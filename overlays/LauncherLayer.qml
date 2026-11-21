import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/modules"

// 启动器的窗口层。和通知层一样不随布局切换 —— topbar / island / dock 下都在。
//
// 分工：这里管窗口、遮罩、定位、点外面关掉；面板内容在 modules/Launcher.qml。
Scope {
    id: root

    required property var screen

    // 只在打开它的那块屏上出现。latch 不到屏幕名（没跑 Hyprland）时
    // 退化成「每块屏都出一个」—— 单屏下没区别，多屏下至少不会一块都没有。
    readonly property bool onThisScreen: LauncherState.screenName === "" || LauncherState.screenName === root.screen.name

    PanelWindow {
        id: win

        screen: root.screen
        visible: LauncherState.open && root.onThisScreen

        // 遮罩。scrim = 0 的主题（gruvbox）这里就是全透明，
        // 只有面板本身看得见，桌面一点都不压暗。
        color: Style.alpha(Style.color.background, Style.launcher.scrim)

        // 盖在所有窗口之上；namespace 仍是 desk，于是继承既有的 layerrule，
        // 玻璃主题下面板自动带模糊，不用为启动器再配一条规则。
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "desk"
        // 要打字就必须独占键盘。关掉的瞬间焦点自动还给原来的窗口。
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // 尊重栏预留的区域：于是 y = 0 就是栏的正下方，
        // align: "top" 的 dmenu 条自动贴在栏下沿，而不是被栏压住。
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // 打开时清空上次的查询并把焦点放进输入框。
        // 不这么做的话，窗口虽然起来了，键盘事件没人接，打字全丢。
        onVisibleChanged: {
            if (win.visible)
                panel.reset();
        }

        // 点在面板外面关掉。面板自己是 Surface，带 MouseArea，
        // 落在面板上的点击不会穿到这一层来。
        MouseArea {
            anchors.fill: parent
            onClicked: LauncherState.hide()
        }

        Launcher {
            id: panel

            // width = 0 的主题要的是「铺满一整行」的 dmenu 条，所以不留边距；
            // 其余主题用 token 给的固定宽度，由 Launcher 自己的 implicitWidth 决定。
            width: Style.launcher.width > 0 ? Style.launcher.width : win.width
            x: Math.round((win.width - panel.width) / 2)
            y: Math.round(Style.launcher.align === "top" ? 0 : (win.height - panel.height) / 2) + Style.launcher.offsetY + (win.visible ? 0 : Style.space.m)

            opacity: win.visible ? 1 : 0

            onDismissed: LauncherState.hide()

            // 淡入 + 轻微上移。motion.enabled 关着的主题直接硬出现。
            Behavior on opacity {
                enabled: Style.motion.enabled

                NumberAnimation {
                    duration: Style.durFast
                    easing.type: Style.easing
                }
            }
            Behavior on y {
                enabled: Style.motion.enabled

                NumberAnimation {
                    duration: Style.durFast
                    easing.type: Style.easing
                }
            }
        }
    }
}
