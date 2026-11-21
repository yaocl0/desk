import QtQuick
import QtQuick.Layouts
import "root:/core"
import "root:/ui"
import "root:/services"

// 天气卡。城市名和刷新间隔从 config.json 喂给 services/Weather ——
// 那一层是叶子，读不到 core/。喂的动作放在这张卡里而不是 shell.qml：
// 卡片被删掉时 Binding 跟着销毁，city 还原成空串，请求就真的停了。
Card {
    id: root

    readonly property bool configured: Config.weatherCity !== ""

    // 逐小时显示几列，由内容区宽度决定：卡片拖宽就多铺几列，
    // 服务那边一次给 12 个小时，够用。
    // 这一行是靠「多铺几列」吃掉多余宽度的，所以字号不用跟着变。
    readonly property int hourCols: Math.max(3, Math.min(Weather.hours.length, Math.floor(root.contentWidth / Math.round(Style.font.sizeL * 2.6))))

    // 实况那一块（城市 / 大温度 / 描述 / 高低温 / 天气图标）没有可铺的内容 ——
    // 多出来的宽度只会变成中间一片空白，图标被推到最右边。所以让它整体跟着长。
    // 相对自然宽度算倍数，夹在 1～2：再大就喧宾夺主了。
    readonly property real heroScale: Math.max(1, Math.min(2, root.contentWidth / (Style.space.cardWidth - root.pad * 2)))

    Binding {
        target: Weather
        property: "city"
        value: Config.weatherCity
    }

    Binding {
        target: Weather
        property: "intervalMin"
        value: Config.weatherInterval
    }

    // ── 没配城市 / 出错 ────────────────────────────────────
    StyledText {
        Layout.fillWidth: true
        Layout.preferredWidth: root.contentWidth
        visible: !root.configured
        role: "label"
        tone: "dim"
        wrapMode: Text.WordWrap
        text: '在 config.json 里设 "weatherCity"，比如 "杭州"'
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.configured && Weather.error !== ""
        role: "label"
        tone: "warning"
        elide: Text.ElideRight
        text: Weather.error
    }

    // ── 实况 ──────────────────────────────────────────────
    StyledText {
        Layout.fillWidth: true
        visible: root.configured
        role: "label"
        tone: "dim"
        font.pixelSize: Math.round(Style.font.sizeS * root.heroScale)
        text: Weather.place !== "" ? Weather.place : Config.weatherCity
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.configured && Weather.ready
        spacing: Style.space.m

        StyledText {
            text: `${Math.round(Weather.temp)}°`
            font.pixelSize: Math.round(Style.font.sizeL * 2 * root.heroScale)
            font.weight: Font.DemiBold
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                font.pixelSize: Math.round(Style.font.sizeM * root.heroScale)
                text: Weather.summary
            }

            StyledText {
                role: "label"
                tone: "dim"
                font.pixelSize: Math.round(Style.font.sizeS * root.heroScale)
                text: `最高 ${Weather.high}°  最低 ${Weather.low}°`
            }
        }

        StyledIcon {
            glyph: Weather.glyph
            tone: "accent"
            size: Math.round(Style.font.sizeL * 2 * root.heroScale)
        }
    }

    // ── 逐小时 ────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: root.configured && Weather.hours.length > 0
        spacing: Style.space.s

        Repeater {
            model: Weather.hours.slice(0, root.hourCols)

            // 每一列要能被拉宽，整行才填得满。
            //
            // 坑在这儿：带 Layout.alignment 的子项不会被拉伸，于是这个 ColumnLayout
            // 算出来的 maximumWidth 被封死在最宽子项（约 29），外层 RowLayout 的
            // 最大宽度跟着被封死 —— Layout.fillWidth 设了也白设，整行只有内容那么宽，
            // 卡片拖宽之后右边空一大块。
            // 所以两行文字改成「自己撑满 + 文字内部居中」，图标那行保留 alignment
            // 就够了（只要有一个子项能撑开，父层的最大宽度就不再有上限）。
            ColumnLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: Style.space.xs

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    role: "label"
                    tone: "dim"
                    text: modelData.label
                }

                StyledIcon {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: Weather.glyphFor(modelData.code)
                    tone: "normal"
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    role: "label"
                    text: `${modelData.temp}°`
                }
            }
        }
    }
}
