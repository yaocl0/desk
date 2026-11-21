import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/modules"
import "root:/ui"

// ⚠️ 这是**预览**用的锁屏层，它锁不住任何东西。
//
// 真锁屏要 WlSessionLock：它向合成器声明「这块屏归我了」，所有窗口被挡在
// 后面，合成器直到收到解锁才放行。代价是一旦装上，这个进程崩了或者被 kill，
// 屏幕会**保持锁定** —— 只能 Ctrl+Alt+F2 切 TTY 再 loginctl unlock-session。
//
// 所以先做成一张普通的 Overlay 窗口：长得一样、PAM 认证是真的，
// 但 Esc 随时退得出去。确认手感和认证都对了之后再换，换法见文件末尾。
Scope {
    id: root

    required property var screen

    PanelWindow {
        id: win

        screen: root.screen
        visible: LockState.wanted

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        // 不叫 desk：那个 namespace 上挂着 blur，而这是一张铺满全屏的不透明
        // 窗口，糊它没有意义，只是白烧一遍 GPU。
        WlrLayershell.namespace: "desk-lock"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // 连栏一起盖住 —— 锁屏露出一条状态栏就不像锁屏了
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // 出场动画既要在「关 → 开」时起跑，也要在**构造出来就是开着**时起跑：
        // QML 不会为属性的初始求值触发 onXChanged，所以热重载时锁屏正开着的话
        // onVisibleChanged 一次都不会来 —— intro 停在 0，整幅画面 opacity 全是 0，
        // 只剩星空和底部那行提示，看起来像渲染挂了。日志一个字都不报。
        function enter() {
            scene.reset();
            scene.play();
            scene.focusInput();
        }

        Component.onCompleted: {
            if (win.visible)
                win.enter();
        }

        onVisibleChanged: {
            if (win.visible)
                win.enter();
        }

        LockScene {
            id: scene

            anchors.fill: parent
            screenName: root.screen.name

            // 认证通过 → 淡出动画放完 → 真正退出。
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

        // ── 预览专用的逃生口 ────────────────────────────────
        // Esc 不认证直接退出。接了 WlSessionLock 之后这一整块必须删掉，
        // 连同 LockState.abort()。
        Item {
            anchors.fill: parent
            focus: false

            Keys.onEscapePressed: LockState.abort()
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space.m
            text: "预览模式 · Esc 退出 · 它锁不住任何东西"
            tone: "dim"
            role: "label"
            opacity: 0.6
        }

        // Esc 要能在输入框有焦点时也生效，所以挂在窗口级的 Shortcut 上，
        // 而不是指望上面那个 Item 抢到按键。
        Shortcut {
            sequences: ["Escape"]
            onActivated: LockState.abort()
        }
    }
}
