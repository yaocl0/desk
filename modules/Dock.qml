import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/ui"

// 当前打开的窗口，按 appId 去重。点击唤起，当前窗口下方有指示点。
RowLayout {
    id: root

    property int iconSize: Style.space.l * 2

    spacing: Style.space.s

    // appId 相同的只留一个
    readonly property var apps: {
        const seen = {};
        const out = [];
        for (const t of ToplevelManager.toplevels.values) {
            const key = t.appId || t.title;
            if (!key || seen[key])
                continue;
            seen[key] = true;
            out.push(t);
        }
        return out;
    }

    Repeater {
        model: root.apps

        Surface {
            id: slot

            required property var modelData
            readonly property var entry: DesktopEntries.heuristicLookup(slot.modelData.appId) ?? null
            readonly property bool current: ToplevelManager.activeToplevel?.appId === slot.modelData.appId

            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            radius: Style.shape.radiusM
            tint: slot.current ? Style.color.selected : slot.hovered ? Style.color.hover : Style.color.surfaceAlt
            clickable: true
            onClicked: slot.modelData.activate()

            // 图标名/路径的归一化在 StyledIcon 里统一做
            StyledIcon {
                id: ico

                anchors.centerIn: parent
                source: slot.entry?.icon ?? ""
                size: Math.round(root.iconSize * 0.62)
            }

            // 查不到 .desktop 图标时退回首字母
            StyledText {
                anchors.centerIn: parent
                visible: ico.resolved == ""
                text: (slot.modelData.appId || "?").charAt(0).toUpperCase()
                role: "title"
                tone: slot.current ? "onSelected" : slot.hovered ? "onHover" : "normal"
            }

            // 运行指示点
            Dot {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space.xs / 2
                width: Style.space.xs
                height: width
                opacity: slot.current ? 1 : 0.35
            }
        }
    }
}
