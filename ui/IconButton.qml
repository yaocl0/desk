import QtQuick
import "root:/core"

// 栏里的图标按钮。和 Pill 的区别：Pill 的默认属性走内部 RowLayout，
// 塞不了 PopupWindow 这种非布局子项；这个直接继承 Surface 的 data。
Surface {
    id: root

    property string glyph: ""
    property string tone: "normal"
    property bool active: false
    property string moduleKey: ""

    readonly property color baseTint: root.moduleKey === "" ? Style.color.surfaceAlt : Style.moduleColor(root.moduleKey)

    level: 1
    clickable: true
    tint: root.active ? Style.color.selected : root.hovered ? Style.color.hover : root.baseTint
    radius: Style.shape.radiusFull > 0 ? Math.min(Style.shape.radiusFull, height / 2) : Style.shape.radiusM

    implicitWidth: Style.font.sizeL + Style.space.s * 2
    implicitHeight: Style.font.sizeM + Style.space.xs * 2

    StyledIcon {
        anchors.centerIn: parent
        glyph: root.glyph
        tone: root.active ? "onSelected" : root.hovered ? "onHover" : root.moduleKey !== "" ? "onModule" : root.tone
        size: Style.font.sizeM
    }
}
