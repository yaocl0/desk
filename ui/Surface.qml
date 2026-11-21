import QtQuick
import QtQuick.Effects
import "root:/core"

// 带主题的矩形。圆角 / 描边 / 透明度 / 阴影 / 交互全在这里，
// modules/ 永远不直接写 Rectangle。
Rectangle {
    id: root

    // 0 = 窗口底色，1 = 组件容器，2 = 弹层
    property int level: 1
    property color tint: root.level === 0 ? Style.color.background : root.level === 1 ? Style.color.surfaceAlt : Style.color.surface

    // 主题透明度只作用在"贴着合成器"的层（窗口底 / 弹层），
    // 栏内组件保持不透明 —— 否则选中高亮会被二次稀释成一团糊。
    property bool translucent: root.level !== 1

    // 描边默认只给「贴着合成器」的层：栏本体(0)和弹层(2)。
    // 栏内组件(1)密集堆叠，各自描边会变成一片碎框。
    // 这样主题只要设一个 shape.borderWidth，就能得到
    // 「菜单/面板有细边框、栏内药丸没有」的 macOS 式效果。
    property bool bordered: root.level !== 1

    property bool clickable: false
    readonly property bool hovered: hover.hovered

    signal clicked(var event)
    signal wheeled(var event)

    // -1 = 按 level 推（默认）。调用方给了非负值就用它 —— 启动器要的就是这个：
    // 栏和弹层都贴着桌面出现，底下通常是壁纸；启动器却会盖在任意窗口之上，
    // 还要在上面快速读一列文字，不能和它们共用同一个透明度。
    property real opacityOverride: -1

    // level 0 是栏底，用单独的 barOpacity：想让栏"几乎只剩壁纸"
    // 又不想把通知卡片一起稀释掉。
    readonly property real surfaceOpacity: root.opacityOverride >= 0 ? root.opacityOverride : !root.translucent ? 1.0 : root.level === 0 ? Style.barOpacity : Style.effect.opacity

    color: Style.alpha(root.tint, root.surfaceOpacity)
    radius: Style.shape.radiusM
    border.width: root.bordered ? Style.shape.borderWidth : 0
    border.color: Style.alpha(Style.color.outline, root.surfaceOpacity)

    // 切主题时平滑过渡，而不是硬跳
    Behavior on color {
        enabled: Style.motion.enabled
        ColorAnimation {
            duration: Style.durNormal
        }
    }
    Behavior on radius {
        enabled: Style.motion.enabled
        NumberAnimation {
            duration: Style.durNormal
            easing.type: Style.easing
        }
    }
    Behavior on scale {
        enabled: Style.motion.enabled
        NumberAnimation {
            duration: Style.durFast
            easing.type: Style.easing
        }
    }

    scale: root.clickable && ma.pressed && Style.motion.enabled ? 0.94 : 1.0

    layer.enabled: Style.effect.elevation > 0
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.6
        shadowVerticalOffset: Style.effect.elevation
        shadowOpacity: 0.45
    }

    // hovered 必须走 HoverHandler，不能用 MouseArea.containsMouse：
    // 嵌套时（比如灵动岛的胶囊里放着时钟/音量这些 Pill），子 MouseArea 会把
    // hover 事件消费掉，父级的 containsMouse 直接变 false。PointerHandler 不受
    // 这个限制，父子都能同时收到。
    //
    // 这正是灵动岛"鼠标放上去一直闪"的根因：光标压在子药丸上 → 胶囊判定未悬停
    // → 收起 → 布局一动光标落到内边距 → 判定悬停 → 展开 → 又压回子药丸，循环。
    HoverHandler {
        id: hover

        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    MouseArea {
        id: ma

        anchors.fill: parent
        // 只有可点的 Surface 才需要 hover 事件；不可点的开着只会白白拦截父级
        hoverEnabled: root.clickable
        // 不能用 acceptedButtons: Qt.NoButton 来表示"不可点"——那样连点击的
        // 事件分发都没有。始终接收，只在 clickable 时往外派发。
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (root.clickable)
                root.clicked(event);
        }
        onWheel: event => {
            if (root.clickable)
                root.wheeled(event);
        }
    }
}
