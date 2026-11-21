pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU / 内存占用。/proc 不触发 inotify，所以靠 Timer 主动 reload。
Singleton {
    id: root

    property int interval: 3000

    readonly property real cpu: root._cpu          // 0..1
    readonly property real mem: root._mem          // 0..1
    readonly property real memUsedGb: root._memUsedKb / 1048576.0
    readonly property real memTotalGb: root._memTotalKb / 1048576.0

    property real _cpu: 0
    property real _mem: 0
    property real _memUsedKb: 0
    property real _memTotalKb: 0
    property var _prev: null

    // FileView.text() 是函数而非属性，但内部读的是会发通知的 __text，
    // 所以放在绑定里能跟着文件内容重新求值。
    //
    // 必须声明成 var 而不是 string：绑定首次求值时 FileView 还没构造完，
    // 取值会抛异常让整个绑定变成 undefined，赋给 string 属性就会报
    // "Unable to assign [undefined] to QString"。用 var 接住，在函数里防御。
    readonly property var _statText: stat.text()
    readonly property var _memText: meminfo.text()

    on_StatTextChanged: root._updateCpu(root._statText)
    on_MemTextChanged: root._updateMem(root._memText)

    function _updateCpu(t) {
        if (!t)
            return;
        const line = t.split("\n")[0];
        if (!line.startsWith("cpu"))
            return;
        const f = line.trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 5)
            return;

        const idle = f[3] + f[4];                      // idle + iowait
        const total = f.reduce((a, b) => a + b, 0);

        if (root._prev) {
            const dTotal = total - root._prev.total;
            const dIdle = idle - root._prev.idle;
            if (dTotal > 0)
                root._cpu = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
        }
        root._prev = {
            total: total,
            idle: idle
        };
    }

    function _updateMem(t) {
        if (!t)
            return;
        const field = k => {
            const m = t.match(new RegExp(`^${k}:\\s+(\\d+)`, "m"));
            return m ? Number(m[1]) : 0;
        };
        const total = field("MemTotal");
        const avail = field("MemAvailable");
        if (total > 0) {
            root._mem = Math.max(0, Math.min(1, (total - avail) / total));
            root._memTotalKb = total;
            root._memUsedKb = total - avail;
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
    }
}
