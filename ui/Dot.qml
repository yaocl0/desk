import QtQuick
import "root:/core"

// 纯装饰色块：圆点、色条、分隔线都走它。
// 不像 Surface 那样自带 MouseArea，不会抢走父级的 hover。
Rectangle {
    id: root

    property string tone: "accent"  // accent | error | warning | success | outline | dim

    radius: Math.min(width, height) / 2

    color: ({
            accent: Style.color.accent,
            error: Style.color.error,
            warning: Style.color.warning,
            success: Style.color.success,
            outline: Style.color.outline,
            dim: Style.color.onSurfaceDim
        })[root.tone] ?? Style.color.accent

    Behavior on color {
        enabled: Style.motion.enabled
        ColorAnimation {
            duration: Style.durNormal
        }
    }
}
