import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/ui"
import "root:/services"

// 启动器面板本体 —— 只管内容，不管窗口。窗口、遮罩、定位、点外面关掉
// 都在 overlays/LauncherLayer.qml 里，和 NotificationToast / NotificationLayer 同一个分工。
//
// 一个输入框两种来源，靠前缀切：
//   （无）  应用     DesktopEntries，空串时按使用频率排
//   /      窗口     已经打开的 toplevel，回车切过去
//
// 没有「跑一条 shell 命令」那一路：quickshell 的 stdout/stderr 被 Hyprland 的
// exec-once 接到了 /dev/null，子进程继承下来，输出和退出码全都看不见 ——
// 一个你看不到结果的命令行入口不如不给。要跑命令就开终端。
Surface {
    id: root

    signal dismissed

    readonly property int pad: Style.space.m
    readonly property string query: input.text
    readonly property string mode: root.query.startsWith("/") ? "window" : "app"
    readonly property string term: root.mode === "app" ? root.query : root.query.slice(1)

    // 键盘选中的是第几条
    property int cursor: 0

    // 一次最多算这么多条。再多没有意义 —— 没人会滚到第四十条去找东西，
    // 而每敲一个字符都要重算一遍。
    readonly property int limit: 40

    readonly property var results: {
        const raw = root.term;

        if (root.mode === "window") {
            // 列表 / 环形两个启动器共用同一套窗口搜索，见 services/Windows
            return Windows.search(raw, root.limit).map(it => ({
                        kind: "window",
                        id: it.id,
                        title: it.title,
                        subtitle: it.subtitle,
                        tag: "窗口",
                        source: it.icon,
                        glyph: "󰖯",
                        entry: null,
                        toplevel: it.toplevel
                    }));
        }

        return Apps.search(raw, Config.launcherUsage, root.limit).map(it => {
            const t = Windows.forApp(it.id, it.entry?.startupClass ?? "");
            return {
                kind: "app",
                id: it.id,
                title: it.title,
                subtitle: it.subtitle,
                tag: t ? "运行中" : "应用",
                source: it.icon,
                glyph: "󰣆",
                entry: it.entry,
                toplevel: t
            };
        });
    }

    function reset() {
        input.clear();
        root.cursor = 0;
        input.focusInput();
    }

    function move(delta: int) {
        const n = root.results.length;
        if (n === 0)
            return;
        root.cursor = ((root.cursor + delta) % n + n) % n;
    }

    // 先关面板再动手。面板是独占键盘的 layer surface：它还挂着的时候合成器
    // 不会把焦点让给别的窗口，而它关掉的那一刻焦点又会被还给原先那个窗口 ——
    // 正好把刚发出去的 activate() 盖掉。实测「切换」看起来毫无反应就是这么来的。
    // Qt.callLater 把动作推到下一轮事件循环，那时 unmap 已经发出去了。
    // alt = 按住 Shift：切到已有窗口，而不是再开一个。
    // 默认开新实例 —— 和 rofi / wofi 这些一致，「搜应用」就是「要一个新的」；
    // 「回到那个已经开着的」是另一件事，让 Shift 去表达。
    function activate(alt: bool) {
        const it = root.results[root.cursor];
        if (!it)
            return;
        root.pending = it;
        root.pendingAlt = !!alt;
        root.dismissed();
        actTimer.restart();
    }

    // 动作推迟到面板真的 unmap 之后。Qt.callLater 不够 —— 它还在同一轮
    // 事件循环里，unmap 的 Wayland 请求可能都没发出去，合成器随后的
    // 「把焦点还给原窗口」正好盖掉刚发出的 activate()。
    property var pending: null
    property bool pendingAlt: false

    Timer {
        id: actTimer

        interval: 80
        onTriggered: {
            const it = root.pending;
            root.pending = null;
            if (it)
                root.run(it, root.pendingAlt);
        }
    }

    function run(it: var, alt: bool) {
        // Shift 只对应用有意义：窗口本来就是切过去
        const focusIt = !!(it.toplevel && alt);

        if (focusIt)
            it.toplevel.activate();
        else if (it.entry)
            it.entry.execute();
        else if (it.toplevel)
            it.toplevel.activate();

        // 频率只记真正启动过的应用：切窗口不算「又用了一次这个应用」，
        // 否则一直开着的终端会把榜单压死。
        if (it.kind === "app" && !focusIt)
            Config.recordLaunch(it.id);
    }

    function handleKey(event: var) {
        const k = event.key;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;

        if (k === Qt.Key_Escape)
            root.dismissed();
        else if (k === Qt.Key_Down || k === Qt.Key_Tab || (ctrl && k === Qt.Key_J))
            root.move(1);
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab || (ctrl && k === Qt.Key_K))
            root.move(-1);
        else if (k === Qt.Key_PageDown)
            root.move(Style.launcher.rows);
        else if (k === Qt.Key_PageUp)
            root.move(-Style.launcher.rows);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            root.activate((event.modifiers & Qt.ShiftModifier) !== 0);
        else if (ctrl && k === Qt.Key_U)
            input.clear();
        else
            return;   // 没接住的键留给 TextInput 自己处理

        event.accepted = true;
    }

    // 结果变了就回到第一条：敲下一个字符之后，原来停在第七条的光标
    // 指向的已经是另一个应用了，留在那儿只会误触。
    onResultsChanged: root.cursor = 0
    onCursorChanged: list.positionViewAtIndex(root.cursor, ListView.Contain)

    level: 2
    radius: Style.shape.radiusL
    // 启动器不跟 effect.opacity 走：栏和弹层底下通常是壁纸，它底下是任意窗口。
    // -1 时退回按 level 推，和别的面板一致。
    opacityOverride: Style.launcher.opacity ?? -1
    implicitWidth: Style.launcher.width > 0 ? Style.launcher.width : body.implicitWidth + root.pad * 2
    implicitHeight: body.implicitHeight + root.pad * 2

    ColumnLayout {
        id: body

        anchors.fill: parent
        anchors.margins: root.pad
        spacing: Style.space.s

        StyledInput {
            id: input

            Layout.fillWidth: true
            Layout.preferredHeight: Style.launcher.inputHeight
            glyph: root.mode === "window" ? "󰖯" : "󰍉"
            placeholder: "搜索应用　/ 切窗口"
            onKeyPressed: event => root.handleKey(event)
        }

        Dot {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, Style.shape.borderWidth)
            visible: list.visible || empty.visible
            tone: "outline"
        }

        ListView {
            id: list

            Layout.fillWidth: true
            // 行数由主题定，不足一屏时面板跟着缩 —— 下面空一片比截断更难看
            Layout.preferredHeight: Math.min(root.results.length, Style.launcher.rows) * Style.launcher.rowHeight
            visible: root.results.length > 0

            model: root.results
            currentIndex: root.cursor
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            delegate: ResultRow {
                required property var modelData
                required property int index

                width: list.width
                title: modelData.title
                subtitle: modelData.subtitle
                tag: modelData.tag
                source: modelData.source
                glyph: modelData.glyph
                selected: index === root.cursor

                onClicked: event => {
                    root.cursor = index;
                    root.activate((event.modifiers & Qt.ShiftModifier) !== 0);
                }
            }
        }

        StyledText {
            id: empty

            Layout.fillWidth: true
            Layout.preferredHeight: Style.launcher.rowHeight
            visible: root.results.length === 0 && root.query !== ""
            text: "没有匹配项"
            tone: "dim"
            role: "label"
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Style.space.xs
            visible: Style.launcher.hint
            text: "↑↓ 选择　↵ 新实例　⇧↵ 切过去　/ 窗口　esc 关闭"
            tone: "dim"
            role: "label"
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
