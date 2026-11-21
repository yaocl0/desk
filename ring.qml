//@ pragma UseQApplication

import QtQml
import Quickshell
import "root:/core"
import "root:/overlays"

// 环形启动器的独立预览入口 —— 不动 shell.qml，也不和正在跑的 desk 抢什么：
// quickshell 按配置路径分实例，两边各有各的 IPC socket 和各自的层。
//
//   qs -p ~/workspace/desk/ring.qml          起来就是开着的
//   qs -p ~/workspace/desk/ring.qml ipc call launcher toggle   关了再开
//
// 环形启动器已经进了主 shell（设置面板 → 启动器 → 环形），这个入口只剩一个用处：
// 单独调环本身的时候不用把整个 shell 翻来覆去重载，也不会动你正在用的桌面。
// 不需要就可以删掉，删了不影响任何东西。
Scope {
    // 存盘即热重载。理由同 shell.qml：根对象是 Quickshell 特殊构造的，
    // 挂不上 Component.onCompleted，借一个子对象来设。
    QtObject {
        Component.onCompleted: {
            Quickshell.watchFiles = true;
            LauncherState.show();
        }
    }

    // IpcHandler 在惰性单例里注册不上，和 shell.qml 一样显式建一个
    Ipc {}

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property var modelData

            // 预览里也铺一张壁纸：花瓣是半透明的，底下没东西就看不出玻璃感，
            // 只剩一块灰片。正式用的时候这层由 shell.qml 管，这里不重复。
            WallpaperLayer {
                screen: perScreen.modelData
            }

            RingLauncherLayer {
                screen: perScreen.modelData
            }
        }
    }
}
