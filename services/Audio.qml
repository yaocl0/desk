pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

// 默认输出设备的音量状态。之后做音量 OSD / 控制中心时复用同一个单例。
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: root.sink?.ready ?? false
    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false

    function setVolume(v: real) {
        if (root.sink?.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (root.sink?.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    // 不 track 的话 Pipewire 节点属性不会同步过来
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
