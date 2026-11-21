pragma Singleton

import Quickshell
import Quickshell.Io

// config.json 的读写。改文件 → 热重载；调 setTheme/setLayout → 写回文件。
// 两条路都汇到同一份 JSON，不存在两个事实来源。
Singleton {
    id: root

    readonly property string theme: cfg.theme
    readonly property string layout: cfg.layout
    // 用哪个启动器。list = 列表式（modules/Launcher），ring = 环形（modules/RingLauncher）。
    // 两套是平行实现，共用 core/LauncherState，所以快捷键和 IPC 不用跟着改。
    readonly property string launcher: cfg.launcher

    // 锁屏背景。blur = 锁那一刻的桌面截图糊掉，stars = 星空。
    // 选 stars 时 core/LockState 根本不会去截图 —— 用不到的东西不该拍，
    // 那张图里可能有任何正开着的内容。
    readonly property string lockBackground: cfg.lockBackground
    readonly property string wallpaper: cfg.wallpaper
    readonly property string wallpaperDir: cfg.wallpaperDir || `${Quickshell.env("HOME")}/Pictures`
    // 自动轮换壁纸的间隔，单位分钟，0 = 不轮换
    // 自动切换的开关和间隔分开存：关掉再打开时，原来设的间隔还在，
    // 不用把 interval 清零再猜一个默认值回填。
    readonly property bool wallpaperAuto: cfg.wallpaperAuto
    readonly property int wallpaperInterval: cfg.wallpaperInterval

    // 面板上能选的几档
    readonly property var wallpaperIntervals: [10, 30, 60, 180]

    // 桌面组件。每项是 { key, x, y }，坐标相对「栏下面那块可用区域」的左上角。
    //
    // 老格式是纯字符串数组（只有顺序、没有坐标）。读到就补成 x/y = -1，
    // 由 overlays/DesktopLayer 量出卡片高度后依次铺开再写回 —— 不用手改 config。
    readonly property var desktopWidgets: (cfg.desktopWidgets ?? []).map(it => typeof it === "string" ? ({
                key: it,
                x: -1,
                y: -1,
                w: 0
            }) : ({
                key: it.key,
                x: it.x ?? -1,
                y: it.y ?? -1,
                // w = 卡片宽度（px）。0 / 缺省 = 用卡片自己的自然宽度。
                // 老配置里的 s（缩放倍率）已废弃，读到就忽略，退回自然宽度。
                w: it.w ?? 0
            }))

    function hasWidget(key: string): bool {
        return root.desktopWidgets.some(w => w.key === key);
    }

    // 启动器的使用频率：{ "firefox.desktop": 12 }。空 query 时结果按它排，
    // 所以「常用的那几个」开箱就在最上面，不用先打字。
    readonly property var launcherUsage: cfg.launcherUsage ?? ({})

    // 只保留计数最高的 40 条 —— 装了几百个 .desktop 的机器上，
    // 不裁剪的话 config.json 会被一堆只开过一次的条目撑大。
    function recordLaunch(id: string) {
        if (!id)
            return;
        const next = Object.assign({}, root.launcherUsage);
        next[id] = (next[id] ?? 0) + 1;
        const kept = Object.keys(next).sort((a, b) => next[b] - next[a]).slice(0, 40);
        const out = {};
        for (const k of kept)
            out[k] = next[k];
        cfg.launcherUsage = out;
        file.writeAdapter();
    }

    // 天气卡用。city 留空时卡片会提示怎么填，并且一个请求都不发
    readonly property string weatherCity: cfg.weatherCity
    readonly property int weatherInterval: cfg.weatherInterval
    // 换壁纸时是否自动重算 material 主题的配色（需要装 matugen）
    readonly property bool autoTheme: cfg.autoTheme

    readonly property var themes: ["gruvbox", "glass", "material", "pastel"]
    readonly property var layouts: ["topbar", "island", "dock"]
    readonly property var launchers: ["list", "ring"]
    readonly property var lockBackgrounds: ["blur", "stars"]

    function setTheme(name: string) {
        cfg.theme = name;
        file.writeAdapter();
    }

    function setLayout(name: string) {
        cfg.layout = name;
        file.writeAdapter();
    }

    function setLauncher(name: string) {
        cfg.launcher = name;
        file.writeAdapter();
    }

    function setLockBackground(name: string) {
        cfg.lockBackground = name;
        file.writeAdapter();
    }

    function setWallpaper(path: string) {
        cfg.wallpaper = path;
        file.writeAdapter();
    }

    function setWallpaperAuto(on: bool) {
        cfg.wallpaperAuto = on;
        file.writeAdapter();
    }

    function setWallpaperInterval(minutes: int) {
        // 夹到 1 以上：0 会让定时器永远不跑，但那是「关」该干的事。
        // 用 interval=0 表达「关」的话，关掉再打开就不知道原来设了多久。
        cfg.wallpaperInterval = Math.max(1, minutes);
        file.writeAdapter();
    }

    // 桌面组件的增删改。必须整个换一个新数组 —— 原地 push/splice 不会发
    // 变更通知，桌面上的 Repeater 和面板里的对勾都不会动。
    //
    // 拖动松手时才写回：拖动中途反复写盘会让 FileView 重载、Repeater 重建，
    // 正在拖的卡片当场被销毁。
    function setWidgets(list: var) {
        cfg.desktopWidgets = list.map(w => ({
                    key: w.key,
                    x: Math.round(w.x),
                    y: Math.round(w.y),
                    w: Math.round(w.w ?? 0)
                }));
        file.writeAdapter();
    }

    function moveWidget(key: string, x: real, y: real) {
        root.setWidgets(root.desktopWidgets.map(w => w.key === key ? ({
                    key: w.key,
                    x: x,
                    y: y,
                    w: w.w
                }) : w));
    }

    // 卡片宽度。0 = 退回自然宽度。上下限由 DesktopLayer 按 token 夹，
    // 这里只挡住明显荒唐的值 —— core/ 读不到 Style（Style 自己要读 Config，
    // 两个单例互相引用会死锁）。
    function resizeWidget(key: string, w: real) {
        const v = w <= 0 ? 0 : Math.max(80, Math.min(2000, w));
        root.setWidgets(root.desktopWidgets.map(it => it.key === key ? ({
                    key: it.key,
                    x: it.x,
                    y: it.y,
                    w: v
                }) : it));
    }

    // 放置模式落位时用：带着坐标一步到位，不用先加再移
    function addWidgetAt(key: string, x: real, y: real) {
        if (root.hasWidget(key)) {
            root.moveWidget(key, x, y);
            return;
        }
        root.setWidgets([
                ...root.desktopWidgets,
                {
                    key: key,
                    x: x,
                    y: y,
                    w: 0
                }
            ]);
    }

    // x/y = -1 表示「还没定位」，交给 DesktopLayer 找位置
    function addWidget(key: string) {
        if (root.hasWidget(key))
            return;
        root.setWidgets([
                ...root.desktopWidgets,
                {
                    key: key,
                    x: -1,
                    y: -1,
                    w: 0
                }
            ]);
    }

    function removeWidget(key: string) {
        root.setWidgets(root.desktopWidgets.filter(w => w.key !== key));
    }

    function toggleWidget(key: string) {
        if (root.hasWidget(key))
            root.removeWidget(key);
        else
            root.addWidget(key);
    }

    FileView {
        id: file

        path: `${Quickshell.shellDir}/config.json`
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: cfg

            property string theme: "gruvbox"
            property string layout: "topbar"
            property string launcher: "list"   // list | ring，见 shell.qml 的启动器注册
            property string lockBackground: "blur"  // blur | stars，见 modules/LockScene
            property string wallpaper: ""
            property string wallpaperDir: ""   // 空 = ~/Pictures
            property bool wallpaperAuto: true  // 总开关
            property int wallpaperInterval: 30 // 分钟
            property var desktopWidgets: []    // [{ key, x, y, w }]，目录见 modules/DesktopWidgets.qml
            property var launcherUsage: ({})   // { desktopId: 启动次数 }，启动器排序用
            property string weatherCity: ""    // 空 = 天气卡不发请求
            property int weatherInterval: 15   // 分钟
            property bool autoTheme: true
        }
    }
}
