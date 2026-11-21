import "root:/core"
import "root:/services"
import "root:/ui"

Pill {
    id: root

    property real warnAt: 0.8

    // 超阈值换色位，而不是把文字染色
    moduleKey: Sys.cpu >= root.warnAt ? "alert" : "cpu"

    StyledIcon {
        glyph: "󰻠"
        tone: "onModule"
        size: Style.font.sizeM
    }

    StyledText {
        text: `${Math.round(Sys.cpu * 100)}%`
        tone: "onModule"
    }
}
