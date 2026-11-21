import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/modules"

// 真·锁屏。和 overlays/LockLayer.qml 是两套：那个是预览（普通 Overlay 窗口、
// Esc 能退），这个是 ext-session-lock —— 合成器把所有窗口挡在后面，
// 除了认证通过没有别的出路。
//
// ⚠️ 这里**刻意没有**任何逃生口：没有 Esc、没有 abort、没有「预览模式」提示。
// 锁屏上留一个不用密码就能退的入口，它就不是锁屏。
//
// 这也意味着：这个进程在锁着的时候崩了 / 被 kill，屏幕会保持锁定。
// 救援路径只有一条：Ctrl+Alt+F2 切 TTY → loginctl unlock-session。
//
// 不放进 Variants：WlSessionLock 自己管所有屏幕，每块屏生成一个
// WlSessionLockSurface。按屏实例化会得到 N 个互相抢锁的 WlSessionLock。
Scope {
    WlSessionLock {
        locked: LockState.wanted

        WlSessionLockSurface {
            id: surface

            color: Style.color.background

            // surface 是开始锁的时候才构造的，所以这里就是「锁屏出现」那一刻：
            // 清掉上次的输入、起出场动画、把焦点放进输入框。
            // 最后一项不能省 —— session lock 的 surface 天然独占键盘，
            // 但焦点不在输入框上的话打的字照样全丢。
            Component.onCompleted: {
                scene.reset();
                scene.play();
                scene.focusInput();
            }

            LockScene {
                id: scene

                anchors.fill: parent
                screenName: surface.screen?.name ?? ""

                // 认证通过 → 放完淡出 → 才真正解锁。
                // 直接在 PAM 回调里 finish() 的话画面是硬切的。
                Connections {
                    target: LockState

                    function onUnlockingChanged() {
                        if (LockState.unlocking)
                            exit.restart();
                    }
                }

                Timer {
                    id: exit

                    interval: Style.motion.enabled ? Style.durNormal * 2 + 60 : 0
                    onTriggered: LockState.finish()
                }
            }
        }
    }
}
