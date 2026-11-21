import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/core"

// 两种图标来源：Nerd Font 字形（glyph）或图标名/路径/URL（source）。
//
// source 统一在这里归一化，调用方可以随便传：
//   "firefox"                      图标主题名 → 过 Quickshell.iconPath 查
//   "/usr/lib/kitty/logo/kitty.png" 绝对路径 → 补 file:// 前缀
//   "image://icon/foo"             已经是 URL → 原样用
// 不补 file:// 的话，Image 会把裸路径按相对路径解析成 qrc:/usr/lib/...，直接加载失败。
Item {
    id: root

    property string glyph: ""
    property string source: ""
    property string tone: "normal"
    property int size: Style.font.sizeL

    readonly property url resolved: {
        const s = root.source;
        if (s === "")
            return "";
        if (s.includes("://"))
            return s;
        const p = s.startsWith("/") ? s : Quickshell.iconPath(s, true);
        if (p === "")
            return "";
        return p.includes("://") ? p : `file://${p}`;
    }

    implicitWidth: root.size
    implicitHeight: root.size

    StyledText {
        anchors.centerIn: parent
        visible: root.resolved == ""
        text: root.glyph
        tone: root.tone
        font.pixelSize: root.size
        horizontalAlignment: Text.AlignHCenter
    }

    IconImage {
        anchors.fill: parent
        visible: root.resolved != ""
        source: root.resolved
    }
}
