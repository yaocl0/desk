import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/ui"
import "root:/modules"

// 桌面组件层。WlrLayer.Bottom —— 壁纸之上、窗口之下。
//
// 自由定位：每张卡自己记一组 (x, y)，拖到哪就是哪。
//
// 代价是窗口必须铺满整块可用区域，卡片之外的桌面就被挡住了。所以这里**必须**
// 抠输入区：mask 只留各卡片的矩形，其余穿透。好在 mask 只需要在「不拖」的时候
// 正确 —— 拖动期间 Wayland 的隐式指针抓取会把事件继续送到本 surface，
// 跟输入区无关。
//
// namespace 用 "desk"，直接吃 hypr/desk.conf 里已有的 layerrule，
// 卡片自带模糊 —— 不用再动 Hyprland 配置。
Scope {
    id: root

    required property var screen

    readonly property var widgets: Config.desktopWidgets

    // 正在被拖 / 正在被缩放的那张卡的 key；"" = 没有
    property string dragKey: ""
    property string sizeKey: ""

    // 吸附阈值
    readonly property int snapPx: Style.space.s + Style.space.xs

    // 宽度上限。下限是每张卡自己的自然宽度，见 slot.minW
    readonly property int maxCardW: Math.round(Style.space.cardWidth * 3)

    // ── 输入区 ──────────────────────────────────────────────
    // Region 不能用 Repeater 生成（Repeater 只认 Item），所以每张卡自己带一个
    // Region 子对象，创建时登记、销毁时注销，窗口的 mask 绑这个数组。
    property var maskParts: []

    function addMask(r) {
        root.maskParts = [...root.maskParts, r];
    }

    function dropMask(r) {
        root.maskParts = root.maskParts.filter(x => x !== r);
    }

    // ── 本地模型 { key, px, py } ────────────────────────────
    // 不直接拿 Config.desktopWidgets 当 Repeater 的 model：JS 数组一变
    // Repeater 会整批重建 delegate，卡片内部状态（日历翻到的月份之类）全丢。
    // ListModel 可以只改某一项的坐标而不动 delegate。
    ListModel {
        id: cards
    }

    function sync() {
        const w = root.widgets;
        let sameKeys = cards.count === w.length;
        if (sameKeys) {
            for (let i = 0; i < w.length; i++) {
                if (cards.get(i).key !== w[i].key) {
                    sameKeys = false;
                    break;
                }
            }
        }
        if (sameKeys) {
            // key 没变就只更新坐标。松手写回 config 会绕回这里，
            // 不拦住的话每拖一次卡片就重建一次。
            for (let i = 0; i < w.length; i++) {
                if (cards.get(i).px !== w[i].x)
                    cards.setProperty(i, "px", w[i].x);
                if (cards.get(i).py !== w[i].y)
                    cards.setProperty(i, "py", w[i].y);
                if (cards.get(i).pw !== w[i].w)
                    cards.setProperty(i, "pw", w[i].w);
            }
            return;
        }
        cards.clear();
        for (const e of w)
            cards.append({
                key: e.key,
                px: e.x,
                py: e.y,
                pw: e.w
            });

    }

    // ── 吸附 ────────────────────────────────────────────────
    // 候选位：屏幕左/右/居中，以及其它卡片的左右边缘对齐、紧贴左右两侧。
    function snapX(slot: Item, x: real): real {
        const m = Style.space.desktopMargin;
        const g = Style.space.desktopGap;
        const w = slot.width;
        const hi = Math.max(0, field.width - w);
        const cand = [m, field.width - m - w, Math.round((field.width - w) / 2)];
        for (let i = 0; i < rep.count; i++) {
            const o = rep.itemAt(i);
            if (!o || o === slot)
                continue;
            cand.push(o.x, o.x + o.width - w, o.x + o.width + g, o.x - g - w);
        }
        const v = Math.max(0, Math.min(hi, x));
        for (const c of cand) {
            if (c >= 0 && c <= hi && Math.abs(v - c) <= root.snapPx)
                return c;
        }
        return v;
    }

    function snapY(slot: Item, y: real): real {
        const m = Style.space.desktopMargin;
        const g = Style.space.desktopGap;
        const h = slot.height;
        const hi = Math.max(0, field.height - h);
        const cand = [m, field.height - m - h, Math.round((field.height - h) / 2)];
        for (let i = 0; i < rep.count; i++) {
            const o = rep.itemAt(i);
            if (!o || o === slot)
                continue;
            cand.push(o.y, o.y + o.height - h, o.y + o.height + g, o.y - g - h);
        }
        const v = Math.max(0, Math.min(hi, y));
        for (const c of cand) {
            if (c >= 0 && c <= hi && Math.abs(v - c) <= root.snapPx)
                return c;
        }
        return v;
    }

    // ── 放置模式 ────────────────────────────────────────────
    // 面板里点一个还没上桌的组件 → DesktopWidgets.placing 被设上 →
    // 这一层浮到最上面、虚影跟着鼠标，再点一下落位。
    //
    // 为什么不是「从面板里一路拖出来」：弹出框和这一层是两个 Wayland surface，
    // 在弹出框里按下，指针的隐式抓取就归它了，事件送不到这儿；而它又没法在
    // 自己的几何之外画虚影。跨 surface 的连续拖拽做不到。
    readonly property string placing: DesktopWidgets.placing
    property real aimX: 0
    property real aimY: 0

    function aimAt(x: real, y: real) {
        // 虚影的中心跟着指针走，再过一遍吸附
        root.aimX = root.snapX(ghost, x - ghost.width / 2);
        root.aimY = root.snapY(ghost, y - ghost.height / 2);
    }

    function place() {
        Config.addWidgetAt(root.placing, root.aimX, root.aimY);
        DesktopWidgets.placing = "";
    }

    Component.onCompleted: root.sync()
    onWidgetsChanged: root.sync()

    // 保险：放置模式下整层浮在最上面且不抠输入区，万一哪里卡住了，
    // 屏幕就点不动了。30 秒自动退出。
    Timer {
        running: root.placing !== ""
        interval: 30000
        onTriggered: DesktopWidgets.placing = ""
    }

    PanelWindow {
        id: win

        screen: root.screen
        color: "transparent"
        visible: cards.count > 0 || root.placing !== ""

        // 放置时浮到最上面：否则虚影在所有窗口底下，既看不见也点不着
        WlrLayershell.layer: root.placing !== "" ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.namespace: "desk"
        // 桌面组件不该抢键盘 —— 点一下卡片就把焦点从编辑器里拿走是灾难
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // 铺满「栏没占掉」的那块。exclusiveZone: 0 = 尊重别人预留的区域，
        // 所以 y = 0 就是栏的正下方，卡片不会被压到栏底下去。
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // 平时只有卡片矩形吃点击，其余穿透到桌面。
        //
        // 但**手势进行中必须整块都收**（mask: null = 不抠输入区）：
        // 卡片跟着鼠标走的时候，Region 也跟着变，等于在指针抓取期间不停改
        // surface 的输入区。鼠标一快就跑到区外，compositor 发 leave，
        // 抓取当场断掉 —— 表现就是「拖快了卡片不动了」。
        // 手势期间反正整个屏幕都归这次操作，收下所有事件没有副作用。
        mask: root.placing !== "" || root.dragKey !== "" || root.sizeKey !== "" ? null : cardMask

        Item {
            id: field

            anchors.fill: parent

            Region {
                id: cardMask

                regions: root.maskParts
            }

            // ── 放置模式的三件套：虚影、接点击的那一层、提示条 ──────
            // 虚影直接把真组件加载出来，所见即所得 —— 尺寸也得是真的，
            // 不然吸附算不准。
            Loader {
                id: ghost

                x: root.aimX
                y: root.aimY
                z: 10
                active: root.placing !== ""
                visible: ghost.active
                // 关键：虚影压在光标正下方，而它加载的是真组件 —— ui/Surface 里那个
                // MouseArea 是无条件收 Left|Right 的（"始终接收，只在 clickable 时
                // 往外派发"），不关掉的话每一次按下都被它吞掉，落位那一下永远到不了
                // 下面的 placer。enabled: false 让整棵子树不参与输入，
                // 顺带也修掉光标划过日历 ‹ › 按钮时虚影卡顿。
                enabled: false
                opacity: 0.7
                sourceComponent: ghost.active ? DesktopWidgets.componentFor(root.placing) : null

                onActiveChanged: {
                    if (!ghost.active)
                        return;
                    // 还没动鼠标之前先摆在正中，别从左上角闪一下
                    root.aimX = Math.round((field.width - ghost.width) / 2);
                    root.aimY = Math.round((field.height - ghost.height) / 2);
                }
            }

            MouseArea {
                id: placer

                anchors.fill: parent
                z: 9
                enabled: root.placing !== ""
                visible: placer.enabled
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onPositionChanged: e => root.aimAt(e.x, e.y)
                onClicked: e => {
                    if (e.button === Qt.RightButton)
                        DesktopWidgets.placing = "";
                    else
                        root.place();
                }
            }

            Pill {
                z: 11
                visible: root.placing !== ""
                // 同上，提示条也不该挡住落位的点击
                enabled: false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space.l

                StyledIcon {
                    glyph: "󰆾"
                    size: Style.font.sizeM
                }

                StyledText {
                    text: `放置「${DesktopWidgets.labelFor(root.placing)}」 · 点击落位 · 右键取消`
                }
            }

            Repeater {
                id: rep

                model: cards

                // 每张卡外面套一层，是为了把「删除」「拖动」这些管理动作留在
                // 管理者这边：ui/Card 只管长什么样，不认识 Config，
                // 也不知道自己能被删被拖。加新卡不用为这些做任何事。
                Item {
                    id: slot

                    required property int index
                    required property string key
                    required property real px
                    required property real py
                    // 0 = 用卡片自己的自然宽度
                    required property real pw

                    readonly property bool dragging: root.dragKey === slot.key
                    readonly property bool resizing: root.sizeKey === slot.key

                    property real dx: 0
                    property real dy: 0
                    // 改尺寸过程中的实时宽度；松手才写回 config
                    property real dw: 0

                    readonly property real cw: slot.resizing ? slot.dw : slot.pw

                    // 卡片「没被指定宽度」时的自然宽度 —— 也就是它的最小宽度。
                    //
                    // 只能在 cw <= 0 的时候量：一旦喂了宽度，内容会跟着宽度变
                    //（天气的逐小时列数、实况块放大倍数），implicitWidth 就被自己
                    // 污染了，量出来的「下限」会一路跟着涨，卡片越拖越宽缩不回去。
                    //
                    // 持续量而不是只量一次，顺带也解决了异步加载：天气卡取到数据
                    // 之前只有城市名那一行，等数据到了自然宽度才是真的。
                    property real natW: 0

                    readonly property real holderW: holder.implicitWidth
                    readonly property real minW: slot.natW > 0 ? slot.natW : Style.space.cardWidth

                    onHolderWChanged: {
                        if (slot.cw <= 0)
                            slot.natW = slot.holderW;
                    }

                    // 没有坐标的（IPC 加的、老配置迁移来的）先落在一个按序号
                    // 错开的位置上，然后立刻写回 config —— 「没有坐标」只是个
                    // 过场状态，不留存。位置不看卡片尺寸，所以没有「等它量出
                    // 高度」那套竞态。
                    readonly property real fallbackX: Style.space.desktopMargin + slot.index * Style.space.l
                    readonly property real fallbackY: Style.space.desktopMargin + slot.index * Style.space.l

                    // 卡片是真的变宽，不是缩放 —— 高度由内容重排之后自己决定
                    width: holder.implicitWidth
                    height: holder.implicitHeight

                    z: slot.dragging ? 1 : 0
                    opacity: slot.dragging ? 0.9 : 1.0

                    // 夹在可用区域内：换分辨率 / 插拔显示器后坐标可能落到屏幕外，
                    // 夹一下至少还看得见、还拖得回来。不写回 config —— 接上外屏
                    // 再拔掉，不该把原来的位置悄悄改掉。
                    x: slot.dragging ? slot.dx : Math.max(0, Math.min(field.width - slot.width, slot.px >= 0 ? slot.px : slot.fallbackX))
                    y: slot.dragging ? slot.dy : Math.max(0, Math.min(field.height - slot.height, slot.py >= 0 ? slot.py : slot.fallbackY))


                    Loader {
                        id: holder

                        width: holder.implicitWidth
                        height: holder.implicitHeight
                        // 目录里没这个 key（手改 config 拼错了）就什么都不加载
                        sourceComponent: DesktopWidgets.componentFor(slot.key)
                    }

                    // 把宽度喂给卡片。每个桌面组件的根都是 ui/Card，
                    // 它认 fixedWidth，内部再按 contentWidth 重排。
                    // 0 = 不指定，卡片按内容自然撑开。
                    Binding {
                        target: holder.item
                        property: "fixedWidth"
                        value: Math.round(slot.cw)
                    }

                    // 这张卡在输入区里占的那一块。用 item 而不是手写 x/y，
                    // 省得自己操心坐标系换算。
                    Region {
                        id: hole

                        item: slot
                        // 故意不跟卡片的圆角：右下的缩放把手和右上的 × 都贴着角，
                        // 一抠圆角它们就有一大半落到输入区外面，点下去根本到不了
                        // 窗口（glass 的 radiusL 是 12，material 24，把手才 18 见方）。
                        // 代价只是四个角上几块全透明的小三角也会吃掉点击，可以忽略。
                    }

                    Component.onCompleted: {
                        root.addMask(hole);
                        if (slot.cw <= 0)
                            slot.natW = holder.implicitWidth;
                        // 没坐标的立刻补一个，让「没有坐标」不留存。
                        // callLater：别在构造过程中写 config，那会在 delegate 还没
                        // 建完的时候把 sync 再跑一遍。
                        if (slot.px < 0)
                            Qt.callLater(() => Config.moveWidget(slot.key, slot.fallbackX, slot.fallbackY));
                    }
                    Component.onDestruction: root.dropMask(hole)

                    // 顶部拖动条。没有可见的手柄 —— 按住卡片上沿就能拖。
                    //
                    // 这条带会压住日历的「‹ 月份 ›」那一行，所以**不能用 MouseArea**：
                    // 那东西一按下就独占抓取，月份再也翻不了。DragHandler 在超过拖动
                    // 阈值之前不抢抓取，于是「点一下」照常落到下面的按钮上，
                    // 「按住拖」才接管。× 按钮同理，不受影响。
                    Item {
                        id: dragBar

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: Style.space.l
                        z: 1

                        // 唯一的可供性：鼠标移到上沿变成抓手
                        HoverHandler {
                            cursorShape: slot.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        }

                        DragHandler {
                            id: dh

                            // 按下那一刻卡片在 field 里的位置 + 指针的场景坐标，
                            // 位移按两者的差算。用 scenePressPosition 而不是 activeTranslation：
                            // 卡片拖动时自己在动，在它的坐标系里算位移会和自身位移互相喂。
                            property real baseX: 0
                            property real baseY: 0

                            // 自己算位置，不让它直接搬运 —— 搬运会绕过吸附和夹取
                            target: null

                            onActiveChanged: {
                                if (dh.active) {
                                    const g = slot.mapToItem(field, 0, 0);
                                    dh.baseX = g.x;
                                    dh.baseY = g.y;
                                    slot.dx = g.x;
                                    slot.dy = g.y;
                                    root.dragKey = slot.key;
                                } else {
                                    root.dragKey = "";
                                    Config.moveWidget(slot.key, slot.dx, slot.dy);
                                }
                            }

                            // 两个信号都接：只要指针动了就重算，不依赖某一个一定会发
                            onCentroidChanged: dh.follow()
                            onActiveTranslationChanged: dh.follow()

                            function follow() {
                                if (!dh.active)
                                    return;
                                const c = dh.centroid;
                                const dxs = c.scenePosition.x - c.scenePressPosition.x;
                                const dys = c.scenePosition.y - c.scenePressPosition.y;
                                slot.dx = root.snapX(slot, dh.baseX + dxs);
                                slot.dy = root.snapY(slot, dh.baseY + dys);
                            }
                        }
                    }

                    // 右下角的缩放把手。同样用 DragHandler 而不是 MouseArea，
                    // 理由和顶部拖动条一样：不抢下面内容的点击。
                    Item {
                        id: sizer

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Style.space.xs
                        implicitWidth: Style.space.l + Style.space.xs
                        implicitHeight: Style.space.l + Style.space.xs
                        z: 1
                        visible: hov.hovered || slot.resizing

                        // 用 Dot 而不是字形：一个角标而已，不必赌 Nerd Font 里
                        // 哪个码位长得像「缩放」
                        Dot {
                            anchors.centerIn: parent
                            width: Style.space.s
                            height: Style.space.s
                            tone: slot.resizing ? "accent" : "dim"
                        }

                        HoverHandler {
                            cursorShape: Qt.SizeHorCursor
                        }

                        DragHandler {
                            id: rh

                            // 按下那一刻卡片的实际宽度
                            property real baseW: 0

                            target: null

                            onActiveChanged: {
                                if (rh.active) {
                                    rh.baseW = slot.width;
                                    slot.dw = slot.width;
                                    root.sizeKey = slot.key;
                                } else {
                                    root.sizeKey = "";
                                    // 拖到底就存 0（= 自然宽度）而不是存一个具体数值。
                                    // 这样「最小」这个状态始终由卡片自己定义，
                                    // 换主题 / 内容变了也还是贴着它的下限。
                                    Config.resizeWidget(slot.key, slot.dw <= slot.minW + 1 ? 0 : slot.dw);
                                }
                            }

                            onCentroidChanged: rh.follow()
                            onActiveTranslationChanged: rh.follow()

                            function follow() {
                                if (!rh.active)
                                    return;
                                const c = rh.centroid;
                                // 只看横向：高度是内容重排之后自己定的，
                                // 竖着拖没有意义
                                const ddx = c.scenePosition.x - c.scenePressPosition.x;
                                // 下限是这张卡的自然宽度：默认大小就是最小，只能往大拖
                                slot.dw = Math.max(slot.minW, Math.min(root.maxCardW, rh.baseW + ddx));
                            }
                        }
                    }

                    // 悬停才出现，平时不打扰
                    IconButton {
                        id: closeBtn

                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.space.xs
                        z: 1
                        visible: hov.hovered && !slot.dragging
                        glyph: "󰅖"
                        onClicked: Config.removeWidget(slot.key)
                    }

                    HoverHandler {
                        id: hov
                    }
                }
            }
        }
    }
}
