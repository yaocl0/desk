import "root:/core"
import "root:/services"
import "root:/ui"

Pill {
    id: root

    readonly property int percent: Math.round(Audio.volume * 100)

    moduleKey: "volume"
    visible: Audio.ready
    clickable: true
    onClicked: Audio.toggleMute()
    onWheeled: event => Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))

    StyledIcon {
        glyph: Audio.muted ? "󰝟" : root.percent >= 50 ? "󰕾" : root.percent > 0 ? "󰖀" : "󰕿"
        tone: "onModule"
        size: Style.font.sizeM
    }

    StyledText {
        text: `${root.percent}%`
        tone: "onModule"
    }
}
