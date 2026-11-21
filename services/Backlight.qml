pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// 屏幕亮度。
//
// /sys/class/backlight/*/brightness 是 root 独占的（这台机器上 644 root:root，
// 用户也不在 video 组），所以写走 logind 的 SetBrightness —— 不要 root，
// 也不用往系统里塞 udev 规则。装 brightnessctl 也行，但那是多一个外部依赖，
// logind 本来就在跑。读还是直接读 sysfs。
//
// 只管内置屏（eDP）。外接显示器要走 DDC/CI，是另一套东西，不在这层。
Singleton {
    id: root

    readonly property bool available: root.max > 0 && root.device !== ""
    readonly property real level: root.available ? root.value / root.max : 0

    property string device: ""
    property int max: 0
    // 不是 readonly：拖动时先乐观更新，不等 sysfs 回读，否则滑块跟不上手
    property int value: 0

    property real _want: 0
    property int _wrote: -1

    function set(frac: real) {
        if (!root.available)
            return;
        // 不许拖到全黑 —— 屏幕黑了就没法再拖回来了
        root._want = Math.max(0.02, Math.min(1, frac));
        root.value = Math.round(root._want * root.max);
        root._flush();
    }

    function nudge(delta: real) {
        root.set(root.level + delta);
    }

    // busctl 一次只留一个在途。拖动期间攒下的最新值在 onExited 里补发，
    // 否则一路拖过去会 spawn 出几十个进程。
    function _flush() {
        if (writer.running || !root.available)
            return;
        const v = Math.round(root._want * root.max);
        if (v === root._wrote)
            return;
        root._wrote = v;
        writer.command = ["busctl", "--system", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/self", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", root.device, String(v)];
        writer.running = true;
    }

    // 设备名只探一次
    Process {
        running: true
        command: ["sh", "-c", "ls -1 /sys/class/backlight 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: root.device = this.text.trim()
        }
    }

    // 同 Sys.qml：FileView.text() 是函数，但内部读的是会发通知的 __text，
    // 放在绑定里能跟着文件内容重新求值。用 var 接住，构造完成前取值会抛。
    readonly property var _maxText: maxFile.text()
    readonly property var _curText: curFile.text()

    on_MaxTextChanged: {
        const n = parseInt(root._maxText);
        if (n > 0)
            root.max = n;
    }

    on_CurTextChanged: {
        // 自己正在写的时候别回读，否则乐观更新会被旧值顶回去
        if (writer.running)
            return;
        const n = parseInt(root._curText);
        if (n >= 0)
            root.value = n;
    }

    FileView {
        id: maxFile

        // device 探到之前 path 是空的，别让它往日志里刷错误
        printErrors: false
        path: root.device === "" ? "" : `/sys/class/backlight/${root.device}/max_brightness`
    }

    FileView {
        id: curFile

        printErrors: false
        path: root.device === "" ? "" : `/sys/class/backlight/${root.device}/brightness`
    }

    // sysfs 不发 inotify：外部改了亮度（Fn 键）只能靠轮询发现
    Timer {
        running: root.available
        interval: 3000
        repeat: true
        onTriggered: curFile.reload()
    }

    Process {
        id: writer

        onExited: code => {
            if (code !== 0)
                console.warn(`[Backlight] 设置失败（busctl ${code}）`);
            root._flush();
        }
    }
}
