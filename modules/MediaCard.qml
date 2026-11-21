import QtQuick
import QtQuick.Layouts
import "root:/core"
import "root:/ui"
import "root:/services"

// 正在播放卡。MPRIS 上没有播放器时也保留卡片本身，
// 只是内容换成一行灰字 —— 卡片忽隐忽现会让整叠桌面组件上下跳。
Card {
    id: root

    // 封面跟着卡片宽度长，但不小于三行字高 —— 窄的时候别缩成一个点
    readonly property int artSize: Math.max(Style.font.sizeL * 3, Math.round(root.contentWidth * 0.3))

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space.m

        // 封面。拿不到图就退回一个音符字形，不留一块空洞
        Surface {
            implicitWidth: root.artSize
            implicitHeight: root.artSize
            level: 1
            radius: Style.shape.radiusS

            StyledIcon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                glyph: "󰝚"
                tone: "dim"
                size: Style.font.sizeL
            }

            Image {
                id: cover

                anchors.fill: parent
                source: Mpris.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(root.artSize, root.artSize)
                clip: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space.xs

            StyledText {
                Layout.fillWidth: true
                role: "title"
                elide: Text.ElideRight
                text: Mpris.active ? Mpris.title : "没有正在播放"
                tone: Mpris.active ? "normal" : "dim"
            }

            StyledText {
                Layout.fillWidth: true
                role: "label"
                tone: "dim"
                elide: Text.ElideRight
                visible: Mpris.active
                text: Mpris.artist !== "" ? Mpris.artist : Mpris.app
            }

            RowLayout {
                spacing: Style.space.xs
                visible: Mpris.active

                IconButton {
                    glyph: "󰒮"
                    enabled: Mpris.canPrev
                    opacity: Mpris.canPrev ? 1.0 : 0.4
                    onClicked: Mpris.previous()
                }

                IconButton {
                    glyph: Mpris.playing ? "󰏤" : "󰐊"
                    active: Mpris.playing
                    onClicked: Mpris.toggle()
                }

                IconButton {
                    glyph: "󰒭"
                    enabled: Mpris.canNext
                    opacity: Mpris.canNext ? 1.0 : 0.4
                    onClicked: Mpris.next()
                }
            }
        }
    }

    // 进度条。播放器不报时长时 Mpris.length 是 0，整条自己隐掉
    Surface {
        Layout.fillWidth: true
        implicitHeight: Style.space.xs
        visible: Mpris.length > 0
        level: 1
        bordered: false
        radius: Style.shape.radiusS
        tint: Style.color.outline

        Surface {
            width: parent.width * Mpris.progress
            height: parent.height
            level: 1
            bordered: false
            radius: parent.radius
            tint: Style.color.accent
        }
    }
}
