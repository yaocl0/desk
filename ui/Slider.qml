import QtQuick
import QtQuick.Layouts
import "root:/core"

// 横向滑条，表示一个 0..1 的量（亮度 / 音量这类）。
// 和 MenuRow / Tile 一样只发信号，不认识任何 service。
//
// 图标和数值在轨道外面：轨道本身只剩一条细线 + 一颗圆钮，
// 满值时不会变成一整块 accent 色压住整个面板。
Item {
    id: root

    property real value: 0
    property string glyph: ""
    property bool showPercent: true

    signal moved(real v)

    readonly property real clamped: Math.max(0, Math.min(1, root.value))

    implicitHeight: Math.round(Style.font.sizeL * 1.6)

    RowLayout {
        anchors.fill: parent
        spacing: Style.space.s

        StyledIcon {
            visible: root.glyph !== ""
            glyph: root.glyph
            // 不用 dim：高透明主题下低对比度的图标会被背后的窗口内容吃掉。
            // accent 留给「值」本身（填充 + 圆钮），图标只是个标签。
            tone: "normal"
            size: Style.font.sizeM
        }

        Item {
            id: bar

            // 圆钮在两端要留得下，所以可走行程是 width - knob
            readonly property int knob: Style.font.sizeM
            readonly property int trackH: Math.max(2, Math.round(Style.space.xs * 0.75))
            readonly property real span: Math.max(1, bar.width - bar.knob)

            Layout.fillWidth: true
            Layout.fillHeight: true

            // 指针位置 → 值。按圆钮中心算，这样钮始终跟在指针底下，
            // 而不是在两端差半个钮的距离。
            function at(x: real): real {
                return Math.max(0, Math.min(1, (x - bar.knob / 2) / bar.span));
            }

            Surface {
                id: track

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: bar.trackH
                level: 1
                bordered: false
                tint: Style.color.outline
                radius: Style.shape.radiusFull > 0 ? height / 2 : 0
            }

            Surface {
                anchors.verticalCenter: parent.verticalCenter
                // 填到圆钮中心，不是填到钮的左边
                width: bar.knob / 2 + bar.span * root.clamped
                height: bar.trackH
                level: 1
                bordered: false
                tint: Style.color.accent
                radius: track.radius
            }

            Surface {
                id: knob

                x: bar.span * root.clamped
                anchors.verticalCenter: parent.verticalCenter
                width: bar.knob
                height: bar.knob
                level: 1
                bordered: false
                tint: Style.color.accent
                // 极简主题 radiusFull 是 0，这里就老实是个方块
                radius: Style.shape.radiusFull > 0 ? width / 2 : Style.shape.radiusS

                Behavior on x {
                    enabled: Style.motion.enabled && !ma.pressed
                    NumberAnimation {
                        duration: Style.durFast
                        easing.type: Style.easing
                    }
                }
            }

            MouseArea {
                id: ma

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: e => root.moved(bar.at(e.x))
                onPositionChanged: e => {
                    if (ma.pressed)
                        root.moved(bar.at(e.x));
                }
                onWheel: e => root.moved(root.clamped + (e.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        StyledText {
            id: pct

            // 定宽：否则 9% → 100% 的时候整条会左右抖
            Layout.preferredWidth: metrics.width
            visible: root.showPercent
            role: "label"
            tone: "dim"
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(root.clamped * 100)}%`

            TextMetrics {
                id: metrics

                font: pct.font
                text: "100%"
            }
        }
    }
}
