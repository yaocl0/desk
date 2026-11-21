import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import "root:/core"
import "root:/ui"

Pill {
    id: root

    property int maxWidth: Style.space.l * 20

    readonly property string title: ToplevelManager.activeToplevel?.title ?? ""

    moduleKey: "window"
    visible: root.title !== ""
    // 自己撑开，但不超过上限；超了交给内部文字 elide
    implicitWidth: Math.min(label.implicitWidth + Style.space.m * 2 + root.hPadding * 2, root.maxWidth)

    StyledIcon {
        glyph: "󰖯"
        tone: "onModule"
        size: Style.font.sizeM
    }

    StyledText {
        id: label

        Layout.fillWidth: true
        text: root.title
        tone: "onModule"
        elide: Text.ElideRight
    }
}
