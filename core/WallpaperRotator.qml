import QtQml
import Quickshell

// 定时自动换壁纸：config.json 的 wallpaperInterval 是分钟数，0 = 不轮换。
//
// 不是 Singleton：同 Ipc / Matugen，QML 单例惰性创建，没人引用就不实例化，
// 里面的 Timer 也就不会跑。由 shell.qml 显式实例化一次。
Scope {
    id: root

    // 总开关关掉就直接给 0，下面 running 的条件自然不成立。
    // Timer.interval 是 int 毫秒，夹到一天以内，免得配了个大数直接溢出成负值
    readonly property int intervalMs: Config.wallpaperAuto ? Math.min(Math.max(0, Config.wallpaperInterval), 1440) * 60000 : 0

    Timer {
        id: timer

        // 只有一张图没什么可轮的。count 是异步填的，目录扫完这个绑定会自己转真。
        running: root.intervalMs > 0 && Wallpaper.count > 1
        interval: root.intervalMs
        repeat: true
        onTriggered: Wallpaper.next()
    }

    // 刚用选择器挑完一张，不该过几秒就被定时器顶掉 —— 手动换了就重新计时。
    // restart() 走的是 C++ setter，不会打断上面 running 的绑定，
    // 依赖再变时（比如改了 interval）那个绑定照样重新求值。
    Connections {
        target: Config

        function onWallpaperChanged() {
            if (timer.running)
                timer.restart();
        }
    }
}
