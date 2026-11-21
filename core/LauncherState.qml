pragma Singleton

import Quickshell
import Quickshell.Hyprland

// 启动器的开关。放在 core/ 是因为 core/Ipc.qml 要能开关它，
// 而 core/ 不许反向依赖 overlays/ —— 两边都认这个单例就接上了。
//
// 这里只有「开没开、开在哪块屏」，没有查询串：查询串属于面板自己的瞬态，
// 面板关掉就该忘掉，不必让别人看见。
Singleton {
    id: root

    property bool open: false

    // 打开那一瞬间锁定一次当前屏，而不是一直绑 Hyprland.focusedMonitor。
    // 绑着的话：鼠标跟随焦点的配置下，光标划到另一块屏，启动器会连人带输入
    // 一起跳过去 —— 正在打的字还在，窗口却换了一块屏，手感很怪。
    property string screenName: ""

    function show() {
        root.screenName = Hyprland.focusedMonitor?.name ?? "";
        root.open = true;
    }

    function hide() {
        root.open = false;
    }

    function toggle() {
        if (root.open)
            root.hide();
        else
            root.show();
    }
}
