import QtQuick
import QtQuick.Layouts
import "root:/core"

// Surface + 内边距 + 横向排列。
//
// moduleKey 指向主题的 module 色组，让每个组件有自己的药丸底色
// （themes/pastel.json 是这套配色的样板）。主题不填 module 段时
// 一律退回 surfaceAlt —— gruvbox 下那是 transparent，药丸就隐形。
Surface {
    id: root

    default property alias content: row.data

    property string moduleKey: ""
    property int hPadding: Style.space.s
    property int vPadding: Style.space.xs

    tint: root.moduleKey === "" ? Style.color.surfaceAlt : Style.moduleColor(root.moduleKey)
    radius: Style.shape.radiusFull > 0 ? Math.min(Style.shape.radiusFull, height / 2) : Style.shape.radiusM

    implicitWidth: row.implicitWidth + root.hPadding * 2
    implicitHeight: row.implicitHeight + root.vPadding * 2

    // anchors.fill 而不是 centerIn：这样内部的 Layout.fillWidth 子项
    // 在宽度被外部限制时才能真正收缩并 elide（窗口标题要用）。
    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: root.hPadding
        anchors.rightMargin: root.hPadding
        anchors.topMargin: root.vPadding
        anchors.bottomMargin: root.vPadding
        spacing: Style.space.xs
    }
}
