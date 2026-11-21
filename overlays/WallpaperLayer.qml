import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/core"
import "root:/ui"

// 壁纸层。WlrLayer.Background 在所有窗口之下。
//
// namespace 故意不叫 "desk"：Hyprland 的 layerrule 按正则匹配 namespace，
// 叫 desk 的话模糊规则会把壁纸自己也糊掉。
Scope {
    id: root

    required property var screen

    PanelWindow {
        id: win

        screen: root.screen
        visible: Wallpaper.hasWallpaper

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "desk-wallpaper"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // 图没铺满时的垫底色，跟主题
        color: Style.color.background

        WallpaperView {
            anchors.fill: parent
            source: Wallpaper.source
        }
    }
}
