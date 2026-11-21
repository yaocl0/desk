import QtQuick
import QtQuick.Layouts
import "root:/core"
import "root:/ui"

// 壁纸缩略图网格。原来长在 WallpaperPicker 里连着按钮和弹层，
// 现在只是设置面板的一页 —— 不管自己怎么被打开。
ColumnLayout {
    id: root

    signal picked

    readonly property int columns: 3
    // GridView 的 cellWidth 含间距，所以先定 cell 再反推缩略图宽，
    // 否则 columns * cellWidth 会超出内容区，挤掉最后一列。
    readonly property int cellW: Math.round(Style.space.popupWidth / root.columns)
    readonly property int thumbW: root.cellW - Style.space.s
    readonly property int thumbH: Math.round(root.thumbW * 9 / 16)

    spacing: Style.space.s

    StyledText {
        role: "label"
        tone: "dim"
        text: Wallpaper.count > 0 ? `${Config.wallpaperDir}  ·  ${Wallpaper.count} 张` : `${Config.wallpaperDir} 下没有图片`
    }

    GridView {
        Layout.preferredWidth: root.columns * root.cellW
        Layout.preferredHeight: Math.min(3, Math.max(1, Math.ceil(Wallpaper.count / root.columns))) * (root.thumbH + Style.space.s)
        visible: Wallpaper.count > 0

        cellWidth: root.cellW
        cellHeight: root.thumbH + Style.space.s
        clip: true
        model: Wallpaper.files

        delegate: Surface {
            id: thumb

            required property string filePath
            required property url fileUrl

            readonly property bool current: Config.wallpaper === thumb.filePath

            width: root.thumbW
            height: root.thumbH
            level: 1
            radius: Style.shape.radiusS
            tint: thumb.current ? Style.color.selected : thumb.hovered ? Style.color.hover : Style.color.surfaceAlt
            clickable: true

            onClicked: {
                Wallpaper.set(thumb.filePath);
                root.picked();
            }

            Image {
                anchors.fill: parent
                anchors.margins: thumb.current ? Style.space.xs / 2 : 0
                source: thumb.fileUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(root.thumbW, root.thumbH)
                clip: true
            }
        }
    }

    // ── 自动切换 ──────────────────────────────────────────
    Dot {
        Layout.fillWidth: true
        Layout.topMargin: Style.space.xs
        Layout.bottomMargin: Style.space.xs
        implicitHeight: 1
        tone: "outline"
    }

    MenuRow {
        label: "自动切换壁纸"
        glyph: "󰑐"
        checked: Config.wallpaperAuto
        onActivated: Config.setWallpaperAuto(!Config.wallpaperAuto)
    }

    // 间隔只在开着的时候才列 —— 关掉还摆一排不起作用的选项是噪音
    Repeater {
        model: Config.wallpaperIntervals

        MenuRow {
            required property int modelData

            visible: Config.wallpaperAuto
            label: modelData < 60 ? `${modelData} 分钟` : `${Math.round(modelData / 60)} 小时`
            checked: Config.wallpaperInterval === modelData
            onActivated: Config.setWallpaperInterval(modelData)
        }
    }
}
