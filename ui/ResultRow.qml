import QtQuick
import QtQuick.Layouts
import "root:/core"

// 列表里的一条结果：图标位 + 主标题 + 副标题 + 右侧类型标签。
//
// 和同族两个的分工：ui/MenuRow 是「在一组里选一个」（带对勾），
// ui/Tile 是「进到下一层」（带当前值），这个是「列表里的一条，可以被键盘选中」。
//
// 尺寸默认取 launcher 那组 token —— 行高、图标大小、要不要副标题，
// 是主题的事，不该让 modules/Launcher 去判断。
Surface {
    id: root

    property string title: ""
    property string subtitle: ""
    property string tag: ""             // 右侧类型标签：应用 / 窗口 / 命令
    property string source: ""          // 图标名或路径，交给 StyledIcon 归一化
    property string glyph: ""           // 查不到图标时的字形兜底
    property bool selected: false
    property int iconSize: Style.launcher.iconSize
    property bool showSubtitle: Style.launcher.subtitle

    readonly property bool hasIcon: root.iconSize > 0

    implicitHeight: Style.launcher.rowHeight
    level: 1
    bordered: false
    radius: Style.shape.radiusM
    tint: root.selected ? Style.color.selected : root.hovered ? Style.color.hover : "transparent"
    clickable: true
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space.s
        anchors.rightMargin: Style.space.s
        spacing: Style.space.s

        StyledIcon {
            id: ico

            visible: root.hasIcon
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            source: root.source
            glyph: root.glyph
            tone: root.selected ? "onSelected" : root.hovered ? "onHover" : "normal"
            size: root.iconSize
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                tone: root.selected ? "onSelected" : root.hovered ? "onHover" : "normal"
                elide: Text.ElideRight
            }

            // 选中行的底色可能是实心 accent，副标题再用 dim 就糊成一片；
            // 那时改用 onSelected 并压一点透明度，层次还在，可读性也在。
            StyledText {
                Layout.fillWidth: true
                visible: root.showSubtitle && root.subtitle !== ""
                text: root.subtitle
                role: "label"
                tone: root.selected ? "onSelected" : root.hovered ? "onHover" : "dim"
                opacity: root.selected || root.hovered ? 0.75 : 1
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: root.tag !== ""
            text: root.tag
            role: "label"
            tone: root.selected ? "onSelected" : root.hovered ? "onHover" : "dim"
            opacity: root.selected || root.hovered ? 0.75 : 1
        }
    }
}
