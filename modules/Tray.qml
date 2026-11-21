import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "root:/core"
import "root:/ui"

RowLayout {
    id: root

    // 菜单要挂在哪个窗口上；不传就只响应左键
    property var hostWindow: null

    spacing: Style.space.xs

    Repeater {
        model: SystemTray.items

        Surface {
            id: entry

            required property SystemTrayItem modelData

            implicitWidth: Style.font.sizeL + Style.space.xs * 2
            implicitHeight: implicitWidth
            tint: entry.hovered ? Style.color.hover : Style.moduleColor("tray")
            clickable: true

            onClicked: event => {
                const item = entry.modelData;
                if (event.button === Qt.LeftButton && !item.onlyMenu) {
                    item.activate();
                    return;
                }
                if (!item.hasMenu || !root.hostWindow)
                    return;

                menuLoader.active = true;
                // openAt 的坐标相对于父窗口（整条栏），不是相对于图标：
                // 要把图标位置映射到窗口坐标系，否则菜单会钉在栏的最左边。
                const pos = entry.mapToItem(null, 0, 0);
                menuLoader.item.openAt(root.hostWindow, pos.x, root.hostWindow.height);
            }

            StyledIcon {
                anchors.centerIn: parent
                source: entry.modelData.icon
                size: Style.font.sizeL
            }

            Loader {
                id: menuLoader

                active: false

                sourceComponent: StyledMenu {
                    handle: entry.modelData.menu
                    onCloseRequested: close()
                }
            }
        }
    }
}
