import QtQuick
import QtQuick.Layouts
import "root:/core"

// 菜单式可选行：左边一个对勾位，右边文字。
// 主题 / 布局 / 桌面组件三处都用它 —— 之前这段在 ThemePicker 里抄了两遍。
//
// macOS 菜单的做法：未选中留一个空格而不是画空心圈，
// 这样勾和不勾的文字起始位置一致，列表不会左右跳。
Surface {
    id: root

    property string label: ""
    property string glyph: ""   // 空 = 不占位
    property bool checked: false

    signal activated

    Layout.fillWidth: true
    // 必须显式给 implicitWidth：否则 Layout.fillWidth 的行对 ColumnLayout 的
    // implicitWidth 贡献为 0，整个面板会被标签撑成一条
    implicitWidth: content.implicitWidth + Style.space.s * 2
    implicitHeight: Math.round(Style.font.sizeM * 1.9)
    level: 1
    bordered: false
    radius: Style.shape.radiusS
    tint: root.checked ? Style.color.selected : root.hovered ? Style.color.hover : "transparent"
    clickable: true
    onClicked: root.activated()

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.leftMargin: Style.space.s
        anchors.rightMargin: Style.space.s
        spacing: Style.space.s

        StyledText {
            text: root.checked ? "✓" : " "
            tone: root.checked ? "onSelected" : root.hovered ? "onHover" : "dim"
        }

        StyledIcon {
            visible: root.glyph !== ""
            glyph: root.glyph
            tone: root.checked ? "onSelected" : root.hovered ? "onHover" : "dim"
            size: Style.font.sizeM
        }

        StyledText {
            Layout.fillWidth: true
            text: root.label
            tone: root.checked ? "onSelected" : root.hovered ? "onHover" : "normal"
        }
    }
}
