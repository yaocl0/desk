import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/services"
import "root:/modules"

// 不随布局切换的全屏层。topbar / island / dock 下都在。
Scope {
    id: root

    required property var screen

    PanelWindow {
        screen: root.screen
        color: "transparent"
        WlrLayershell.namespace: "desk"

        visible: Notif.active.length > 0

        anchors {
            top: true
            right: true
        }
        margins {
            top: Style.space.m
            right: Style.space.m
        }

        // 自己不占位，但尊重栏already预留的区域 → 自动落在栏下面
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        implicitWidth: Style.space.popupWidth
        implicitHeight: stack.implicitHeight

        ColumnLayout {
            id: stack

            anchors.fill: parent
            spacing: Style.space.s

            Repeater {
                model: Notif.active

                NotificationToast {
                    required property var modelData

                    Layout.fillWidth: true
                    notif: modelData
                }
            }
        }
    }
}
