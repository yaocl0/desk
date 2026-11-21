import "root:/core"
import "root:/services"
import "root:/ui"

Pill {
    id: root

    readonly property string glyph: {
        if (Batt.charging)
            return "󰂄";
        const levels = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return levels[Math.max(0, Math.min(10, Math.floor(Batt.percent / 10)))];
    }

    // 低电量换成告警色位，而不是把文字染红 —— 彩色药胶条上文字一律是 module.on
    moduleKey: Batt.low ? "alert" : "battery"
    visible: Batt.available

    StyledIcon {
        glyph: root.glyph
        tone: "onModule"
        size: Style.font.sizeM
    }

    StyledText {
        text: `${Batt.percent}%`
        tone: "onModule"
    }
}
