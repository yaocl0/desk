import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/ui"
import "root:/modules"
import "root:/layouts/parts"

// 顶栏 + 底部 Dock。这是"一个布局 = 多个窗口"的例子 ——
// 顶栏部件直接复用 TopBarLayout 的那个，Dock 是第二个窗口。
Scope {
    id: root

    required property var screen

    TopBar {
        barScreen: root.screen
    }

    PanelWindow {
        screen: root.screen
        color: "transparent"
        WlrLayershell.namespace: "desk"

        // 只锚底部 → 自动水平居中；不占用窗口区域，悬浮在内容之上
        anchors.bottom: true
        margins.bottom: Math.max(Style.space.barMargin, Style.space.s)
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: dock.implicitWidth + Style.space.m * 2
        implicitHeight: dock.implicitHeight + Style.space.s * 2

        visible: dock.apps.length > 0

        Surface {
            anchors.fill: parent
            level: 2
            radius: Style.shape.radiusFull > 0 ? Math.min(Style.shape.radiusFull, height / 2) : Style.shape.radiusM

            Dock {
                id: dock

                anchors.centerIn: parent
            }
        }
    }
}
