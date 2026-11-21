import QtQuick
import QtQuick.Layouts
import "root:/core"

// 设置面板首页的磁贴：图标 + 标题 + 当前值，点进去是二级页。
//
// 和 MenuRow 的分工：那个是「在一组里选一个」（带对勾），
// 这个是「进到下一层」（带当前值）。两者都只发信号，不认识 Config。
Surface {
    id: root

    property string glyph: ""
    property string label: ""
    property string value: ""

    signal activated

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Style.space.m * 2
    level: 1
    bordered: false
    radius: Style.shape.radiusM
    tint: root.hovered ? Style.color.hover : Style.color.surfaceAlt
    clickable: true
    onClicked: root.activated()

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Style.space.m
        spacing: Style.space.s

        StyledIcon {
            glyph: root.glyph
            tone: root.hovered ? "onHover" : "accent"
            size: Style.font.sizeL
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                tone: root.hovered ? "onHover" : "normal"
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.value !== ""
                role: "label"
                tone: root.hovered ? "onHover" : "dim"
                text: root.value
                elide: Text.ElideRight
            }
        }
    }
}
