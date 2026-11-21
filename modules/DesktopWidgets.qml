pragma Singleton

import QtQuick
import Quickshell

// 桌面组件目录：有哪些卡可以往桌面上放。
//
// 加一张卡 = 在 catalog 里加一行 + 加一个 Component。设置面板照着 catalog 列选项，
// DesktopLayer 按 key 取 Component —— 两边读的是同一份，不会出现
// 「面板里能勾、桌面上不出现」这种对不上的情况。
//
// 为什么不放 core/：目录里装的是 Component，而 core/ 不许反向依赖视觉层
//（tools/check-style.sh 第 5 条）。所以目录待在 modules/，
// 「用户勾了哪几个」那份纯数据留在 core/Config —— 数据和实现分两边。
Singleton {
    id: root

    // 正在放置的组件 key，"" = 没有。面板点一下设上，桌面层接住并进入放置模式。
    // 不写进 config：这是个瞬时的交互状态，不该留到下次开机。
    //
    // 放在目录这儿，是因为面板和桌面层本来就都认识它 —— 不用再造一个单例。
    property string placing: ""

    readonly property var catalog: [
        {
            key: "calendar",
            label: "日历",
            glyph: "󰃭"
        },
        {
            key: "weather",
            label: "天气",
            glyph: "󰖐"
        },
        {
            key: "media",
            label: "正在播放",
            glyph: "󰝚"
        },
        {
            key: "album",
            label: "壁纸相册",
            glyph: "󰸉"
        }
    ]

    function componentFor(key: string): var {
        return ({
                calendar: calendarC,
                weather: weatherC,
                media: mediaC,
                album: albumC
            })[key] ?? null;
    }

    function labelFor(key: string): string {
        return root.catalog.find(w => w.key === key)?.label ?? key;
    }

    Component {
        id: calendarC

        CalendarCard {}
    }

    Component {
        id: weatherC

        WeatherCard {}
    }

    Component {
        id: mediaC

        MediaCard {}
    }

    Component {
        id: albumC

        AlbumCard {}
    }
}
