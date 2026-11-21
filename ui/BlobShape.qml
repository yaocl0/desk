import QtQuick
import QtQuick.Shapes
import "root:/core"

// 一圈圆并起来的那一坨。每个格子底下压一个圆，相邻的圆互相叠住，
// 中间再垫一个圆把当中填实 —— 轮廓就是「胖的圆弧凸起 + 两凸之间的凹口」。
//
// 和 ui/PetalShape 的区别：那个是正弦花瓣（r 随 cos 起伏），凸起是波峰，
// 边缘处处是曲线但没有一段是真正的圆弧。这个的每一片**就是一个圆**。
//
// 做法仍是极坐标采样成折线，只是半径函数换成「若干圆求并」：
// 一条从原点出发、方向 θ 的射线，和某个偏心圆的远交点是
//   r = d·cos Δ + √(rl² − d²sin²Δ)       （Δ = θ 与该圆圆心方向的夹角）
// 对所有圆取最大值，再和中心圆取最大值，就是并集的外轮廓。
// 成立的前提是这坨形状对原点是星形的 —— 圆绕着原点均匀摆一圈，天然满足。
Item {
    id: root

    property int lobes: 8

    // 每片凸起**露在外面的那段圆弧**有多少度。
    //
    // 这个比直接给圆心距离好使：圆露得多就是一颗球卡在边上，露得少就是
    // 一道平缓的扇贝。给 90（四分之一圆）就是后者。
    //
    // 圆心距 d 和半径 rl 由它反解，不单独给：
    //   峰值要落在外接圆上        d + rl = 1
    //   相邻两圆的交点要正好在 ±φ₀   tan ψ · (d + rl·cos φ₀) = rl·sin φ₀
    // 其中 ψ = π/lobes（相邻凸起的半间隔），φ₀ = lobeArc/2。
    // 八瓣 + 90° 解出来正好 d = rl = 0.5。
    property real lobeArc: 90

    // 中心圆，只当兜底：lobeArc 小到圆心跑得很外时，当中会空出一个洞。
    // 正常参数下凸起的圆自己就盖过中心，这个值用不上。
    property real core: 0.3

    readonly property real _psi: Math.PI / Math.max(1, root.lobes)
    readonly property real _phi: root.lobeArc * Math.PI / 360   // 弧长的一半，转弧度

    // d / rl。分母为 0（φ₀ 或 ψ 退化）时退回 1，等价于 d = rl。
    readonly property real _ratio: {
        const t = Math.tan(root._psi);
        if (t <= 0)
            return 1;
        const v = (Math.sin(root._phi) - Math.cos(root._phi) * t) / t;
        return v > 0 ? v : 0;
    }

    // 两者之和恒为 1，于是最远点就是外接半径，调用方不用留余量
    readonly property real lobeRadius: 1 / (1 + root._ratio)
    readonly property real lobeCenter: root._ratio * root.lobeRadius

    property color color: Style.color.surface
    property real topLight: 0
    property color strokeColor: "transparent"
    property real strokeWidth: 0

    readonly property int samples: Math.max(240, root.lobes * 40)

    function radiusAt(t: real): real {
        let r = root.core;
        const d = root.lobeCenter;
        const rl = root.lobeRadius;
        for (let k = 0; k < root.lobes; k++) {
            const delta = t - k * 2 * Math.PI / root.lobes;
            const b = d * Math.sin(delta);
            const disc = rl * rl - b * b;
            if (disc < 0)
                continue;   // 这条射线根本不穿过这个圆
            const hit = d * Math.cos(delta) + Math.sqrt(disc);
            if (hit > r)
                r = hit;
        }
        return r;
    }

    readonly property var points: {
        const cx = root.width / 2;
        const cy = root.height / 2;
        const n = root.samples;
        const out = [];
        for (let i = 0; i <= n; i++) {
            const t = i / n * 2 * Math.PI;
            const r = root.radiusAt(t);
            out.push(Qt.point(cx + cx * r * Math.cos(t), cy + cy * r * Math.sin(t)));
        }
        return out;
    }

    Shape {
        anchors.fill: parent
        // CurveRenderer 走 GPU 曲线求值。默认的 GeometryRenderer 在这种
        // 几百点的折线上会把凹口那几像素画出锯齿。
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.strokeWidth > 0 ? root.strokeWidth : -1
            strokeColor: root.strokeColor

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height

                GradientStop {
                    position: 0
                    color: Qt.tint(root.color, Qt.rgba(1, 1, 1, root.topLight))
                }
                GradientStop {
                    position: 0.55
                    color: root.color
                }
                GradientStop {
                    position: 1
                    color: root.color
                }
            }

            PathPolyline {
                path: root.points
            }
        }
    }
}
