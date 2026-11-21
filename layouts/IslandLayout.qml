import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/ui"
import "root:/modules"

// 多个悬浮岛：左边工作区，中间时钟（悬停展开）。
// 用的是和 TopBarLayout 完全相同的 modules/。
Scope {
    id: root

    required property var screen

    // 两座岛共用的顶部间距 —— 各写各的迟早漂移，差 1px 就是肉眼可见的不齐
    readonly property int islandTop: Math.max(Style.space.barMargin, Style.space.xs)

    // ── 左岛：工作区 ──────────────────────────────────────────
    // 同时锚 top 和 left。中岛那种「只锚一边就自动居中」是 layer-shell 的
    // 规则，这里要的恰恰是不居中，所以必须把水平那边也锚死。
    PanelWindow {
        screen: root.screen
        color: "transparent"
        WlrLayershell.namespace: "desk"

        anchors.top: true
        anchors.left: true
        margins.top: root.islandTop
        // 水平方向不跟 xs：岛贴着屏幕边缘太紧，和中岛的悬浮感对不上
        margins.left: Math.max(Style.space.barMargin, Style.space.m)
        // 顶部那条带的空间由中岛一次性要下来（见下）。左岛必须 Ignore：
        // 两个 surface 各要一次，合成器会老老实实挖走两倍高度。
        // Ignore 同时意味着它不被那条预留区推下去 —— 正好落在带子里。
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: wsIsland.implicitWidth
        implicitHeight: Style.space.barHeight

        // Hyprland 还没连上时 shown 是空的，别先闪一颗空胶囊出来
        visible: wsRow.shown.length > 0

        Surface {
            id: wsIsland

            anchors.fill: parent
            level: 2
            radius: height / 2
            implicitWidth: wsRow.implicitWidth + Style.space.m * 2

            // 开关窗口时工作区会增减，让岛跟着长/缩而不是硬跳
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Style.durNormal
                    easing.type: Style.easing
                }
            }

            Workspaces {
                id: wsRow

                anchors.centerIn: parent
            }
        }
    }

    // ── 中岛：时钟，悬停展开成状态条 ──────────────────────────
    PanelWindow {
        id: win

        screen: root.screen
        color: "transparent"
        WlrLayershell.namespace: "desk"

        // 只锚顶部 → layer-shell 自动水平居中。
        // 不写 exclusionMode，用默认的 Auto：它按锚定边把「上边距 + 岛高」
        // 整条带向合成器要下来，窗口从岛下面开始排，岛不再盖在窗口上。
        // 预留放在中岛而不是左岛，是因为中岛始终可见 —— 工作区空了
        // 左岛会隐藏，顶部空间不该跟着一起塌掉。
        anchors.top: true
        margins.top: root.islandTop

        implicitWidth: capsule.implicitWidth
        implicitHeight: Style.space.barHeight

        Surface {
            id: capsule

            // 切换面板开着时保持展开：否则光标移进面板就离开了胶囊，
            // 胶囊一收起，面板赖以定位的那个按钮就没了。
            readonly property bool expanded: capsule.hovered || picker.active

            anchors.fill: parent
            level: 2
            radius: height / 2
            implicitWidth: content.implicitWidth + Style.space.l * 2

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Style.durNormal
                    easing.type: Style.easing
                }
            }

            RowLayout {
                id: content

                anchors.centerIn: parent
                spacing: Style.space.m

                Clock {}

                // 同一批 modules，窄处只留图标
                Network {
                    visible: capsule.expanded
                    showLabel: false
                }

                Volume {
                    visible: capsule.expanded
                }

                Battery {
                    visible: capsule.expanded
                }

                SettingsPanel {
                    id: picker

                    visible: capsule.expanded
                    hostWindow: win
                }
            }
        }
    }
}
