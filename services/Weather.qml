pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// 天气。数据源 Open-Meteo：免费、不要 API key。
//
// 两步：城市名 →（geocoding）经纬度 →（forecast）实况 + 逐小时 + 当日高低温。
// 经纬度只在城市名变了时解析一次，之后每个周期只打第二个请求。
//
// city / intervalMin 由使用方喂进来，不在这里读 Config ——
// services/ 是叶子，只读外部系统状态，连 core/ 都不依赖。
// 顺带的好处：没人喂城市名就一个请求都不发，桌面上没有天气卡时是真的不跑。
Singleton {
    id: root

    property string city: ""
    property int intervalMin: 15

    // ── 对外 ────────────────────────────────────────────────
    readonly property bool ready: root._cur !== null
    readonly property string place: root._place
    readonly property real temp: root._cur?.temperature_2m ?? 0
    readonly property int code: root._cur?.weather_code ?? -1
    readonly property real high: root._high
    readonly property real low: root._low
    // [{ label: "14时", temp: 27, code: 2 }, …]
    readonly property var hours: root._hours
    // 空串 = 没出错。出错时保留上一次的数据，不把卡片清空
    readonly property string error: root._error

    readonly property string glyph: root.glyphFor(root.code)
    readonly property string summary: root.describe(root.code)

    // WMO 天气码 → Nerd Font 字形 / 中文描述
    function _info(c: int): var {
        return ({
                0: ["󰖙", "晴"],
                1: ["󰖕", "晴间多云"],
                2: ["󰖕", "多云"],
                3: ["󰖐", "阴"],
                45: ["󰖑", "雾"],
                48: ["󰖑", "雾凇"],
                51: ["󰖗", "毛毛雨"],
                53: ["󰖗", "毛毛雨"],
                55: ["󰖗", "强毛毛雨"],
                56: ["󰖒", "冻毛毛雨"],
                57: ["󰖒", "冻毛毛雨"],
                61: ["󰖗", "小雨"],
                63: ["󰖖", "中雨"],
                65: ["󰖖", "大雨"],
                66: ["󰖒", "冻雨"],
                67: ["󰖒", "冻雨"],
                71: ["󰖘", "小雪"],
                73: ["󰖘", "中雪"],
                75: ["󰖘", "大雪"],
                77: ["󰖘", "米雪"],
                80: ["󰖗", "阵雨"],
                81: ["󰖖", "阵雨"],
                82: ["󰖖", "强阵雨"],
                85: ["󰖘", "阵雪"],
                86: ["󰖘", "强阵雪"],
                95: ["󰖓", "雷阵雨"],
                96: ["󰖒", "雷阵雨伴冰雹"],
                99: ["󰖒", "雷阵雨伴冰雹"]
            })[c] ?? ["󰖐", "—"];
    }

    function glyphFor(c: int): string {
        return root._info(c)[0];
    }

    function describe(c: int): string {
        return root._info(c)[1];
    }

    function refresh() {
        if (root.city === "")
            return;
        if (root._lat === "")
            root._geocode();
        else
            root._forecast();
    }

    // ── 内部状态 ────────────────────────────────────────────
    property string _place: ""
    property string _lat: ""
    property string _lon: ""
    property var _cur: null
    property var _hours: []
    property real _high: 0
    property real _low: 0
    property string _error: ""

    // 连续传输失败次数。开机时 Hyprland 的 exec-once 和 NetworkManager 几乎
    // 同时跑（实测两边都落在开机后第 9 秒），DNS 往往还没就绪 —— 第一发必然
    // 失败。原先失败后要等满一个周期（默认 15 分钟）才有第二次尝试，
    // 这就是「每次重启天气都挂、过一会儿又自己好了」。挂起唤醒掉线同理。
    property int _fails: 0

    // 正常走 intervalMin；失败后退避 5s → 10s → 20s → 40s → 60s 封顶
    readonly property int _delay: root._fails > 0 ? Math.min(60000, 5000 * Math.pow(2, root._fails - 1)) : Math.max(1, root.intervalMin) * 60000

    // 传输层失败（DNS / 连接 / 超时）：会好的，快重试
    function _netFail(msg: string) {
        root._fails = Math.min(root._fails + 1, 5);
        root._error = msg;
        console.warn(`[Weather] ${msg}，${Math.round(root._delay / 1000)}s 后重试（连续第 ${root._fails} 次）`);
    }

    // 数据本身的问题（城市拼错、返回体不对）：重试多少次都一样，
    // 所以只报错，不进退避，免得每分钟空打一发
    function _dataFail(msg: string) {
        root._fails = 0;
        root._error = msg;
        console.warn(`[Weather] ${msg}`);
    }

    function _ok() {
        root._fails = 0;
        root._error = "";
    }

    onCityChanged: {
        // 换城市 → 旧的经纬度作废，重新解析
        root._lat = "";
        root._lon = "";
        root._error = "";
        root._fails = 0;
        if (root.city === "") {
            root._cur = null;
            root._hours = [];
            root._place = "";
        } else {
            root._geocode();
        }
    }

    function _get(p: var, url: string) {
        // 上一发还在路上就不重复打 —— 覆盖 running 进程的 command 是未定义行为
        if (p.running)
            return;
        p.command = ["curl", "-sS", "-f", "--max-time", "10", url];
        p.running = true;
    }

    function _geocode() {
        root._get(geo, `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(root.city)}&count=1&language=zh&format=json`);
    }

    function _forecast() {
        root._get(fc, `https://api.open-meteo.com/v1/forecast?latitude=${root._lat}&longitude=${root._lon}` + "&current=temperature_2m,weather_code&hourly=temperature_2m,weather_code" + "&daily=temperature_2m_max,temperature_2m_min&forecast_days=2&timezone=auto");
    }

    // 从逐小时数组里挑「当前时刻之后的 12 个小时」。给够，具体显示几列
    // 由卡片按自己的宽度决定 —— 卡被拖宽就多铺几列。
    // Open-Meteo 的 time 是 "2026-11-19T14:00" 这种本地时间字符串，
    // 直接按字符串比大小就是按时间比大小，不用解析成 Date。
    function _pickHours(h: var, now: string): var {
        if (!h?.time)
            return [];
        let i = h.time.findIndex(t => t > now);
        if (i < 0)
            return [];
        return h.time.slice(i, i + 12).map((t, k) => ({
                    label: `${t.slice(11, 13)}时`,
                    temp: Math.round(h.temperature_2m[i + k]),
                    code: h.weather_code[i + k]
                }));
    }

    // _fails 一变就得重新计时，否则退避后的新间隔要等当前这一轮走完才生效
    on_FailsChanged: {
        if (poll.running)
            poll.restart();
    }

    Timer {
        id: poll

        // 没城市名就不跑
        running: root.city !== ""
        interval: root._delay
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: geo

        stdout: StdioCollector {
            onStreamFinished: {
                // 请求本身失败时 stdout 是空的 —— 别在这儿报个误导的「解析失败」，
                // 交给下面的 onExited 说清楚是传输问题
                if (this.text.trim() === "")
                    return;
                try {
                    const r = JSON.parse(this.text)?.results?.[0];
                    if (!r) {
                        root._dataFail(`找不到城市「${root.city}」`);
                        return;
                    }
                    root._lat = String(r.latitude);
                    root._lon = String(r.longitude);
                    root._place = r.name ?? root.city;
                    // 还没拿到天气，先不算成功，继续往下打
                    root._forecast();
                } catch (e) {
                    root._dataFail(`地名解析失败: ${e}`);
                }
            }
        }

        onExited: code => {
            if (code !== 0)
                root._netFail(`地名解析请求失败（curl ${code}）`);
        }
    }

    Process {
        id: fc

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "")
                    return;
                try {
                    const d = JSON.parse(this.text);
                    if (!d?.current) {
                        root._dataFail("天气返回体里没有 current");
                        return;
                    }
                    root._cur = d.current;
                    root._high = Math.round(d.daily?.temperature_2m_max?.[0] ?? 0);
                    root._low = Math.round(d.daily?.temperature_2m_min?.[0] ?? 0);
                    root._hours = root._pickHours(d.hourly, d.current.time);
                    root._ok();
                } catch (e) {
                    root._dataFail(`天气数据解析失败: ${e}`);
                }
            }
        }

        onExited: code => {
            if (code !== 0)
                root._netFail(`天气请求失败（curl ${code}）`);
        }
    }
}
