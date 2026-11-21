import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/ui"
import "root:/modules"

// 横贯顶部的栏。被 TopBarLayout 和 DockLayout 共用 ——
// 布局之间共享窗口部件，而不是复制一遍模块列表。
PanelWindow {
    id: win

    required property var barScreen

    screen: win.barScreen
    color: "transparent"
    WlrLayershell.namespace: "desk"

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Style.space.barMargin
        left: Style.space.barMargin
        right: Style.space.barMargin
    }
    implicitHeight: Style.space.barHeight

    Surface {
        anchors.fill: parent
        level: 0
        radius: Style.barRadius

        // ── 左：工作区 + 当前窗口 ──────────────────────────
        RowLayout {
            id: leftGroup

            anchors.left: parent.left
            anchors.leftMargin: Style.space.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space.s

            Workspaces {}

            ActiveWindow {
                // 不许顶到居中的时钟上
                maxWidth: Math.max(0, (win.width / 2) - clock.width / 2 - leftGroup.x - Style.space.l * 2)
            }
        }

        // ── 中：时钟 ──────────────────────────────────────
        Clock {
            id: clock

            anchors.centerIn: parent
        }

        // ── 右：状态 + 托盘 + 切换按钮 ────────────────────
        RowLayout {
            id: rightGroup

            anchors.right: parent.right
            anchors.rightMargin: Style.space.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space.s

            Network {}

            Volume {}

            Memory {}

            Cpu {}

            Battery {}

            Tray {
                hostWindow: win
            }

            SettingsPanel {
                hostWindow: win
            }
        }
    }
}
