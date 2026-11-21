import QtQuick
import "root:/core"

// 带像素扩散转场的壁纸显示。
//
// ping-pong 双缓冲：img0 / img1 轮流当「前景」（当前显示）和「后备」（装新图）。
// 转场结束只交换角色、不重新加载任何图 —— 早先的做法是把新图回写进旧图槽位，
// 那会触发一次异步解码，而 progress 同时归零要去显示那张正在解码的图，
// 结果就是动画末尾闪一下。
//
// 边缘辉光色取 Style.color.accent，换主题连转场边缘一起变。
Item {
    id: root

    property url source

    // 默认全部来自主题 token，必要时可在实例上覆盖
    property int cellPx: Style.effect.wallpaperCell
    property int seeds: Style.effect.wallpaperSeeds
    property real glow: Style.effect.wallpaperGlow
    property real irregular: 0.08

    readonly property bool transitioning: anim.running

    // 0 / 1：当前显示的是哪一张
    property int frontIndex: 1
    readonly property Image frontImg: root.frontIndex === 0 ? img0 : img1
    readonly property Image backImg: root.frontIndex === 0 ? img1 : img0

    // 两张图都不自己渲染，只作为着色器的纹理来源
    Image {
        id: img0

        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        width: root.width
        height: root.height
        sourceSize: Qt.size(root.width, root.height)
        onStatusChanged: root._onImageReady(img0)
    }

    Image {
        id: img1

        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        width: root.width
        height: root.height
        sourceSize: Qt.size(root.width, root.height)
        onStatusChanged: root._onImageReady(img1)
    }

    onSourceChanged: {
        if (root.source == "")
            return;

        // 上一次还没放完就来了新的：先让它落位，再开始新的
        if (anim.running)
            root._swap();

        const b = root.backImg;
        if (b.source == root.source && b.status === Image.Ready)
            root._begin();      // 刚好是上一张，纹理还在，不用重新解码
        else
            b.source = root.source;
    }

    function _onImageReady(img: Image) {
        if (img.status !== Image.Ready || img !== root.backImg)
            return;
        root._begin();
    }

    function _begin() {
        // 第一张图没有「旧图」可吞，或主题把时长设成 0 → 直接落位
        if (root.frontImg.status !== Image.Ready || Style.wallpaperDuration <= 0) {
            root._swap();
            return;
        }
        fx.seedValue = Math.random() * 1000;
        anim.restart();
    }

    // 交换角色并把 progress 归零。
    // 交换后 oldTex 就是刚刚揭示完的那张 —— 画面不变，所以不会闪。
    function _swap() {
        anim.stop();
        root.frontIndex = 1 - root.frontIndex;
        fx.progress = 0;
    }

    ShaderEffect {
        id: fx

        anchors.fill: parent
        // 两张都没就绪前别渲染，否则采样空纹理会闪
        visible: root.frontImg.status === Image.Ready

        fragmentShader: "root:/ui/shaders/spread.frag.qsb"

        // 名字必须和着色器里的 uniform 一一对应
        property variant oldTex: root.frontImg
        property variant newTex: root.backImg
        property real progress: 0
        property real cell: root.cellPx / Math.max(1, fx.width)
        property real glow: root.glow
        property real irregular: root.irregular
        property real seedValue: 0
        property real seedCount: Math.max(1, Math.min(32, root.seeds))
        property real aspect: fx.width / Math.max(1, fx.height)
        property color edgeColor: Style.color.accent

        NumberAnimation {
            id: anim

            target: fx
            property: "progress"
            from: 0
            to: 1
            duration: Style.wallpaperDuration
            easing.type: Easing.InOutSine
            onFinished: root._swap()
        }
    }
}
