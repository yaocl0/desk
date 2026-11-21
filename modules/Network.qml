import "root:/core"
import "root:/services"
import "root:/ui"

Pill {
    id: root

    // 窄处（灵动岛）只留图标
    property bool showLabel: true

    readonly property bool wired: Net.kind === "wired"

    readonly property string glyph: {
        if (root.wired)
            return "󰈀";
        if (!Net.wifiEnabled)
            return "󰤮";
        if (!Net.wifiUp)
            return "󰤯";
        return ["󰤟", "󰤟", "󰤢", "󰤥", "󰤨"][Net.signalLevel];
    }

    readonly property string label: {
        if (root.wired)
            return "有线";
        if (Net.wifiUp)
            return `${Net.ssid} (${Math.round(Net.signal * 100)}%)`;
        if (!Net.wifiEnabled)
            return "已关闭";
        return "未连接";
    }

    moduleKey: "network"

    StyledIcon {
        glyph: root.glyph
        tone: "onModule"
        size: Style.font.sizeM
    }

    StyledText {
        visible: root.showLabel
        text: root.label
        tone: "onModule"
    }
}
