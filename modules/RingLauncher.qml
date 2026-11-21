import QtQuick
import "root:/core"
import "root:/ui"
import "root:/services"

// 环形启动器面板 —— 只管内容，窗口 / 遮罩 / 滚轮在 overlays/RingLauncherLayer.qml。
// 和 modules/Launcher.qml 是两个平行的实现，谁都不认识谁：用哪一个由
// config.launcher 决定，shell.qml 里两个 LazyLoader 二选一。
//
// 形态抄的是 Nebula（AGPL-3.0）那个径向启动器：一圈不同形状的图标绕着一块
// 花瓣背板，中间一颗搜索药丸，方向键转的是整个环、选中项永远停在正上方。
// 代码没有抄 —— 它依赖 m3shapes 这个 C++ 插件和它自己那套 M3 色卡，
// 这里的形状是 ui/PetalShape 用极坐标现算的，数据走本仓库既有的 services/Apps。
//
// 只有应用一路：没有前缀模式，也没有「跑 shell 命令」。后者的理由同
// modules/Launcher.qml —— quickshell 的 stdout 被 exec-once 接到了 /dev/null，
// 看不到结果的命令行入口不如不给。切主题 / 布局这些在栏上的设置面板里。
Item {
    id: root

    signal dismissed

    // ── 布局 ────────────────────────────────────────────────
    // 不走 Style.launcher：那组 token（rowHeight / rows / width）描述的是
    // 一块列表面板，对环一个都用不上。环要的是半径和格子，放这儿一处可调。
    //
    // 这几个数是互相咬死的，改之前先看一眼：
    //   格子外缘 = ringRadius + itemSize/2        必须 < 花瓣峰值 ringSize/2
    //   药丸半宽 = pillWidth/2                    必须 < ringRadius - labelWidth/2
    readonly property int ringSize: 440
    readonly property int ringRadius: 158
    readonly property int itemSize: 58
    readonly property int labelWidth: 96
    readonly property int iconSize: 28
    readonly property int pillWidth: 200
    readonly property int pillHeight: 44

    // 槽位固定八个。保留 slots 这个名字而不是全文替换成 appSlots：
    // 环上所有角度、折返、错峰都是按「一圈几格」算的，留一个名字说明它是什么。
    readonly property int appSlots: 8
    readonly property int slots: root.appSlots

    // 最多参与转环的结果数。比槽位多就开始循环推送，但也不必无限 ——
    // 没人会转到第四十个去找东西，搜不到就再敲一个字符。
    readonly property int limit: 16

    // ── 时长 ────────────────────────────────────────────────
    // 不用 Style.durFast / durNormal：那两个是给栏上药丸的 100ms 量级，
    // 开场这种有编排的动画要长得多。仍然受 motion.enabled 门控 ——
    // 关掉动效的主题下全部归零，环直接出现在最终位置。
    readonly property int durFast: Style.motion.enabled ? 110 : 0
    readonly property int durNormal: Style.motion.enabled ? 220 : 0
    readonly property int durSlow: Style.motion.enabled ? 420 : 0
    readonly property int durIntro: Style.motion.enabled ? 700 : 0

    // ── 缓动小工具 ──────────────────────────────────────────
    // 开场是「一条 0→1 的线性进度 + 若干个各自截取一段的派生值」，
    // 而不是十几条 NumberAnimation 互相对表。错峰、回弹都是从 intro 现算的。
    function phase(t: real, start: real, len: real): real {
        return Math.max(0, Math.min(1, (t - start) / len));
    }

    function back(t: real): real {
        const c1 = 1.70158 * 1.2;
        const c3 = c1 + 1;
        return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
    }

    function decel(t: real): real {
        return 1 - Math.pow(1 - t, 3);
    }

    // ── 状态 ────────────────────────────────────────────────
    property string query: ""

    // 一个输入框两种来源，和列表式启动器用同一个前缀约定：
    //   （无）  应用     Apps.search，空串时按使用频率排
    //   /      窗口     已经开着的 toplevel，回车切过去
    readonly property string mode: root.query.startsWith("/") ? "window" : "app"
    readonly property string term: root.mode === "window" ? root.query.slice(1) : root.query

    // cursor = results 里的第几条（真正会被回车执行的那条）
    // selected = 哪一格高亮。结果比槽位多时两者脱钩：环在转，格子不动，
    //            内容从格子里换进换出。
    property int cursor: 0
    property int selected: 0
    readonly property bool infinite: root.results.length > root.slots

    property real intro: 0
    property bool rushing: false

    readonly property var results: {
        if (root.mode === "window") {
            // 窗口搜索和匹配在 services/Windows，列表式启动器用的是同一份
            return Windows.search(root.term, root.limit).map(it => ({
                        id: it.id,
                        title: it.title,
                        icon: it.icon,
                        glyph: "󰖯",
                        toplevel: it.toplevel
                    }));
        }
        return Apps.search(root.term, Config.launcherUsage, root.limit).map(it => ({
                    id: it.id,
                    title: it.title,
                    icon: it.icon,
                    glyph: "󰣆",
                    entry: it.entry
                }));
    }

    // 格子全是正圆。
    //
    // 原来是八格八个形状（4/9/圆/6/8/12/7/4 瓣），想法是「差异本身就是
    // 这一圈有八个不同东西的信息」。实际效果不好：58px 上的多瓣形状读不出
    // 是什么花，只看得出边缘不平。转动的提示由图标和标签在动来给，够了。
    //
    // 要把形状找回来：给下面 Repeater 里的 RingItem 加 leaves / valley，
    // ui/PetalShape 的能力一直都在。

    // 第 position 格（0 = 正上方）此刻该显示 results 里的谁。
    // 把 position 折到 [-slots/2, slots/2]：右半边往后取，左半边往前取，
    // 于是「下一个」总是从右边转进来，而不是绕大半圈。
    function entryAt(position: int): var {
        if (root.results.length === 0)
            return null;
        return root.results[root.indexAt(position, position)] ?? null;
    }

    // 第 position 格此刻显示的是 results 里的第几条。entryAt 取的是元素，
    // 这个取的是下标 —— 鼠标点哪一格，光标就该落到哪一条。
    function indexAt(position: int, slotIndex: int): int {
        const n = root.results.length;
        if (!root.infinite)
            return slotIndex;
        const offset = position <= root.slots / 2 ? position : position - root.slots;
        return ((root.cursor + offset) % n + n) % n;
    }

    function step(delta: int, repeat: bool) {
        root.rushing = repeat;
        if (repeat)
            rushTimer.restart();
        const n = root.results.length;
        if (n === 0)
            return;
        root.cursor = ((root.cursor + delta) % n + n) % n;
        root.selected = root.infinite ? ((root.selected + delta) % root.slots + root.slots) % root.slots : root.cursor;
    }

    // 松手之后回到「错峰 + 回弹」。按住时每一格都在等自己的 delay、
    // 又都在回弹，整个环会糊成一团果冻。
    Timer {
        id: rushTimer

        interval: root.durNormal + 60
        onTriggered: root.rushing = false
    }

    // 结果变了就回到第一条：敲下一个字符之后，原来停在第五格的光标
    // 指向的已经是另一个应用了，留在那儿只会误触。
    onResultsChanged: {
        root.cursor = 0;
        root.selected = 0;
    }

    function reset() {
        input.clear();
        root.query = "";
        root.cursor = 0;
        root.selected = 0;
        root.rushing = false;
        input.focusInput();
    }

    // 开场 / 收场都是推同一条 0↔1 的线性进度，花瓣、格子、药丸各自从里面
    // 截一段用（见 phase）。收场比开场快一截 —— 关东西的时候没人想等。
    //
    // 时长为 0（主题关了动效）时不走动画：duration 0 的 NumberAnimation 仍然
    // 要等一帧才到位，而这一帧里 visible 还绑在 intro > 0 上，会闪一下。
    function play() {
        foldAnim.stop();
        if (root.durIntro === 0) {
            root.intro = 1;
            return;
        }
        root.intro = 0;
        openAnim.restart();
    }

    function fold() {
        // activate() 已经用 closeNow() 瞬间关掉了，这里不用再放一遍
        if (root.intro === 0)
            return;
        openAnim.stop();
        if (root.durSlow === 0) {
            root.intro = 0;
            return;
        }
        foldAnim.restart();
    }

    NumberAnimation {
        id: openAnim

        target: root
        property: "intro"
        to: 1
        duration: root.durIntro
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: foldAnim

        target: root
        property: "intro"
        to: 0
        duration: root.durSlow
        easing.type: Easing.Linear
    }

    // ── 执行 ────────────────────────────────────────────────
    // 先关面板再动手，理由和 modules/Launcher.qml 里写的一样：面板是独占键盘的
    // layer surface，它关掉的那一刻合成器会把焦点还给原先那个窗口，正好盖掉
    // 刚发出去的启动请求。Qt.callLater 不够 —— 那还在同一轮事件循环里，
    // unmap 的 Wayland 请求可能都没发出去。
    property var pending: null

    function activate() {
        const it = root.results[root.cursor];
        if (!it)
            return;
        root.pending = it;
        // 这里**不**排期执行。真正动手要等窗口 unmap 之后，由
        // overlays/RingLauncherLayer 在 visible 变 false 时调 runPending()。
        //
        // 原因就是上面那段注释说的那件事，只是环形多了一层：它的窗口
        // visible 绑在「shouldShow 或收场动画还没放完」上，于是关掉之后
        // 还要再挂 420ms。固定 80ms 的定时器在那会儿去 activate() 窗口，
        // 环还是个独占键盘的 layer surface，合成器根本不让焦点出去；
        // 等环真消失了，焦点又被还给原来那个窗口，把 activate 盖掉。
        //
        // 所以：先瞬间关掉（不放收场动画），再等真的 unmap。
        root.closeNow();
        root.dismissed();
    }

    // 跳过收场动画直接关。切窗口是「我现在要去那边」，为了一段 420ms 的
    // 折叠动画把动作往后拖既慢又容易出错。Esc / 点外面关掉时仍然有动画。
    function closeNow() {
        openAnim.stop();
        foldAnim.stop();
        root.intro = 0;
    }

    function runPending() {
        const it = root.pending;
        root.pending = null;
        if (!it)
            return;
        if (it.toplevel) {
            it.toplevel.activate();
            return;
        }
        if (it.entry) {
            it.entry.execute();
            // 频率只记真正启动过的应用：切窗口不算「又用了一次这个应用」，
            // 否则一直开着的终端会把榜单压死。
            Config.recordLaunch(it.id);
        }
    }

    function handleKey(event: var) {
        const k = event.key;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;

        if (k === Qt.Key_Escape)
            root.dismissed();
        else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab || (ctrl && k === Qt.Key_J))
            root.step(1, event.isAutoRepeat);
        else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab || (ctrl && k === Qt.Key_K))
            root.step(-1, event.isAutoRepeat);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            root.activate();
        else if (ctrl && k === Qt.Key_U)
            input.clear();
        else
            return;   // 没接住的键留给 TextInput 自己处理

        event.accepted = true;
    }

    implicitWidth: root.ringSize
    implicitHeight: root.ringSize
    width: root.ringSize
    height: root.ringSize

    // ── 花瓣背板 ────────────────────────────────────────────
    BlobShape {
        id: petal

        readonly property real t: root.phase(root.intro, 0, 0.6)

        anchors.fill: parent
        lobes: root.slots
        // 每片凸起只露四分之一段圆弧 —— 平缓的扇贝，不是卡在边上的一排球。
        // 圆心距和半径由它反解（见 BlobShape），八瓣时正好 d = rl = 0.5，
        // 凸起的圆自己就盖过中心，core 用不上。
        //
        // 切到窗口模式时弧长拉到 150°，凸起变深。这是整个界面里唯一一处
        // 「模式变了」的全局提示 —— 比在角落加一行字直观，而且不占地方。
        lobeArc: root.mode === "window" ? 150 : 90

        Behavior on lobeArc {
            enabled: Style.motion.enabled

            NumberAnimation {
                duration: root.durSlow
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        // 半径函数的峰值在 θ=0（正右方），格子的 0° 在正上方，差 90°。
        // 转过来之后每个格子正好压在自己那片花瓣上。
        // 开场再多转 120° 进来，让它是「旋进来」而不是「胀出来」。
        rotation: -90 - (1 - root.decel(petal.t)) * 120
        scale: Math.max(0, root.back(petal.t))

        // 和列表启动器同一块底色。两个启动器是同一件事的两种形态，
        // 底色不一样会让人以为是两个程序 —— 所以这里照搬 Surface(level 2)
        // 的算法：surface 配 launcher.opacity，后者 <0 时退回 effect.opacity。
        // （启动器单独拆出不透明度，是因为它盖的是任意窗口，不像栏和弹层
        // 那样底下只有壁纸，见 Defaults 里那段注释。）
        readonly property real surfaceOpacity: (Style.launcher.opacity ?? -1) >= 0 ? Style.launcher.opacity : Style.effect.opacity

        color: Style.alpha(Style.color.surface, petal.surfaceOpacity)
        topLight: 0.12
        strokeColor: Style.alpha(Style.color.onSurface, 0.14)
        strokeWidth: 1

        Behavior on color {
            enabled: Style.motion.enabled

            ColorAnimation {
                duration: root.durNormal
            }
        }
    }

    // 点在花瓣外面（环的四个角）也该关掉。声明在 Repeater 之前 ——
    // QML 里后声明的同级在上层，格子自己的 MouseArea 要能先拿到事件。
    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            if (Math.hypot(mouse.x - width / 2, mouse.y - height / 2) > width / 2)
                root.dismissed();
        }
    }

    Repeater {
        model: root.slots

        RingItem {
            id: slot

            required property int index

            // 0 = 正上方。每次转环变的是 selected，于是所有格子的 angle 一起变，
            // 看上去就是整个环在转。
            readonly property int position: (slot.index - root.selected + root.slots) % root.slots
            readonly property real appearT: Math.max(0, root.back(root.phase(root.intro, 0.3 + slot.position * 0.04, 0.35)))

            angle: slot.position * 360 / root.slots
            ringRadius: root.ringRadius
            itemSize: root.itemSize
            labelWidth: root.labelWidth
            iconSize: root.iconSize
            labelSize: Style.font.sizeS

            // 结果够多就循环推送，不够就一格对一条
            entry: root.infinite ? root.entryAt(slot.position) : root.results[slot.index] ?? null
            selected: slot.position === 0

            // 离正上方越远出得越晚，于是开场是「从选中项往两边展开」
            delay: root.rushing ? 0 : Math.min(slot.position, root.slots - slot.position) * 25
            rushing: root.rushing
            durFast: root.durFast
            durNormal: root.durNormal
            durSlow: root.durSlow

            opacity: Math.min(1, slot.appearT * 2)
            transform: Scale {
                origin.x: root.labelWidth / 2
                origin.y: root.itemSize / 2
                xScale: slot.appearT
                yScale: slot.appearT
            }

            // 点的是哪一格，就先把光标挪过去再执行 —— 否则回车和鼠标会指向两个不同的东西
            onClicked: {
                root.cursor = root.indexAt(slot.position, slot.index);
                root.activate();
            }
        }
    }

    // ── 中心搜索药丸 ────────────────────────────────────────
    // 从一颗圆点横向拉开成胶囊。宽度用 back 曲线，所以会拉过头一点再收回来。
    Surface {
        id: pill

        readonly property real t: root.phase(root.intro, 0.45, 0.45)

        anchors.centerIn: parent
        width: root.pillHeight + (root.pillWidth - root.pillHeight) * Math.max(0, root.back(pill.t))
        height: root.pillHeight
        scale: Math.min(1, pill.t * 4)
        level: 1
        bordered: true
        radius: height / 2
        tint: Style.color.background

        StyledInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Style.space.m
            anchors.rightMargin: Style.space.m
            // 药丸还在拉开的时候不要让文字跟着横向挤 —— 先把壳撑开，最后才显字
            opacity: Math.max(0, pill.t * 3 - 2)
            glyph: root.mode === "window" ? "󰖯" : "󰍉"
            // 药丸就这么宽，占位符得短 —— 被截断的提示比没有提示更糟
            placeholder: root.mode === "window" ? "切换窗口" : "搜索　/ 窗口"
            onTextChanged: root.query = input.text
            onKeyPressed: event => root.handleKey(event)
        }
    }
}
