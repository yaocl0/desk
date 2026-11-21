import QtQuick
import "root:/core"
import "root:/ui"
import "root:/services"

// 锁屏画面的编排。只管「什么东西摆在哪」，窗口在 overlays/LockLayer.qml，
// 状态和认证在 core/LockState.qml —— 和启动器那套分工一致。
//
// 从上到下一条中轴：时间 → 播放器 → 密码条 → 一行状态。
// 不做 Nebula 那种卡片绕圈飞的编排：那套好看，但它每一块都绑着自己那边
// 的服务（Lyrics / Equalizer / Recorder），这边没有对应的东西，
// 硬搬会得到一圈空壳。
Item {
    id: root

    signal dismissed

    // 哪块屏 —— 背景要据此读对应的那张截图
    required property string screenName

    // 0 → 1 的出场进度。和环形启动器一个套路：一条线性进度，
    // 各部件各自从里面截一段，而不是十几条动画互相对表。
    property real intro: 0

    function phase(t: real, start: real, len: real): real {
        return Math.max(0, Math.min(1, (t - start) / len));
    }

    function play() {
        root.intro = 0;
        if (Style.motion.enabled)
            introAnim.restart();
        else
            root.intro = 1;
    }

    NumberAnimation {
        id: introAnim

        target: root
        property: "intro"
        to: 1
        duration: 900
        easing.type: Easing.OutCubic
    }

    // ── 背景：两套，按 config.lockBackground 二选一 ──────────
    // 和 shell.qml 的启动器注册同一个写法，用 Loader 而不是 visible：
    // 没选中的那套一个对象都不创建 —— 它们各自都不便宜，一个要常驻一张
    // 全屏截图 + MultiEffect，另一个要一块全屏 Canvas。
    //
    // blur 这一路写成「不等于 stars」：config.json 被手改成不认识的值时
    // 退回模糊桌面，总比锁屏背后空一块强。
    Loader {
        id: blurBg

        anchors.fill: parent
        active: Config.lockBackground !== "stars"

        sourceComponent: LockBackdrop {
            screenName: root.screenName
        }
    }

    Loader {
        anchors.fill: parent
        active: Config.lockBackground === "stars"

        sourceComponent: Starfield {
            // 星云跟着主题的 accent 走，于是四套主题各是一片不同颜色的星空
            tint: Style.color.accent
        }
    }

    // 解锁成功时整幅画面淡出。真接上 WlSessionLock 之后，
    // 这段动画放完才调 LockState.finish()，所以「开锁」是看得见的一拍。
    opacity: LockState.unlocking ? 0 : 1

    Behavior on opacity {
        enabled: Style.motion.enabled

        NumberAnimation {
            duration: Style.durNormal * 2
            easing.type: Easing.InCubic
        }
    }

    Column {
        id: stack

        anchors.centerIn: parent
        width: Math.min(parent.width - Style.space.l * 4, Style.space.l * 24)
        spacing: Style.space.l

        // ── 时间 ──────────────────────────────────────────
        LockClock {
            id: clock

            readonly property real t: root.phase(root.intro, 0, 0.5)

            anchors.horizontalCenter: parent.horizontalCenter
            opacity: clock.t
            // 轻微下落。位移给得很小 —— 锁屏是每天看几十次的东西，
            // 动静大了很快就烦。
            //
            // 这里必须写 clock.t 不能写 parent.t：Translate 不是 Item，
            // 它里面的 parent 解析到的是 LockClock 的父级（那一列 Column），
            // 读出来 undefined、y 变 NaN，整块就不画了 —— 而且一句都不报。
            transform: Translate {
                y: (1 - clock.t) * -Style.space.l
            }
        }

        // ── 密码条 ────────────────────────────────────────
        LockInput {
            id: input

            readonly property real t: root.phase(root.intro, 0.25, 0.5)

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, Style.space.l * 18)
            opacity: t
            transform: Translate {
                y: (1 - input.t) * Style.space.l
            }
        }
    }

    // ── 底部状态 ────────────────────────────────────────────
    // 不放进上面那个 Column：那一列是居中的，这一行该贴底，
    // 两者挂在一起的话屏幕高度一变整列就跟着飘。
    Row {
        readonly property real t: root.phase(root.intro, 0.6, 0.4)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space.l * 2
        spacing: Style.space.l
        opacity: t

        Row {
            spacing: Style.space.xs
            visible: Batt.available

            StyledIcon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: Batt.charging ? "󰂄" : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.max(0, Math.min(10, Math.floor(Batt.percent / 10)))]
                tone: Batt.low ? "error" : "dim"
                size: Style.font.sizeM
            }

            StyledText {
                text: `${Batt.percent}%`
                tone: Batt.low ? "error" : "dim"
            }
        }

        Row {
            spacing: Style.space.xs
            visible: Weather.ready

            StyledIcon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: Weather.glyph
                tone: "dim"
                size: Style.font.sizeM
            }

            StyledText {
                text: `${Math.round(Weather.temp)}° ${Weather.summary}`
                tone: "dim"
            }
        }

        Row {
            spacing: Style.space.xs

            StyledIcon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰻠"
                tone: "dim"
                size: Style.font.sizeM
            }

            StyledText {
                text: `${Math.round(Sys.cpu * 100)}%`
                tone: "dim"
            }

            StyledIcon {
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space.s
                glyph: "󰍛"
                tone: "dim"
                size: Style.font.sizeM
            }

            StyledText {
                text: `${Sys.memUsedGb.toFixed(1)}G`
                tone: "dim"
            }
        }
    }

    // 点哪儿都把焦点抓回输入框 —— 锁屏上除了打字没别的事要做，
    // 「点了一下然后发现打不进字」是最没必要的卡壳。
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: input.focusField()
        z: -1
    }

    function focusInput() {
        input.focusField();
    }

    function reset() {
        input.clear();
        // 星空那一路没有东西要重读；blurBg.item 在未激活时是 null
        if (blurBg.item)
            blurBg.item.reload();
    }
}
