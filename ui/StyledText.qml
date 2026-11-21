import QtQuick
import "root:/core"

// 带主题的文字。modules/ 只说"这是什么语义"，不说"这是什么颜色"。
Text {
    id: root

    property string role: "body"    // label | body | title
    property string tone: "normal"  // normal | dim | accent | onAccent | onSelected | onHover | onModule | success | warning | error

    // Style 已按「本机装了哪些」解析过回退链
    font.family: Style.fontFamily
    font.pixelSize: root.role === "label" ? Style.font.sizeS : root.role === "title" ? Style.font.sizeL : Style.font.sizeM
    font.weight: root.role === "title" ? Font.DemiBold : Style.font.weight
    font.letterSpacing: Style.font.letterSpacing
    verticalAlignment: Text.AlignVCenter

    color: ({
            normal: Style.color.onSurface,
            dim: Style.color.onSurfaceDim,
            accent: Style.color.accent,
            onAccent: Style.color.onAccent,
            onSelected: Style.color.onSelected,
            onHover: Style.hoverOn,
            onModule: Style.moduleOn,
            success: Style.color.success,
            warning: Style.color.warning,
            error: Style.color.error
        })[root.tone] ?? Style.color.onSurface

    Behavior on color {
        enabled: Style.motion.enabled
        ColorAnimation {
            duration: Style.durNormal
        }
    }
}
