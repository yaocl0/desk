import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/core"

// 通用弹出面板。内容直接写在里面，纵向排列。
// 和 StyledMenu 的区别：那个是 DBusMenu 的渲染器，这个装任意内容。
PopupWindow {
    id: root

    default property alias content: body.data

    property var anchorWindow: null
    property int anchorX: 0
    property int anchorY: 0
    readonly property int pad: Style.space.m
    property int minWidth: Style.space.l * 8
    // 菜单式内容要贴紧（macOS 菜单行是连续的），默认留一点气口
    property int spacing: Style.space.s

    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: Math.max(body.implicitWidth, root.minWidth) + root.pad * 2
    implicitHeight: body.implicitHeight + root.pad * 2

    anchor {
        window: root.anchorWindow
        rect.x: root.anchorX
        rect.y: root.anchorY
    }

    // x 做个夹取，靠右的按钮不会把面板顶出屏幕
    function openFrom(item: Item, window) {
        if (!item || !window)
            return;
        const pos = item.mapToItem(null, 0, 0);
        root.anchorWindow = window;
        root.anchorX = Math.max(0, Math.min(pos.x, window.width - root.implicitWidth));
        root.anchorY = window.height;
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function toggleFrom(item: Item, window) {
        if (root.visible)
            root.close();
        else
            root.openFrom(item, window);
    }

    Surface {
        anchors.fill: parent
        level: 2
        radius: Style.shape.radiusL

        ColumnLayout {
            id: body

            anchors.fill: parent
            anchors.margins: root.pad
            spacing: root.spacing
        }
    }
}
