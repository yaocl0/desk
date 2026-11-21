import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "root:/core"
import "root:/ui"

// 动态工作区：有窗口的才显示。
//
// 另外两种也必须显示，否则要么"看不见自己在哪"，要么漏掉提示：
//   · active —— 某块屏幕正显示着它（多屏时不止一个），哪怕是空的
//   · urgent —— 里面有窗口在求关注
RowLayout {
    id: root

    readonly property var shown: {
        const out = [];
        for (const w of Hyprland.workspaces.values) {
            if (!w || w.id < 0)      // 负数 id 是 special workspace（便签页），不进栏
                continue;
            const windows = w.toplevels?.values?.length ?? 0;
            if (windows > 0 || w.active || w.urgent)
                out.push(w);
        }
        // values 的顺序不保证，自己按 id 排
        return out.sort((a, b) => a.id - b.id);
    }

    spacing: Style.space.xs

    Repeater {
        model: root.shown

        Pill {
            id: ws

            required property var modelData

            tint: ws.modelData.focused ? Style.color.selected : Style.color.surfaceAlt
            clickable: true
            // Hyprland 0.5x 起 dispatch 换成了 Lua API，旧写法 `workspace N`
            // 会被拒绝（')' expected near 'N'）。切换工作区在 focus 下，
            // 不在 workspace 下 —— hl.dsp.workspace.* 是改编号/重命名那组。
            onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace=${ws.modelData.id}})`)

            StyledText {
                // 命名工作区显示名字，数字工作区 name 就是 "1" 这种
                text: ws.modelData.name || ws.modelData.id
                tone: ws.modelData.focused ? "onSelected" : ws.modelData.urgent ? "error" : "normal"
            }
        }
    }
}
