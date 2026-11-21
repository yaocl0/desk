import QtQuick
import "root:/core"

// 栏里的图标按钮。和 Pill 的区别：Pill 的默认属性走内部 RowLayout，
// 塞不了 PopupWindow 这种非布局子项；这个直接继承 Surface 的 data。
Surface {
    id: root

    property string glyph: ""
    // 图标主题名 / 路径，非空时顶掉 glyph（归一化在 StyledIcon 里）
    property string source: ""
    property int iconSize: Style.font.sizeM
    // 左右内边距，和 Pill.hPadding 一个意思。栏上那排按钮用默认值，
    // 徽标要贴边，自己压小（见 modules/LauncherButton）。
    property int hPadding: Style.space.s

    // 默认值是个绑定：挂了 moduleKey 就用药丸上的文字色，和 Pill 里那些
    // tone: "onModule" 是一个规矩。调用方显式写 tone 就按它来 ——
    // 主题要把发行版徽标单独染成品牌色，靠的就是这条。
    property string tone: root.moduleKey === "" ? "normal" : "onModule"
    property bool active: false
    property string moduleKey: ""

    readonly property color baseTint: root.moduleKey === "" ? Style.color.surfaceAlt : Style.moduleColor(root.moduleKey)

    level: 1
    clickable: true
    tint: root.active ? Style.color.selected : root.hovered ? Style.color.hover : root.baseTint
    radius: Style.shape.radiusFull > 0 ? Math.min(Style.shape.radiusFull, height / 2) : Style.shape.radiusM

    // 取 max 而不是直接用 iconSize：默认档（iconSize = sizeM）下得出的
    // 还是原来那两个值，栏上那排按钮一点不动；只有徽标这种放大的才撑开。
    implicitWidth: Math.max(Style.font.sizeL, root.iconSize) + root.hPadding * 2
    implicitHeight: Math.max(Style.font.sizeM, root.iconSize) + Style.space.xs * 2

    StyledIcon {
        anchors.centerIn: parent
        glyph: root.glyph
        source: root.source
        tone: root.active ? "onSelected" : root.hovered ? "onHover" : root.tone
        size: root.iconSize
    }
}
