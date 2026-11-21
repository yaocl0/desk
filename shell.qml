//@ pragma UseQApplication

import QtQml
import Quickshell
import "root:/core"
import "root:/layouts"
import "root:/overlays"

Scope {
    // 存盘即热重载。shell.qml 的根对象是 Quickshell 特殊构造的，
    // 挂不上 Component.onCompleted，所以借一个子对象来设。
    QtObject {
        Component.onCompleted: Quickshell.watchFiles = true
    }

    // 这几个都不是 Singleton：QML 单例惰性创建，没人引用就不实例化，
    // 里面的 IpcHandler / Timer / Connections 也就不生效。显式各建一个。
    Ipc {}

    // 换壁纸 → 自动重算 material 配色
    Matugen {}

    // 每 config.json 的 wallpaperInterval 分钟自动换下一张（0 = 关）
    WallpaperRotator {}

    // 锁屏。不进下面的 Variants —— WlSessionLock 自己管所有屏幕，
    // 按屏实例化会得到 N 个互相抢锁的 WlSessionLock。
    // 平时不占任何资源：locked 为 false 时合成器侧什么都没有。
    LockWindow {}

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property var modelData

            // ── 布局注册表：加一个布局 = 加一个 LazyLoader ──────────
            LazyLoader {
                active: Config.layout === "topbar"

                component: TopBarLayout {
                    screen: perScreen.modelData
                }
            }

            LazyLoader {
                active: Config.layout === "island"

                component: IslandLayout {
                    screen: perScreen.modelData
                }
            }

            LazyLoader {
                active: Config.layout === "dock"

                component: DockLayout {
                    screen: perScreen.modelData
                }
            }

            // ── 全屏层：不随布局切换 ──────────────────────────────
            WallpaperLayer {
                screen: perScreen.modelData
            }

            DesktopLayer {
                screen: perScreen.modelData
            }

            NotificationLayer {
                screen: perScreen.modelData
            }

            // ── 启动器：两套平行实现，按 config.launcher 二选一 ──
            // 和上面的布局注册表同一个写法。用 LazyLoader 而不是 visible：
            // 没选中的那套一个对象都不创建，两个 PanelWindow 不会同时挂在
            // 合成器上抢 Overlay 层和键盘独占。
            //
            // list 这一路写成「不等于 ring」而不是「等于 list」：
            // config.json 被手改成一个不认识的值时，退回列表式总比
            // 一个启动器都没有强 —— 快捷键按下去毫无反应最难查。
            LazyLoader {
                active: Config.launcher !== "ring"

                component: LauncherLayer {
                    screen: perScreen.modelData
                }
            }

            LazyLoader {
                active: Config.launcher === "ring"

                component: RingLauncherLayer {
                    screen: perScreen.modelData
                }
            }
        }
    }
}
