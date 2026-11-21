import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/core"
import "root:/ui"

// 桌面日历卡 —— 桌面组件层的示例组件。
//
// 这里只描述「结构和语义」：标题、星期行、6×7 的格子、哪一天是今天。
// 颜色 / 字号 / 圆角 / 间距一个字面值都没有，全部走 Style token，
// 所以四套主题下自动变样：gruvbox 是直角不透明、今天只变文字颜色；
// glass 是圆角玻璃、今天是一颗实心药丸。同一棵组件树。
Card {
    id: root

    // 翻月只动这个偏移量，不直接存「当前显示的月份」。
    // 否则 SystemClock 跨月推进时会把用户翻到的那一页重置掉。
    property int monthOffset: 0

    readonly property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth() + root.monthOffset, 1)

    // 一周从周几开始跟系统 locale 走（中文/法文环境自动是周一）
    readonly property int firstDow: Qt.locale().firstDayOfWeek

    // 网格从「1 号所在那一周的第一天」起算
    readonly property date gridStart: {
        const d = new Date(root.shown);
        d.setDate(1 - ((d.getDay() - root.firstDow + 7) % 7));
        return d;
    }

    // 格子边长由内容区宽度七等分反推 —— 卡片被拖宽，整张日历跟着铺开
    readonly property int cell: Math.floor(root.contentWidth / 7)

    SystemClock {
        id: clock

        // 只用来判定「今天」，跨零点自己推进，不需要更细的精度
        precision: SystemClock.Hours
    }

    function dayAt(i: int): date {
        const d = new Date(root.gridStart);
        d.setDate(d.getDate() + i);
        return d;
    }

    function isToday(d: date): bool {
        return d.toDateString() === clock.date.toDateString();
    }

    // ── 标题行：‹ 月份 › ────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space.xs

        IconButton {
            glyph: "󰅁"
            onClicked: root.monthOffset--
        }

        // 点月份名回到本月
        Surface {
            id: monthBar

            Layout.fillWidth: true
            implicitHeight: title.implicitHeight
            level: 1
            tint: monthBar.hovered ? Style.color.hover : Style.color.surfaceAlt
            radius: Style.shape.radiusS
            clickable: true
            onClicked: root.monthOffset = 0

            StyledText {
                id: title

                anchors.centerIn: parent
                role: "title"
                tone: monthBar.hovered ? "onHover" : root.monthOffset === 0 ? "normal" : "accent"
                text: Qt.formatDate(root.shown, "MMMM yyyy")
            }
        }

        IconButton {
            glyph: "󰅂"
            onClicked: root.monthOffset++
        }
    }

    // ── 星期行 + 日期格 ────────────────────────────────────
    // 固定 6 行 42 格：月份之间行数不一样的话，翻月时卡片高度会跳。
    GridLayout {
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
            model: 7

            StyledText {
                required property int index

                Layout.preferredWidth: root.cell
                role: "label"
                tone: "dim"
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDow + index) % 7, Locale.NarrowFormat)
            }
        }

        Repeater {
            model: 42

            Item {
                id: slot

                required property int index

                readonly property date day: root.dayAt(slot.index)
                readonly property bool inMonth: slot.day.getMonth() === root.shown.getMonth()
                readonly property bool today: root.isToday(slot.day)

                implicitWidth: root.cell
                implicitHeight: root.cell

                // 今天的底色。gruvbox 把 color.selected 设成 transparent，
                // 于是这块自动隐形，今天就只剩文字变色 —— 不用在这写 if。
                Surface {
                    anchors.centerIn: parent
                    width: root.cell - Style.space.xs
                    height: parent.height - Style.space.xs
                    visible: slot.today
                    level: 1
                    tint: Style.color.selected
                    radius: Style.shape.radiusFull > 0 ? Math.min(Style.shape.radiusFull, height / 2) : Style.shape.radiusS
                }

                StyledText {
                    anchors.centerIn: parent
                    text: slot.day.getDate()
                    tone: slot.today ? "onSelected" : slot.inMonth ? "normal" : "dim"
                    opacity: slot.inMonth || slot.today ? 1.0 : 0.45
                }
            }
        }
    }
}
