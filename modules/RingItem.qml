import QtQuick
import "root:/core"
import "root:/ui"

// 环上的一格。只管「我是第几度、我画什么」，转到哪一度、该画谁都是
// modules/RingLauncher 算好了喂进来的 —— 和 ResultRow 对 Launcher 的关系一样。
//
// 尺寸不从 Style 取：启动器那组 token 是给列表式面板用的（rowHeight / rows），
// 环要的是另一套（半径、格子大小、标签宽）。那套放在 RingLauncher 顶上，
// 一处可调，这里只接参数。
Item {
    id: root

    signal clicked

    // 0 = 正上方，顺时针。动画走最短路径，所以 350° → 10° 是往右转 20°，
    // 不是往左倒 340°。
    property real angle: 0
    property real ringRadius: 150
    property real itemSize: 56
    property real labelWidth: 92
    property real iconSize: 26
    property real labelSize: 13

    property var entry: null
    property bool selected: false

    // 形状。默认正圆（leaves = 0 时半径恒为 1）。
    // PetalShape 的多瓣能力还在，想要形状差异的话由调用方给这两个值。
    property int leaves: 0
    property real valley: 1

    // 开场时按「离正上方多远」错峰弹出，由父级算好 0~1 丢进来
    property real appear: 1

    // 连按方向键时不要错峰、也不要回弹 —— 一路按住的话，每一格都在等自己的
    // delay、又都在回弹，整个环会糊成一团果冻。rushing 下统一改成快出快停。
    property int delay: 0
    property bool rushing: false

    property int durFast: 110
    property int durNormal: 220
    property int durSlow: 420

    readonly property bool empty: root.shownEntry === null
    readonly property real radians: (root.angle - 90) * Math.PI / 180

    // 极简主题（gruvbox）把 color.selected 设成 transparent —— 在列表里那是
    // 「选中只靠文字变色」，很合理；在环上却会变成「选中那一格的底没了」，
    // 八格里空一格比高亮本身还扎眼，而且这一格恰恰是回车会启动的那个。
    //
    // 和 ui/StyledInput 处理选区同一个办法：透明就退回 accent，
    // 文字色跟着换成 onAccent，不然会出现浅底浅字。
    //
    // 注意必须先过一道 color 属性再读 .a：Style.color 是从 JSON 读出来的 var，
    // Style.color.selected 拿到的是字符串 "transparent"，JS 字符串没有 .a，
    // 读出来是 undefined，=== 0 永远不成立 —— 这个 fallback 第一版就是这么失效的。
    // 赋给一个 color 属性才会被 QML 转成真正的颜色值，透明色的 a 才是 0。
    readonly property color selectedToken: Style.color.selected
    readonly property bool fallback: root.selectedToken.a === 0
    readonly property color highlight: root.fallback ? Style.color.accent : root.selectedToken
    // 名字不能叫 onHighlight：QML 里 on + 大写开头会被当成 highlight 这个属性的
    // 信号处理器，不是一个能读的属性 —— 读出来 undefined，还不报错，
    // StyledText 落到 ?? onSurface 的兜底，琥珀底上就成了白字。
    readonly property string highlightTone: root.fallback ? "onAccent" : "onSelected"

    width: root.labelWidth
    height: root.itemSize + Style.space.xs + label.height
    x: parent.width / 2 + root.ringRadius * Math.cos(root.radians) - width / 2
    y: parent.height / 2 + root.ringRadius * Math.sin(root.radians) - height / 2

    Behavior on angle {
        enabled: Style.motion.enabled

        SequentialAnimation {
            PauseAnimation {
                duration: root.delay
            }
            RotationAnimation {
                direction: RotationAnimation.Shortest
                duration: root.rushing ? root.durNormal : root.durSlow
                easing.type: root.rushing ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: 1.2
            }
        }
    }

    // ── 换内容时先缩掉再弹回来 ──────────────────────────────
    // 结果多于格子数时，转环会让每一格轮流换人。直接改 entry 的话内容是
    // 硬跳的，而这一格同时还在转 —— 看上去就像图标在飞行途中被掉了包。
    // 缩到 0 再弹回来，换人这件事就有了自己的一拍。
    property var shownEntry: null

    Component.onCompleted: root.shownEntry = root.entry

    function key(e: var): string {
        return e ? (e.id ?? e.name ?? "") : "";
    }

    // Qt.callLater：一次按键会连着改 angle 和 entry，不推迟的话
    // swap 可能在 angle 还没更新完时就起跑。
    onEntryChanged: Qt.callLater(root.sync)

    function sync() {
        if (root.key(root.entry) === root.key(root.shownEntry))
            return;
        if (!Style.motion.enabled) {
            root.shownEntry = root.entry;
            return;
        }
        swap.restart();
    }

    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: root
            property: "scale"
            to: 0
            duration: root.durFast
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: root.shownEntry = root.entry
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: root.durNormal
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    PetalShape {
        id: badge

        anchors.horizontalCenter: parent.horizontalCenter
        // 选中的那一格大一圈。不是用 scale —— scale 被换人动画占着了。
        width: root.itemSize * (root.selected ? 1.12 : 1)
        height: badge.width

        leaves: root.leaves
        valley: root.valley
        // 悬停不再变形 —— 底色已经从半透明的 onSurface 换成 hover 色，
        // 反馈够清楚了。再叠一层「圆变成花」等于把刚去掉的花又请回来。

        color: root.empty ? Style.alpha(Style.color.onSurface, 0.07) : root.selected ? root.highlight : mouse.containsMouse ? Style.color.hover : Style.alpha(Style.color.onSurface, 0.17)
        topLight: 0.1

        Behavior on width {
            enabled: Style.motion.enabled

            NumberAnimation {
                duration: root.durNormal
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        StyledIcon {
            anchors.centerIn: parent
            visible: !root.empty
            source: root.shownEntry?.icon ?? ""
            glyph: root.shownEntry?.glyph ?? ""
            size: root.iconSize
            // selected 的底色可能是实心 accent（pastel 的琥珀），字形图标必须跟着翻色，
            // 否则浅底浅字。有真图标时这个 tone 用不上，StyledIcon 走的是 IconImage。
            tone: root.selected ? root.highlightTone : mouse.containsMouse ? "onHover" : "normal"
        }
    }

    // 选中项的标签垫一颗药丸。不选中的只有文字 ——
    // 八个标签各自带底色的话，环中间会糊成一圈色块。
    Surface {
        anchors.centerIn: label
        width: Math.min(root.width + Style.space.s, label.contentWidth + Style.space.m)
        height: label.contentHeight + Style.space.xs * 2
        visible: root.selected && !root.empty
        level: 1
        bordered: false
        radius: height / 2
        tint: root.highlight
    }

    StyledText {
        id: label

        anchors.top: badge.bottom
        anchors.topMargin: Style.space.xs
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.shownEntry?.title ?? ""
        font.pixelSize: root.labelSize
        font.weight: root.selected ? Font.DemiBold : Style.font.weight
        // 未选中的也要用 normal：这一行是条目的标题，不是副标题。
        // dim 在 gruvbox 下是 #665c54，压在花瓣上根本读不出来 ——
        // 列表里标题本来也是 normal，只有第二行才 dim。
        // 层次交给不透明度 + 药丸 + 字重，不靠把文字压暗。
        tone: root.selected ? root.highlightTone : "normal"
        opacity: root.selected ? 1 : 0.72
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.empty
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
