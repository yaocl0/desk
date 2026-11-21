import QtQuick
import QtQuick.Layouts
import "root:/core"
import "root:/ui"
import "root:/services"

// 设置面板。栏上只留这一个入口 —— 壁纸 / 主题 / 布局 / 桌面组件
// 原来是三个按钮、三个弹层，现在是一个按钮、一个弹层、两级导航。
//
// 页面不用 StackLayout 而是几块并排按 visible 切：StackLayout 的
// implicitHeight 取所有页的最大值，弹层会永远按最高那页（壁纸网格）撑开，
// 翻到只有三行的「布局」页时下面空一大片。
IconButton {
    id: root

    property var hostWindow: null

    // "" = 首页（磁贴），其余是二级页的 key
    property string page: ""

    readonly property var pages: [
        {
            key: "wallpaper",
            label: "壁纸",
            glyph: "󰸉"
        },
        {
            key: "theme",
            label: "主题",
            glyph: "󰸌"
        },
        {
            key: "layout",
            label: "布局",
            glyph: "󰕰"
        },
        {
            key: "launcher",
            label: "启动器",
            glyph: "󰍉"
        },
        {
            key: "lockbg",
            // 不叫「锁屏」：在一排设置磁贴里那读起来像个「点一下就锁屏」的按钮，
            // 而它其实是选背景样式的。二级页标题取的是同一个 label。
            label: "锁屏样式",
            glyph: "󰌾"
        },
        {
            key: "widgets",
            label: "桌面组件",
            glyph: "󰒓"
        }
    ]

    // 磁贴上的副标题：不用点进去就能看到当前是什么
    function valueOf(key: string): string {
        if (key === "wallpaper")
            return Wallpaper.path === "" ? "未设置" : Wallpaper.path.slice(Wallpaper.path.lastIndexOf("/") + 1);
        if (key === "theme")
            return Config.theme;
        if (key === "layout")
            return Config.layout;
        if (key === "launcher")
            return Config.launcher === "ring" ? "环形" : "列表";
        if (key === "lockbg")
            return root.lockLabel(Config.lockBackground);
        if (key === "widgets")
            return `${Config.desktopWidgets.length} 个`;
        return "";
    }

    // 磁贴副标题和二级页的行标用同一份映射，免得两处措辞飘开
    function lockLabel(name: string): string {
        return name === "stars" ? "星空" : "模糊桌面";
    }

    function titleOf(key: string): string {
        return root.pages.find(p => p.key === key)?.label ?? "";
    }

    glyph: "󰒓"
    moduleKey: "pickerSettings"
    active: popup.visible
    onClicked: {
        // 每次重新打开都回到首页，而不是停在上次翻到的那一页
        if (!popup.visible)
            root.page = "";
        popup.toggleFrom(root, root.hostWindow);
    }

    StyledPopup {
        id: popup

        // 固定宽度。否则壁纸页（3 列缩略图）和布局页（三行文字）宽度差一倍，
        // 来回翻页时弹层会忽胖忽瘦
        minWidth: Style.space.popupWidth
        spacing: 2

        // ── 二级页的返回条 ──────────────────────────────────
        Surface {
            id: back

            Layout.fillWidth: true
            Layout.bottomMargin: Style.space.xs
            visible: root.page !== ""
            implicitHeight: Math.round(Style.font.sizeM * 1.9)
            level: 1
            bordered: false
            radius: Style.shape.radiusS
            tint: back.hovered ? Style.color.hover : "transparent"
            clickable: true
            onClicked: root.page = ""

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space.s
                anchors.rightMargin: Style.space.s
                spacing: Style.space.s

                StyledIcon {
                    glyph: "󰅁"
                    tone: back.hovered ? "onHover" : "normal"
                    size: Style.font.sizeM
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.titleOf(root.page)
                    tone: back.hovered ? "onHover" : "normal"
                }
            }
        }

        // ── 首页：磁贴 ─────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            visible: root.page === ""
            columns: 2
            columnSpacing: Style.space.s
            rowSpacing: Style.space.s

            Repeater {
                model: root.pages

                Tile {
                    required property var modelData
                    required property int index

                    // 磁贴是奇数个时最后一块跨满两列 —— 否则右边空半格。
                    // 偶数个时恒为 1，不影响原来四块的排法。
                    Layout.columnSpan: root.pages.length % 2 === 1 && index === root.pages.length - 1 ? 2 : 1

                    glyph: modelData.glyph
                    label: modelData.label
                    value: root.valueOf(modelData.key)
                    onActivated: root.page = modelData.key
                }
            }
        }

        // ── 首页：亮度 ─────────────────────────────────────
        // 没有背光设备（台式接外显）时整条不出现，而不是摆一条拖不动的
        Slider {
            Layout.fillWidth: true
            Layout.topMargin: Style.space.s
            visible: root.page === "" && Backlight.available
            glyph: "󰌵"
            value: Backlight.level
            onMoved: v => Backlight.set(v)
        }

        // ── 壁纸 ──────────────────────────────────────────
        WallpaperGrid {
            Layout.fillWidth: true
            visible: root.page === "wallpaper"
            onPicked: popup.close()
        }

        // ── 主题 ──────────────────────────────────────────
        Repeater {
            model: Config.themes

            MenuRow {
                required property string modelData

                visible: root.page === "theme"
                label: modelData
                checked: Config.theme === modelData
                onActivated: Config.setTheme(modelData)
            }
        }

        // ── 布局 ──────────────────────────────────────────
        Repeater {
            model: Config.layouts

            MenuRow {
                required property string modelData

                visible: root.page === "layout"
                label: modelData
                checked: Config.layout === modelData
                onActivated: Config.setLayout(modelData)
            }
        }

        // ── 启动器 ────────────────────────────────────────
        // 切换是即时生效的：shell.qml 里两个 LazyLoader 按 config.launcher
        // 二选一，写回 config.json 的下一帧旧的那套就整个销毁了。
        Repeater {
            model: Config.launchers

            MenuRow {
                required property string modelData

                visible: root.page === "launcher"
                label: modelData === "ring" ? "环形" : "列表"
                checked: Config.launcher === modelData
                onActivated: Config.setLauncher(modelData)
            }
        }

        // ── 锁屏背景 ───────────────────────────────────────
        // 不只是换张图：选星空时 core/LockState 根本不会去截屏，
        // 锁得更快，盘上也不留那张全屏图。
        Repeater {
            model: Config.lockBackgrounds

            MenuRow {
                required property string modelData

                visible: root.page === "lockbg"
                label: root.lockLabel(modelData)
                checked: Config.lockBackground === modelData
                onActivated: Config.setLockBackground(modelData)
            }
        }

        // ── 桌面组件 ───────────────────────────────────────
        Repeater {
            model: DesktopWidgets.catalog

            MenuRow {
                required property var modelData

                visible: root.page === "widgets"
                label: modelData.label
                glyph: modelData.glyph
                checked: Config.hasWidget(modelData.key)
                onActivated: {
                    // 已经在桌面上 → 点一下拿掉；不在 → 拿起来，由你自己放
                    if (Config.hasWidget(modelData.key)) {
                        Config.removeWidget(modelData.key);
                        return;
                    }
                    DesktopWidgets.placing = modelData.key;
                    popup.close();
                }
            }
        }
    }
}
