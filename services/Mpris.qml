pragma Singleton

import QtQml
import Quickshell
import Quickshell.Services.Mpris

// 正在播放。MPRIS 上常常同时挂着好几个播放器（浏览器标签页、音乐客户端），
// 所以要挑一个「此刻该显示的」：优先正在放的，否则取第一个能控制的。
Singleton {
    id: root

    readonly property var players: Mpris.players.values

    readonly property var player: {
        const ps = root.players.filter(p => p.canControl);
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }

    readonly property bool active: root.player !== null
    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property string album: root.player?.trackAlbum ?? ""
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property string app: root.player?.identity ?? ""
    readonly property bool playing: root.player?.isPlaying ?? false

    readonly property bool canNext: root.player?.canGoNext ?? false
    readonly property bool canPrev: root.player?.canGoPrevious ?? false

    // 进度。length / position 单位是秒，播放器不支持时统一给 0，
    // 让调用方用 length > 0 一个条件就能决定要不要画进度条。
    readonly property real length: (root.player?.lengthSupported ?? false) ? root.player.length : 0
    property real position: 0

    readonly property real progress: root.length > 0 ? Math.min(1, root.position / root.length) : 0

    function toggle() {
        root.player?.togglePlaying();
    }

    function next() {
        root.player?.next();
    }

    function previous() {
        root.player?.previous();
    }

    // position 不会自己推送过来 —— D-Bus 上它是个「查询时才有意义」的值。
    // 播放中每秒主动取一次；暂停时停掉，不白白唤醒。
    Timer {
        running: root.playing && (root.player?.positionSupported ?? false)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.position = root.player?.position ?? 0
    }
}
