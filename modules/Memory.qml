import "root:/core"
import "root:/services"
import "root:/ui"

Pill {
    id: root

    property real warnAt: 0.85
    // true 显示已用容量（8.41G），false 显示百分比
    property bool absolute: true

    moduleKey: Sys.mem >= root.warnAt ? "alert" : "memory"

    StyledIcon {
        glyph: "󰍛"
        tone: "onModule"
        size: Style.font.sizeM
    }

    StyledText {
        text: root.absolute ? `${Sys.memUsedGb.toFixed(2)}G` : `${Math.round(Sys.mem * 100)}%`
        tone: "onModule"
    }
}
