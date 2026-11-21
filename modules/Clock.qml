import Quickshell
import "root:/core"
import "root:/ui"

Pill {
    moduleKey: "clock"

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    StyledIcon {
        glyph: "󰥔"
        tone: "onModule"
        size: Style.font.sizeM
    }

    StyledText {
        text: Qt.formatDateTime(clock.date, "MM-dd ddd  HH:mm")
        tone: "onModule"
    }
}
