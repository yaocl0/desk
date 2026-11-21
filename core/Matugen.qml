import QtQml
import Quickshell
import Quickshell.Io

// 换壁纸时自动重算 material 主题的配色。
//
// 没有这一层的话，壁纸选择器和 `ipc call wallpaper set` 只改路径，
// matugen 根本不会跑 —— 换了壁纸配色纹丝不动。
//
// 不是 Singleton：QML 单例惰性创建，没人引用就不会实例化，
// 里面的 Connections 也就不会生效。由 shell.qml 显式实例化一次。
Scope {
    id: root

    // 上一次算过的壁纸，避免热重载后重复跑
    property string lastPath: ""

    function regenerate(path: string) {
        if (!Config.autoTheme || path === "" || path === root.lastPath)
            return;
        root.lastPath = path;
        // --theme-only：只写 themes/material.json，不回头去设壁纸/切主题，
        // 否则会把自己再触发一遍。
        gen.command = [`${Quickshell.shellDir}/tools/wallpaper-theme.sh`, "--theme-only", path];
        gen.running = true;
    }

    Connections {
        target: Config

        function onWallpaperChanged() {
            root.regenerate(Config.wallpaper);
        }
    }

    Process {
        id: gen

        running: false

        // 失败不该静默：没装 matugen、图片读不了都在这儿冒出来
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn(`[Matugen] ${this.text.trim()}`);
            }
        }

        onExited: code => {
            if (code !== 0)
                console.warn(`[Matugen] 取色失败（退出码 ${code}），themes/material.json 保持原样`);
        }
    }
}
