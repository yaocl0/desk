import QtQuick
import QtQuick.Shapes
import "root:/core"

// 参数化的「花瓣 / 曲奇」形状 —— Material 3 Expressive 那套圆形变体的纯 QML 版。
//
// 为什么不用 m3shapes：那是个要 cmake 编译、再 sudo 装进 /usr/lib/qt6 的 C++ 插件，
// 装完 pacman 不认它，Qt 一升级还得重编一遍。这里要的只是「圆周上 N 个圆润凸起」
// 这一类形状，一个极坐标半径函数就够了：
//
//   r(θ) = valley + (1 - valley) · ((1 + cos(leaves·θ)) / 2) ^ sharpness
//
//   leaves    波峰数。0 时 cos 恒为 1，r 恒等于 1 —— 正圆，不用单独开一条分支
//   valley    谷底半径占峰顶的比例。0.88 是曲奇的浅扇贝，0.62 是四叶草的深缺口
//   sharpness 默认 1 —— 纯余弦，整条边处处平滑，谷底是圆的。
//             < 1 会把花瓣撑胖、同时把谷底收成尖角（0.62 接近 M3 那种
//             「鼓起来」的叶子，但放大看每个缺口都是一个角）；
//             > 1 则花瓣变窄、谷底变宽平。要尖角的话按实例给，别改默认。
//
// 形变（morph）不是去插值 leaves —— 非整数的 leaves 会让曲线在 θ=2π 处接不回
// 起点，留下一道缝。改成在同一组 θ 上插值两条半径曲线：两端各自闭合，
// 插出来的中间态自然也闭合。悬停时换形状、命令模式下 8 瓣变 7 瓣都走这条路。
Item {
    id: root

    // ── 起始形状 ──
    property int leaves: 8
    property real valley: 0.72

    // ── 目标形状，morph 0→1 过去 ──
    property int toLeaves: root.leaves
    property real toValley: root.valley
    property real morph: 0

    property real sharpness: 1.0
    property color color: Style.color.surface

    // 顶部白色高光的强度，0 = 纯色平涂。玻璃质感全靠它 ——
    // 一个半透明的形状如果上下一样亮，看着就只是「一块有颜色的塑料」。
    property real topLight: 0

    // 描边。半透明的花瓣压在一屏亮文字上时，轮廓全靠这一圈细边钉住 ——
    // 没有它，边缘那几像素的渐变会和底下的内容糊在一起。
    property color strokeColor: "transparent"
    property real strokeWidth: 0

    // 采样点数。按波峰数给，不是固定值：12 瓣的曲奇用 180 个点会在每片叶子上
    // 只摊到 15 个点，边缘肉眼可见地发棱。
    readonly property int samples: Math.max(180, Math.max(root.leaves, root.toLeaves) * 30)

    function radiusAt(t: real, n: int, v: real): real {
        if (n <= 0)
            return 1;
        return v + (1 - v) * Math.pow((1 + Math.cos(n * t)) / 2, root.sharpness);
    }

    // 整条折线。只在尺寸 / 形状参数变化时重算 —— 开场动画动的是 scale 和
    // rotation，不碰这里，所以那 600ms 里一个点都不用重新算。
    readonly property var points: {
        const cx = root.width / 2;
        const cy = root.height / 2;
        const n = root.samples;
        const m = root.morph;
        const out = [];
        for (let i = 0; i <= n; i++) {
            const t = i / n * 2 * Math.PI;
            const a = root.radiusAt(t, root.leaves, root.valley);
            const b = root.radiusAt(t, root.toLeaves, root.toValley);
            const r = a + (b - a) * m;
            out.push(Qt.point(cx + cx * r * Math.cos(t), cy + cy * r * Math.sin(t)));
        }
        return out;
    }

    Shape {
        anchors.fill: parent
        // CurveRenderer 走 GPU 曲线求值，边缘不靠多重采样。默认的
        // GeometryRenderer 在这种几百个点的折线上会把花瓣边缘画出锯齿。
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // -1 = 不描边。给 0 的话 Qt 仍然会走一遍描边的几何生成。
            strokeWidth: root.strokeWidth > 0 ? root.strokeWidth : -1
            strokeColor: root.strokeColor

            // 恒定用渐变而不是「有高光才切渐变」：topLight = 0 时
            // Qt.tint 的 alpha 也是 0，三个 stop 同色，结果和平涂一模一样，
            // 但省掉了一次 fillColor / fillGradient 之间的条件绑定。
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
