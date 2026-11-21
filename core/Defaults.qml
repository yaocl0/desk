pragma Singleton

import Quickshell

// 内置 token 兜底树。themes/*.json 合并到这棵树上，
// 所以主题文件可以只写想改的字段，写错 / 缺字段也不会让 shell 崩。
Singleton {
    readonly property var tokens: ({
            // 故意是中性灰：主题加载失败时一眼看得出来退回了默认
            color: {
                background: "#1c1c1c",
                surface: "#2a2a2a",
                surfaceAlt: "transparent",
                onBackground: "#d0d0d0",
                onSurface: "#d0d0d0",
                onSurfaceDim: "#707070",
                accent: "#8a8a8a",
                onAccent: "#1c1c1c",
                // 选中项的底色 / 其上的文字色。
                // 极简主题把 selected 设成 transparent，选中就只是文字变色；
                // 圆角主题把它设成 accent，选中就是一颗实心药丸。同一棵组件树。
                selected: "transparent",
                onSelected: "#8a8a8a",
                hover: "#383838",   // 悬停高亮底色（菜单项等）
                // 悬停底色上的文字色。空 = 继承 onSurface。
                // 和 selected/onSelected 是一对的道理：hover 一旦是不透明的亮色
                // （见 themes/pastel.json），文字就必须跟着翻过来，否则白底白字。
                onHover: "",
                success: "#7a9a7a",
                warning: "#9a8a6a",
                error: "#9a6a6a",
                outline: "#3a3a3a"
            },
            // 每个组件自己的药丸底色。默认全透明 —— 主题不写就是现在这样，
            // 想要"彩色药丸条"的主题（见 themes/pastel.json）才逐个填。
            // module.on 是这些药丸上的文字色。
            module: {
                on: "",            // 空 = 继承 color.onSurface
                window: "transparent",
                clock: "transparent",
                network: "transparent",
                volume: "transparent",
                cpu: "transparent",
                memory: "transparent",
                battery: "transparent",
                alert: "transparent",
                tray: "transparent",
                pickerSettings: "transparent"
            },
            shape: {
                radiusS: 0,
                radiusM: 0,
                radiusL: 0,
                radiusFull: 0,
                // 栏本体的圆角。-1 = 跟随 radiusL。
                // 单独拆出来是因为 macOS 风格要「栏方、弹层圆」：
                // 菜单栏贴边且直角，但菜单/面板是圆角的。
                barRadius: -1,
                borderWidth: 0
            },
            space: {
                xs: 4,
                s: 6,
                m: 12,
                l: 20,
                barHeight: 28,
                barMargin: 0,      // 0 = 贴边，>0 = 悬浮
                barPadding: 12,
                popupWidth: 320,   // 通知 / 弹出面板宽度
                // 桌面组件层：卡片距屏幕边缘、卡片之间、卡片本身的宽度
                desktopMargin: 20,
                desktopGap: 12,
                cardWidth: 240
            },
            font: {
                family: "JetBrainsMono Nerd Font",
                sizeS: 11,
                sizeM: 12,
                sizeL: 16,
                weight: 400,
                letterSpacing: 0
            },
            // 启动器的形态。组件树只有一棵，四个主题靠这一组 token 长成
            // dmenu 条 / Spotlight / M3 卡 / 大字彩色面板。
            launcher: {
                width: 520,         // 面板宽；0 = 跟随屏幕宽（两侧留 space.m）
                align: "center",    // center | top（top = 贴在栏的正下方）
                offsetY: 0,         // 对齐之后再偏移，负数上移
                inputHeight: 40,
                rowHeight: 36,
                rows: 8,            // 结果区最多显示几行，超出滚动
                iconSize: 24,       // 0 = 不画图标（dmenu 风）
                subtitle: true,     // 结果行是否带第二行说明
                scrim: 0,           // 背景压暗 0~1，0 = 全透
                // 面板自己的不透明度。-1 = 跟随 effect.opacity。
                // 单独拆出来是因为栏和弹层底下通常是壁纸，启动器底下是任意窗口 ——
                // 同一个 0.7，在壁纸上是玻璃，在一屏代码上就是看不清。
                opacity: -1,
                hint: true          // 底部快捷键提示条
            },
            motion: {
                enabled: false,
                fast: 100,
                normal: 200,
                easing: "outCubic",
                wallpaper: 2000   // 壁纸转场时长，独立于 enabled
            },
            effect: {
                opacity: 1.0,      // <1 时 Hyprland 的 blur 才看得见
                barOpacity: 1.0,   // 栏底单独的透明度，不影响弹层
                elevation: 0,
                // 壁纸转场：格子边长(px)、辉光强度、生长原点数
                wallpaperCell: 3,
                wallpaperGlow: 0.85,
                wallpaperSeeds: 8
            }
        })
}
