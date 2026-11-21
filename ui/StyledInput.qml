import QtQuick
import "root:/core"

// 带主题的单行输入框。modules/ 不许裸 Text，同理不该裸 TextInput ——
// 字体、光标、选区颜色都在这里一次性接到 token 上。
//
// 按键不自己解释：原样抛给 keyPressed，由使用方决定「↓ 是移动选中项还是移动光标」。
// 使用方把 event.accepted 设成 true，TextInput 就不会再处理这个键。
Item {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property string glyph: ""            // 左侧提示字形，空 = 不占位
    readonly property bool inputFocused: input.activeFocus

    signal keyPressed(var event)

    function focusInput() {
        input.forceActiveFocus();
    }

    function clear() {
        input.text = "";
    }

    implicitWidth: Style.space.l * 10
    implicitHeight: Math.round(Style.font.sizeM * 2.4)

    StyledIcon {
        id: lead

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.glyph !== ""
        glyph: root.glyph
        tone: "dim"
        size: Style.font.sizeL
    }

    TextInput {
        id: input

        anchors.left: lead.visible ? lead.right : parent.left
        anchors.leftMargin: lead.visible ? Style.space.s : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        font.family: Style.fontFamily
        font.pixelSize: Style.font.sizeL
        font.weight: Style.font.weight
        font.letterSpacing: Style.font.letterSpacing
        color: Style.color.onSurface
        // 选区用 accent 而不是 color.selected：极简主题把 selected 设成
        // transparent（选中只靠文字变色），那在输入框里会变成「看不见自己选了什么」
        selectionColor: Style.color.accent
        selectedTextColor: Style.color.onAccent
        selectByMouse: true
        clip: true
        verticalAlignment: TextInput.AlignVCenter

        Keys.onPressed: event => root.keyPressed(event)

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            tone: "dim"
            font.pixelSize: Style.font.sizeL
        }

        // 自带光标不跟主题色。给了 delegate 之后闪烁也归自己管，
        // 所以这里无条件闪 —— 它是光标，不是界面动效，不受 motion.enabled 门控。
        cursorDelegate: Rectangle {
            width: Math.max(1, Math.round(Style.font.sizeM / 7))
            radius: width / 2
            color: Style.color.accent

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: input.activeFocus

                NumberAnimation {
                    to: 0
                    duration: 350
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation {
                    duration: 250
                }
                NumberAnimation {
                    to: 1
                    duration: 350
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation {
                    duration: 450
                }
            }
        }
    }
}
