import QtQuick
import Quickshell
import "root:/core"
import "root:/ui"

// 锁屏上的时间。精度只到分钟 —— 锁屏可能挂一整夜，
// 没必要为了一个看不见的秒位每秒触发一次重排。
Column {
    id: root

    property int timeSize: Math.round(Style.font.sizeL * 5)

    spacing: Style.space.xs

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.pixelSize: root.timeSize
        // 大字号下字距收一点，否则 HH:mm 会散开
        font.letterSpacing: -root.timeSize * 0.03
        font.weight: Font.Light
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        // 显式给 locale：不给的话 dddd 跟系统默认走，这台机器上出来是 Friday。
        // 和栏上的时钟不同，那边只有 "MM-dd ddd HH:mm"，没有星期全称，撞不上这个问题。
        text: clock.date.toLocaleDateString(Qt.locale("zh_CN"), "M 月 d 日 dddd")
        tone: "dim"
        font.pixelSize: Style.font.sizeM
    }
}
