import QtQuick
import QtQuick.Layouts
import "root:/core"
import "root:/ui"

// 壁纸相册卡。数据全部来自 core/Wallpaper —— 不碰 services/，
// 和壁纸选择器、定时轮换共用同一份候选列表和同一个 next()。
Card {
    id: root

    readonly property int thumbW: root.contentWidth

    StyledText {
        Layout.fillWidth: true
        role: "label"
        tone: "dim"
        elide: Text.ElideMiddle
        text: Wallpaper.path === "" ? "未设置壁纸" : Wallpaper.path.slice(Wallpaper.path.lastIndexOf("/") + 1)
    }

    Image {
        Layout.preferredWidth: root.thumbW
        Layout.preferredHeight: Math.round(root.thumbW * 9 / 16)
        source: Wallpaper.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.thumbW, Math.round(root.thumbW * 9 / 16))
        clip: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space.s

        StyledText {
            Layout.fillWidth: true
            role: "label"
            tone: "dim"
            text: Config.wallpaperInterval > 0 ? `${Wallpaper.count} 张 · 每 ${Config.wallpaperInterval} 分钟` : `${Wallpaper.count} 张 · 不轮换`
        }

        IconButton {
            glyph: "󰒭"
            onClicked: Wallpaper.next()
        }
    }
}
