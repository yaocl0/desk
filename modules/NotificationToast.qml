import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "root:/core"
import "root:/ui"

Surface {
    id: root

    required property var notif

    readonly property bool critical: root.notif.urgency === NotificationUrgency.Critical
    readonly property string accentTone: root.critical ? "error" : root.notif.urgency === NotificationUrgency.Low ? "dim" : "accent"

    level: 2
    radius: Style.shape.radiusL
    implicitHeight: content.implicitHeight + Style.space.m * 2

    clickable: true
    onClicked: root.notif.dismiss()

    // 紧急通知不自动消失
    Timer {
        running: !root.critical
        interval: root.notif.expireTimeout > 0 ? root.notif.expireTimeout : 5000
        onTriggered: root.notif.dismiss()
    }

    // 左侧紧急度色条
    Dot {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Style.space.s
        width: Style.space.xs / 2 + 1
        tone: root.critical ? "error" : "accent"
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Style.space.m
        anchors.leftMargin: Style.space.m + Style.space.s
        spacing: Style.space.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space.s

            StyledIcon {
                Layout.preferredWidth: Style.font.sizeM
                Layout.preferredHeight: Style.font.sizeM
                visible: root.notif.appIcon !== ""
                source: root.notif.appIcon
                size: Style.font.sizeM
            }

            StyledText {
                Layout.fillWidth: true
                role: "label"
                tone: root.accentTone
                text: root.notif.appName
                elide: Text.ElideRight
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.notif.summary
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.notif.body !== ""
            text: root.notif.body
            tone: "dim"
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Style.space.xs
            visible: root.notif.actions.length > 0
            spacing: Style.space.s

            Repeater {
                model: root.notif.actions

                Pill {
                    id: act

                    required property var modelData

                    // 底色就是 hover 那个色，所以文字也得用配对的 onHover ——
                    // 不然 pastel（hover 是不透明亮色）下就是白底白字
                    tint: Style.color.hover
                    clickable: true
                    onClicked: act.modelData.invoke()

                    StyledText {
                        role: "label"
                        tone: "onHover"
                        text: act.modelData.text
                    }
                }
            }
        }
    }
}
