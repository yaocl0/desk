import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/modules"

// 环形启动器的窗口层。和 overlays/LauncherLayer.qml 是两个平行的实现，
// 共用同一个 core/LauncherState —— 于是 IPC、快捷键、「开在哪块屏」那套
// 一行都不用改，shell.qml 里换哪个组件就用哪个。
//
// 分工：这里管窗口、遮罩、滚轮、点外面关掉；环本体在 modules/RingLauncher.qml。
Scope {
    id: root

    required property var screen

    // 只在打开它的那块屏上出现。latch 不到屏幕名（没跑 Hyprland）时
    // 退化成「每块屏都出一个」—— 单屏下没区别，多屏下至少不会一块都没有。
    readonly property bool onThisScreen: LauncherState.screenName === "" || LauncherState.screenName === root.screen.name
    readonly property bool shouldShow: LauncherState.open && root.onThisScreen

    PanelWindow {
        id: win

        screen: root.screen

        // 关掉之后还要再挂一会儿，把收场动画放完 —— 直接 unmap 的话
        // 花瓣是「啪」地消失，不是收回去的。
        visible: root.shouldShow || panel.intro > 0.01

        // 底色全透明，压暗交给里面那块 Rectangle：它要跟着开场进度一起淡入，
        // 而 PanelWindow.color 改不动就没法做这件事。
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        // 不叫 desk：那个 namespace 上挂着 blur + ignorealpha 0.1 的 layerrule，
        // 而这是一张铺满全屏的窗口 —— 遮罩那 0.12 的 alpha 刚好过了阈值，
        // 结果整块屏幕都被糊一遍。想要花瓣背后有模糊的话，在 hypr 那边单独加：
        //   layerrule = blur, ^desk-ring$
        //   layerrule = ignorealpha 0.3, ^desk-ring$
        // 0.3 这个阈值刚好放过遮罩、留下花瓣。
        WlrLayershell.namespace: "desk-ring"
        // 要打字就必须独占键盘。关掉的瞬间焦点自动还给原来的窗口。
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // 环是居中的，和栏不相干，所以盖满整屏 —— 遮罩要连栏一起压暗，
        // 不然栏那一条会亮得很突兀。
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // 同样要管「构造出来就是开着」的情况：QML 不会为初始求值触发 onXChanged，
        // 热重载时启动器正开着的话 intro 会停在 0，整个环 opacity 全是 0。
        Component.onCompleted: {
            if (win.visible) {
                panel.reset();
                panel.play();
            }
        }

        onVisibleChanged: {
            if (win.visible) {
                panel.reset();
                panel.play();
                return;
            }
            // 窗口刚 unmap。独占键盘的 layer surface 还挂着的时候，合成器
            // 不会把焦点让给别的窗口 —— 必须等它真的消失了再动手，否则
            // toplevel.activate() 会被「焦点还给原窗口」盖掉。
            // 再等 80ms 是让 unmap 的 Wayland 请求真的发到合成器。
            if (panel.pending)
                act.restart();
        }

        Timer {
            id: act

            interval: 80
            onTriggered: panel.runPending()
        }

        // 开着的时候再关一次（比如又按了一下快捷键）：窗口还在，
        // 只是 shouldShow 变 false，这里把收场动画推起来。
        Connections {
            target: root

            function onShouldShowChanged() {
                if (root.shouldShow) {
                    panel.reset();
                    panel.play();
                } else {
                    panel.fold();
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            // 跟着开场进度淡入。主题的 launcher.scrim 仍然说了算 ——
            // gruvbox 把它设成 0，那这层就是全透明的，桌面一点都不压暗。
            color: Style.alpha(Style.color.background, Style.launcher.scrim * panel.intro)

            MouseArea {
                anchors.fill: parent
                onClicked: LauncherState.hide()
            }
        }

        // 滚轮转环。放在窗口上而不是环上 —— 滚到哪儿都该管用，
        // 不用先把鼠标挪到那 440px 的圈里。
        WheelHandler {
            property real acc: 0

            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                // 触摸板一次滑动会发几十个小增量，攒够一格再动，
                // 否则轻轻一划环就转过去半圈。
                acc += event.angleDelta.y;
                if (Math.abs(acc) < 120)
                    return;
                panel.step(acc < 0 ? 1 : -1, false);
                acc = 0;
            }
        }

        RingLauncher {
            id: panel

            anchors.centerIn: parent

            onDismissed: LauncherState.hide()
        }
    }
}
