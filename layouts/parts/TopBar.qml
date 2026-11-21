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

        // ── 左：徽标 ──────────────────────────────────────
        // 不进 leftGroup：那条 RowLayout 的 spacing 是栏上通用的那档，
        // 而徽标要比它更贴边、和右边挨得更紧（见 Style.logoInset / logoGap）。
        // 单拎出来各锚各的，两边互不牵扯。
        LauncherButton {
            id: logo

            anchors.left: parent.left
            anchors.leftMargin: Style.logoInset
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── 左：工作区 + 当前窗口 ──────────────────────────
        RowLayout {
            id: leftGroup

            anchors.left: logo.right
            anchors.leftMargin: Style.logoGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space.s

            Workspaces {
                id: workspaces
            }

            ActiveWindow {
                // 不许顶到居中的时钟上：从这组的左沿量到时钟左沿，再把工作区
                // 占掉的那一截减掉 —— 工作区开着几个就有多宽，不是定值。
                // 徽标不用再减：leftGroup.x 已经是从它右边起算的了。
                // 读 implicitWidth 不读 width 是为了不跟布局自己较劲：
                // width 是布局算出来的，回头又喂给布局就成环了。
                maxWidth: Math.max(0, (win.width / 2) - clock.width / 2 - leftGroup.x - workspaces.implicitWidth - leftGroup.spacing - Style.space.l)
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
