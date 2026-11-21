import QtQuick
import "root:/core"

// 星空 + 星云。一整块 Canvas 画完，只在尺寸变化时重绘 ——
// 星星是静止的，会动的只有上面另外盖的那几颗闪烁点（见 twinkle）。
//
// 位置不用 Math.random()：那样每次重绘都是一张新的星图，窗口一改尺寸
// 星星就全体瞬移。改用一个固定种子的线性同余，同样的 seed 永远是同一张图。
Item {
    id: root

    property int stars: 220
    property int seed: 20261120
    property color tint: Style.color.accent

    // 星云的浓度。0 = 只有星星，纯黑底
    property real nebula: 1.0

    Canvas {
        id: sky

        anchors.fill: parent
        onWidthChanged: sky.requestPaint()
        onHeightChanged: sky.requestPaint()

        Connections {
            target: Style

            // 换主题要跟着换星云的颜色
            function onTokensChanged() {
                sky.requestPaint();
            }
        }

        onPaint: {
            const ctx = sky.getContext("2d");
            const w = sky.width;
            const h = sky.height;
            if (w <= 0 || h <= 0)
                return;
            ctx.reset();

            // 线性同余：和 Math.random 一样够随机，但给定 seed 就是确定的
            let s = root.seed;
            const rnd = () => {
                s = (s * 1103515245 + 12345) & 0x7fffffff;
                return s / 0x7fffffff;
            };

            ctx.fillStyle = Style.color.background;
            ctx.fillRect(0, 0, w, h);

            // 三团星云。径向渐变从 tint 淡到全透，叠在一起就有层次。
            // 位置写成相对比例，换分辨率不用改。
            const clouds = [[0.22, 0.28, 0.42], [0.74, 0.62, 0.5], [0.5, 0.88, 0.36]];
            for (const [cx, cy, cr] of clouds) {
                const r = Math.max(w, h) * cr;
                const g = ctx.createRadialGradient(w * cx, h * cy, 0, w * cx, h * cy, r);
                const c = root.tint;
                g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.13 * root.nebula));
                g.addColorStop(0.55, Qt.rgba(c.r, c.g, c.b, 0.045 * root.nebula));
                g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, w, h);
            }

            // 星星。大小和亮度都按同一个随机值推 —— 大的亮、小的暗，
            // 比两者各自随机更像真的星空（亮度本来就跟视星等相关）。
            const fg = Style.color.onSurface;
            for (let i = 0; i < root.stars; i++) {
                const x = rnd() * w;
                const y = rnd() * h;
                const m = rnd();
                const size = 0.6 + m * m * 1.9;
                ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.22 + m * 0.7);
                ctx.beginPath();
                ctx.arc(x, y, size, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    // 闪烁的几颗单独盖在上面。全部 140 颗都挂动画的话就是 140 条
    // 永不停止的 NumberAnimation，锁屏挂一晚上没必要为这个烧 CPU。
    Repeater {
        model: Style.motion.enabled ? 7 : 0

        Rectangle {
            id: twinkle

            required property int index

            // 和上面那套 LCG 不同源，不用对齐 —— 它们只是「另外几颗星」
            readonly property real fx: (Math.sin(twinkle.index * 12.9898) * 43758.5453) % 1
            readonly property real fy: (Math.sin(twinkle.index * 78.233) * 43758.5453) % 1

            x: Math.abs(twinkle.fx) * root.width
            y: Math.abs(twinkle.fy) * root.height
            width: 2.4
            height: width
            radius: width / 2
            color: Style.color.onSurface

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.visible

                NumberAnimation {
                    to: 0.15
                    duration: 1400 + twinkle.index * 260
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.95
                    duration: 1200 + twinkle.index * 180
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
