import QtQuick
import QtQuick.Effects
import "root:/core"

// 锁屏背景：锁那一刻抓的那张屏，糊掉，再压一层暗罩。
//
// 截图拿不到时退回壁纸 —— 失败路径上也得有个像样的背景，
// 不能因为 grim 没装 / 没跑成就给一块纯色。
Item {
    id: root

    // 这块屏的名字，决定读哪张图。多屏时每块屏贴自己那一张。
    required property string screenName

    property real blurAmount: 1.0

    // 暗罩。糊过的窗口仍然是一张花花绿绿的图，不压暗的话
    // 时钟和密码条压在上面根本读不清。
    property real dim: 0.62

    readonly property bool hasShot: shot.status === Image.Ready

    // screenName 可能**晚于**本组件构造才到位：WlSessionLockSurface 的 screen
    // 是 Quickshell 在 surface 绑定到输出之后才赋的，而 LockWindow 的
    // Component.onCompleted（里面调 reset → reload）跑在那之前。
    // 只靠那一次 reload 的话，这里拿到的是空串，拼出 ".../desk-lock/.png"，
    // 读不到 → 悄悄退回壁纸。界面照常能用，所以不看日志根本发现不了。
    // 只在锁屏真的立着的时候才去读图。不加这个守卫的话，组件构造时
    // screenName 刚从 "" 变成屏幕名就会试读一次，而那会儿 grim 还没写完，
    // 日志里留一条无害但扎眼的 Cannot open。
    onScreenNameChanged: {
        if (LockState.wanted)
            root.reload();
    }

    function reload() {
        // 没拍截图（开机那一下 / 星空模式）就不去读，直接让 hasShot 为 false
        // 走壁纸那条路。读一个不存在的文件只会在日志里留一条必然的告警。
        if (root.screenName === "" || !LockState.captured) {
            shot.source = "";
            return;
        }
        // 路径每次都一样，Qt 会命中自己的 URL 缓存直接给回上一次那张 ——
        // 于是你看到的是「上回锁屏时的桌面」。cache: false 之外还得
        // 真的戳一下 source 才会重新读盘。
        shot.source = "";
        shot.source = `file://${LockState.shotFor(root.screenName)}`;
    }

    Image {
        id: shot

        anchors.fill: parent
        // 故意不在这里绑 source：这个 Item 在 shell 启动时就构造好了，
        // 那会儿截图还不存在，绑上去只会在日志里留一条 Cannot open。
        // 真正的赋值在 reload()，由窗口显示时调用 —— 那时 grim 已经退出了。
        fillMode: Image.PreserveAspectCrop
        // 放大本身就先糊掉一道（grim 已经按 1/4 出图），MultiEffect 只需要
        // 在这个基础上再推一把，就能到「完全读不出字」的程度。
        // 纯靠 blurMax 去怼的话，全分辨率的文字会糊成一条条拉丝。
        smooth: true
        // 不缓存：同一个路径每次锁屏内容都不一样
        cache: false
        // 同步加载。异步的话锁屏已经立起来了图还没解完，先闪一下纯色底 ——
        // 实测全分辨率 PNG 要 ~100ms。现在图只有 480×270，同步解码几毫秒，
        // 卡这一下换「第一帧就是对的」，值。
        asynchronous: false
        visible: false
        layer.enabled: true
    }

    // 截图没有就用壁纸垫底，一样糊
    Image {
        id: fallback

        anchors.fill: parent
        source: root.hasShot ? "" : Wallpaper.source
        fillMode: Image.PreserveAspectCrop
        // 壁纸可能是几千像素宽的原图，不设上限会去解整张。反正要糊，
        // 按屏幕的 1/4 读就够。
        sourceSize: Qt.size(Math.max(1, Math.round(root.width / 4)), Math.max(1, Math.round(root.height / 4)))
        // 这条是降级路径（grim 没跑成），保持异步：为了一个本来就不该发生的
        // 情况去同步解一张大图，会把主线程卡得更久。
        asynchronous: true
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: root.hasShot ? shot : fallback
        blurEnabled: true
        blur: root.blurAmount
        // blurMax 才是「能糊多狠」的上限，blur 只是 0~1 的系数。
        // 不抬这个值的话给到 blur: 1 也只是轻微发虚。64 是它的上限。
        blurMax: 64
        autoPaddingEnabled: false
    }

    // 两层罩：一层统一压暗保证可读，一层从中心往外的暗角
    // 把视线收到中间那一列上。
    Rectangle {
        anchors.fill: parent
        color: Style.alpha(Style.color.background, root.dim)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: Style.alpha(Style.color.background, 0.35)
            }
            GradientStop {
                position: 0.5
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Style.alpha(Style.color.background, 0.35)
            }
        }
    }
}
