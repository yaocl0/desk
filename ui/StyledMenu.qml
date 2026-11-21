import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "root:/core"

// 用 QML 重画 DBusMenu，替代 SystemTrayItem.display() 弹出的原生 Qt QMenu。
// 原生菜单由 Qt 平台主题渲染，不走我们的 token，所以和栏是两套视觉。
//
// QsMenuEntry 继承 QsMenuHandle，所以子菜单可以把 entry 直接当 handle 递归下去。
PopupWindow {
    id: root

    property var handle: null        // QsMenuHandle：顶层菜单，或某个有子项的 entry
    property bool topLevel: true     // 只有顶层抓焦点，子菜单跟着父级

    // 任意一层点中了真正的菜单项 → 冒泡到顶层，由调用方收起整条链
    signal closeRequested

    readonly property int pad: Style.space.xs
    readonly property int rowHeight: Math.round(Style.font.sizeM * 1.9)
    readonly property int minWidth: Style.space.l * 8

    property var openSub: null       // 当前展开的子菜单，用于互斥

    // 锚定目标。PopupWindow 的 parentWindow / relativeX / relativeY 已废弃。
    property var anchorWindow: null
    property int anchorX: 0
    property int anchorY: 0

    visible: false
    color: "transparent"
    grabFocus: root.topLevel
    implicitWidth: Math.max(body.implicitWidth, root.minWidth) + root.pad * 2
    implicitHeight: body.implicitHeight + root.pad * 2

    anchor {
        window: root.anchorWindow
        rect.x: root.anchorX
        rect.y: root.anchorY
    }

    function openAt(window, x: int, y: int) {
        root.anchorWindow = window;
        root.anchorX = x;
        root.anchorY = y;
        root.visible = true;
    }

    function close() {
        root.closeSub();
        root.visible = false;
    }

    function closeSub() {
        if (root.openSub) {
            root.openSub.close();
            root.openSub = null;
        }
    }

    onVisibleChanged: {
        if (!root.visible)
            root.closeSub();
    }

    QsMenuOpener {
        id: opener

        menu: root.handle
    }

    Surface {
        anchors.fill: parent
        level: 2
        radius: Style.shape.radiusM

        ColumnLayout {
            id: body

            anchors.fill: parent
            anchors.margins: root.pad
            spacing: 0

            Repeater {
                model: opener.children

                Item {
                    id: row

                    required property var modelData
                    readonly property bool sep: row.modelData.isSeparator

                    Layout.fillWidth: true
                    implicitWidth: row.sep ? 0 : content.implicitWidth + Style.space.m * 2
                    implicitHeight: row.sep ? Style.space.s : root.rowHeight

                    Dot {
                        visible: row.sep
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Style.space.s
                        anchors.rightMargin: Style.space.s
                        height: 1
                        tone: "outline"
                    }

                    Surface {
                        id: rowBg

                        visible: !row.sep
                        anchors.fill: parent
                        level: 1
                        bordered: false
                        radius: Style.shape.radiusS
                        tint: rowBg.hovered && row.modelData.enabled ? Style.color.hover : "transparent"
                        clickable: row.modelData.enabled

                        onClicked: {
                            if (row.modelData.hasChildren) {
                                root.closeSub();
                                subLoader.active = true;
                                subLoader.item.openAt(root, root.width, row.y);
                                root.openSub = subLoader.item;
                            } else {
                                row.modelData.triggered();
                                root.closeRequested();
                            }
                        }

                        // 移到别的项上时收掉已展开的子菜单
                        onHoveredChanged: {
                            if (rowBg.hovered && root.openSub && root.openSub !== subLoader.item)
                                root.closeSub();
                        }

                        RowLayout {
                            id: content

                            anchors.fill: parent
                            anchors.leftMargin: Style.space.m
                            anchors.rightMargin: Style.space.m
                            spacing: Style.space.s

                            // 勾选 / 单选 指示
                            StyledText {
                                visible: row.modelData.buttonType !== QsMenuButtonType.None
                                tone: !row.modelData.enabled ? "dim" : rowBg.hovered ? "onHover" : "accent"
                                text: {
                                    const on = row.modelData.checkState === Qt.Checked;
                                    if (row.modelData.buttonType === QsMenuButtonType.RadioButton)
                                        return on ? "●" : "○";
                                    return on ? "✓" : " ";
                                }
                            }

                            IconImage {
                                Layout.preferredWidth: Style.font.sizeM
                                Layout.preferredHeight: Style.font.sizeM
                                visible: row.modelData.icon !== ""
                                source: row.modelData.icon
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.text
                                tone: !row.modelData.enabled ? "dim" : rowBg.hovered ? "onHover" : "normal"
                                elide: Text.ElideRight
                            }

                            StyledText {
                                visible: row.modelData.hasChildren
                                text: "›"
                                tone: rowBg.hovered ? "onHover" : "dim"
                            }
                        }
                    }

                    // 子菜单必须用 URL 加载：QML 的静态检查禁止组件直接自引用
                    // （sourceComponent: StyledMenu {} 会报 "instantiated recursively"）。
                    Loader {
                        id: subLoader

                        active: false
                        source: "root:/ui/StyledMenu.qml"

                        onLoaded: {
                            subLoader.item.handle = row.modelData;
                            subLoader.item.topLevel = false;
                            subLoader.item.closeRequested.connect(root.closeRequested);
                        }
                    }
                }
            }
        }
    }
}
