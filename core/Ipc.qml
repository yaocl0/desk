import Quickshell
import Quickshell.Io

// qs ipc call style theme glass
// qs ipc call style launcher ring
// qs ipc call style lockbg stars
// qs ipc call style layout island
// qs ipc call style list
//
// 不是 Singleton：QML 单例是惰性创建的，没人引用就不会实例化，
// IpcHandler 也就注册不上。改成普通组件，由 shell.qml 显式实例化一次。
Scope {
    IpcHandler {
        target: "style"

        function theme(name: string): string {
            if (!Config.themes.includes(name))
                return `未知主题 "${name}"，可用：${Config.themes.join(", ")}`;
            Config.setTheme(name);
            return `theme -> ${name}`;
        }

        function layout(name: string): string {
            if (!Config.layouts.includes(name))
                return `未知布局 "${name}"，可用：${Config.layouts.join(", ")}`;
            Config.setLayout(name);
            return `layout -> ${name}`;
        }

        function launcher(name: string): string {
            if (!Config.launchers.includes(name))
                return `未知启动器 "${name}"，可用：${Config.launchers.join(", ")}`;
            Config.setLauncher(name);
            return `launcher -> ${name}`;
        }

        function lockbg(name: string): string {
            if (!Config.lockBackgrounds.includes(name))
                return `未知锁屏背景 "${name}"，可用：${Config.lockBackgrounds.join(", ")}`;
            Config.setLockBackground(name);
            return `lockbg -> ${name}`;
        }

        function list(): string {
            const rotate = Config.wallpaperAuto && Config.wallpaperInterval > 0 ? `自动切换 每 ${Config.wallpaperInterval} 分钟` : "自动切换 关";
            return `themes:   ${Config.themes.join(" ")}  (当前 ${Config.theme})\n` + `layouts:  ${Config.layouts.join(" ")}  (当前 ${Config.layout})\n` + `launcher: ${Config.launchers.join(" ")}  (当前 ${Config.launcher})\n` + `lockbg:   ${Config.lockBackgrounds.join(" ")}  (当前 ${Config.lockBackground})\n` + `wallpaper: ${Config.wallpaper || "(未设置)"}  (${rotate})`;
        }
    }

    // qs ipc call launcher toggle / open / close
    //
    // 启动器没有自己的快捷键 —— 绑哪个键是 Hyprland 那边的事，
    // 这里只提供入口：bind = SUPER, SPACE, exec, qs -p <仓库> ipc call launcher toggle
    IpcHandler {
        target: "launcher"

        function toggle(): string {
            LauncherState.toggle();
            return LauncherState.open ? "launcher -> 打开" : "launcher -> 关闭";
        }

        function open(): string {
            LauncherState.show();
            return `launcher -> 打开 @ ${LauncherState.screenName || "(未知屏幕)"}`;
        }

        function close(): string {
            LauncherState.hide();
            return "launcher -> 关闭";
        }

        function state(): string {
            return LauncherState.open ? `打开 @ ${LauncherState.screenName || "(未知屏幕)"}` : "关闭";
        }
    }

    // qs ipc call lock lock
    //
    // 只有「锁上」没有「解锁」：解锁的唯一途径是在锁屏上输对密码。
    // 预览入口 lock.qml 里那个 close 是预览专用的，不在这儿暴露。
    //
    // 真正绑键 / 接 hypridle 的是 hypr/desk-lock.sh，不是直接调这个 ——
    // 那个脚本在 shell 不可达时会退回 hyprlock，保证「锁不上」不会发生。
    IpcHandler {
        target: "lock"

        function lock(): string {
            LockState.lock();
            return "lock -> 锁定";
        }

        // 开机自启动走这个：那会儿桌面还是空的，拍屏当背景只会得到一片死灰，
        // 直接用模糊壁纸。只有 hyprland.lua 的 autostart 该调它。
        function lockBoot(): string {
            LockState.lock(false);
            return "lock -> 锁定（开机，不拍屏）";
        }

        // 屏幕亮回来的那一下调过来，把熄屏期间打进密码框的东西清掉。
        // 挂在 hypridle 关屏那个 listener 的 on-resume 上：
        //   on-resume = hyprctl dispatch '...dpms enable...' ; qs -p <仓库> ipc call lock wake
        // 详见 core/LockState.qml 的 wake()。没锁着的时候它什么都不做。
        function wake(): string {
            if (!LockState.wanted)
                return "lock -> 未锁定，无事可做";
            LockState.wake();
            return "lock -> 已清空输入";
        }

        // 给脚本用。不让 hypr/desk-lock.sh 去匹配下面那句中文 ——
        // 哪天改个措辞，脚本就悄悄失效了，而它失效的方式是「不锁屏」。
        function isLocked(): bool {
            return LockState.wanted;
        }

        function state(): string {
            if (LockState.unlocking)
                return "解锁中";
            return LockState.wanted ? "已锁定" : "未锁定";
        }
    }

    // qs ipc call wallpaper set /path/to/image.png
    // qs ipc call wallpaper next
    IpcHandler {
        target: "wallpaper"

        function set(path: string): string {
            if (!path.startsWith("/"))
                return `需要绝对路径，收到: ${path}`;
            Config.setWallpaper(path);
            return `wallpaper -> ${path}`;
        }

        // 手动推进一张，顺序和定时轮换一致。也方便绑快捷键 / 不用等满一个周期就能验。
        function next(): string {
            if (Wallpaper.count === 0)
                return `${Config.wallpaperDir} 下没有图片`;
            Wallpaper.next();
            return `wallpaper -> ${Config.wallpaper}`;
        }

        function get(): string {
            return Config.wallpaper || "(未设置)";
        }

        function clear(): string {
            Config.setWallpaper("");
            return "wallpaper 已清除";
        }
    }

    // qs ipc call desktop list / add calendar / remove calendar
    //              toggle weather / move calendar 700 120 / width weather 420
    //
    // 这里不校验组件名是否在目录里 —— 目录在 modules/DesktopWidgets.qml，
    // 而 core/ 不许反向依赖视觉层。拼错的名字只是加进数组后没人认领，
    // DesktopLayer 的 Loader 拿到 null 就什么都不加载，不会出错。
    // 要带校验的入口请用栏上那个齿轮面板。
    IpcHandler {
        target: "desktop"

        function list(): string {
            const on = Config.desktopWidgets;
            return on.length === 0 ? "(空)" : on.map(w => `${w.key}(${w.x},${w.y})`).join("  ");
        }

        function add(name: string): string {
            Config.addWidget(name);
            return `desktop -> ${Config.desktopWidgets.map(w => w.key).join(" ")}`;
        }

        function remove(name: string): string {
            Config.removeWidget(name);
            return `desktop -> ${Config.desktopWidgets.map(w => w.key).join(" ") || "(空)"}`;
        }

        function toggle(name: string): string {
            Config.toggleWidget(name);
            return `desktop -> ${Config.desktopWidgets.map(w => w.key).join(" ") || "(空)"}`;
        }

        // 卡片宽度（px）。给 0 退回自然宽度。
        function width(name: string, w: int): string {
            if (!Config.hasWidget(name))
                return `桌面上没有「${name}」`;
            Config.resizeWidget(name, w);
            const it = Config.desktopWidgets.find(i => i.key === name);
            return it.w === 0 ? `${name} -> 自然宽度` : `${name} -> 宽 ${it.w}`;
        }

        // 把某张卡挪到指定坐标（相对栏下面那块可用区域的左上角）。
        // 给 -1 就退回按序号错开的默认位置。
        function move(name: string, x: int, y: int): string {
            if (!Config.hasWidget(name))
                return `桌面上没有「${name}」`;
            Config.moveWidget(name, x, y);
            return x < 0 ? `${name} -> 默认位置` : `${name} -> (${x}, ${y})`;
        }
    }
}
