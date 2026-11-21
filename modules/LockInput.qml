import QtQuick
import "root:/core"
import "root:/ui"

// 密码条。一颗药丸，左边一个会随状态变形的锁，中间是「打了几下」，
// 右边是提交。
//
// 中间刻意不显示任何和密码有关的东西 —— 连 • 都不是等长的：
// 每一个点是不同瓣数的花瓣、各自慢慢自转，肩膀后面的人数不出你打了几位，
// 但你自己看得出有没有打进去。LockState 那边也只存 typed 的长度。
Item {
    id: root

    signal submitted

    readonly property bool typing: LockState.typed > 0
    // 一开始打新的就不要再显示上一次的错误了
    readonly property bool failed: LockState.failed && !root.typing

    // 每个点一个形状，循环用。瓣数差得开，扫一眼就知道有几个点。
    readonly property var dotShapes: [
        {
            leaves: 6,
            valley: 0.84
        },
        {
            leaves: 4,
            valley: 0.66
        },
        {
            leaves: 9,
            valley: 0.88
        },
        {
            leaves: 5,
            valley: 0.72
        },
        {
            leaves: 12,
            valley: 0.9
        }
    ]
    readonly property int dotMax: 10
    readonly property int shown: Math.min(LockState.typed, root.dotMax)

    // 点自转用的时钟。只在真的要动的时候跑 —— 锁屏可能挂一整夜，
    // 没人打字的时候不该有任何东西在耗帧。
    property real t: 0

    FrameAnimation {
        running: root.typing && root.visible && Style.motion.enabled
        onTriggered: root.t += frameTime
    }

    function clear() {
        field.text = "";
    }

    function focusField() {
        field.forceActiveFocus();
    }

    implicitWidth: Style.space.l * 20
    implicitHeight: Math.round(Style.font.sizeL * 3)

    Surface {
        anchors.fill: parent
        level: 2
        radius: height / 2
        // 边框是唯一的状态指示：错了变红，在打 / 在验变 accent，其余近乎看不见
        bordered: false

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: 1.5
            border.color: root.failed ? Style.color.error : root.typing || LockState.checking ? Style.color.accent : Style.alpha(Style.color.onSurface, 0.12)

            Behavior on border.color {
                enabled: Style.motion.enabled

                ColorAnimation {
                    duration: Style.durNormal
                }
            }
        }
    }

    // ── 左边的锁 ────────────────────────────────────────────
    Item {
        id: lockBox

        x: Style.space.xs
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - Style.space.xs * 2
        height: lockBox.width

        PetalShape {
            anchors.fill: parent
            // 四个状态四个形状，变形是连续的（PetalShape 在两条半径曲线之间插值）
            leaves: 9
            valley: 0.88
            toLeaves: root.failed ? 5 : LockState.unlocking ? 8 : LockState.checking ? 4 : 12
            toValley: root.failed ? 0.74 : LockState.unlocking ? 0.6 : LockState.checking ? 0.66 : 0.82
            morph: root.failed || LockState.unlocking || LockState.checking || root.typing ? 1 : 0
            color: Style.alpha(root.failed ? Style.color.error : Style.color.accent, 0.26)

            Behavior on morph {
                enabled: Style.motion.enabled

                NumberAnimation {
                    duration: Style.durNormal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            // 验的时候转起来：这是唯一一个「它没死、在等 PAM」的信号
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 2400
                loops: Animation.Infinite
                running: (LockState.checking || LockState.unlocking) && Style.motion.enabled
            }
        }

        StyledIcon {
            anchors.centerIn: parent
            glyph: LockState.unlocking ? "󰌿" : "󰌾"
            tone: root.failed ? "error" : "accent"
            size: Style.font.sizeL
        }
    }

    // ── 中间：提示语 / 一串点 ───────────────────────────────
    Item {
        anchors.left: lockBox.right
        anchors.leftMargin: Style.space.s
        anchors.right: send.left
        anchors.rightMargin: Style.space.s
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        StyledText {
            anchors.centerIn: parent
            visible: !root.typing && !LockState.checking
            text: root.failed ? LockState.message : LockState.unlocking ? "已解锁" : "输入密码"
            tone: root.failed ? "error" : "dim"
            font.pixelSize: Style.font.sizeM
        }

        Row {
            anchors.centerIn: parent
            spacing: Style.space.xs
            visible: root.typing || LockState.checking

            // 验的时候整排一起呼吸，表示「在等」
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: LockState.checking && Style.motion.enabled

                NumberAnimation {
                    to: 0.4
                    duration: 380
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 380
                    easing.type: Easing.InOutSine
                }
            }

            Repeater {
                model: root.shown

                Item {
                    id: dot

                    required property int index

                    // 超过 dotMax 之后点不再增加，但形状要跟着往前滚，
                    // 否则「还在打」这件事就看不出来了
                    readonly property int slot: (LockState.typed - root.shown + dot.index) % root.dotShapes.length

                    width: Math.round(Style.font.sizeM * 1.2)
                    height: dot.width

                    Component.onCompleted: pop.start()

                    NumberAnimation {
                        id: pop

                        target: dot
                        property: "scale"
                        from: 0
                        to: 1
                        duration: Style.motion.enabled ? 300 : 0
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.5
                    }

                    PetalShape {
                        anchors.fill: parent
                        // 轻微上下浮动 + 自转。相位按 index 错开，
                        // 整排就不是一起一落的机械感。
                        y: Math.sin(root.t * 3.2 + dot.index * 0.8) * 2
                        rotation: root.t * 45 + dot.index * 40
                        leaves: root.dotShapes[dot.slot].leaves
                        valley: root.dotShapes[dot.slot].valley
                        color: dot.index % 2 === 0 ? Style.color.accent : Style.alpha(Style.color.onSurface, 0.65)
                    }
                }
            }
        }
    }

    // ── 右边的提交 ──────────────────────────────────────────
    Item {
        id: send

        anchors.right: parent.right
        anchors.rightMargin: Style.space.xs
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - Style.space.xs * 2
        height: send.width
        scale: sendArea.pressed ? 0.88 : sendArea.containsMouse ? 1.06 : 1

        Behavior on scale {
            enabled: Style.motion.enabled

            NumberAnimation {
                duration: Style.durFast
                easing.type: Easing.OutCubic
            }
        }

        PetalShape {
            anchors.fill: parent
            leaves: 0
            valley: 1
            toLeaves: 9
            toValley: 0.84
            morph: root.typing ? 1 : 0
            color: root.typing ? Style.color.accent : Style.alpha(Style.color.onSurface, 0.1)

            Behavior on morph {
                enabled: Style.motion.enabled

                NumberAnimation {
                    duration: Style.durNormal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }
            Behavior on color {
                enabled: Style.motion.enabled

                ColorAnimation {
                    duration: Style.durFast
                }
            }
        }

        StyledIcon {
            anchors.centerIn: parent
            glyph: "󰅂"
            tone: root.typing ? "onAccent" : "dim"
            size: Style.font.sizeL
        }

        MouseArea {
            id: sendArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: root.typing && !LockState.checking
            cursorShape: Qt.PointingHandCursor
            onClicked: root.submitted()
        }
    }

    // 真正接键盘的东西。这里确实是个裸 TextInput，不是 ui/StyledInput ——
    // 它完全不可见，没有任何需要跟主题的地方，而 StyledInput 也不支持
    // NoEcho。界面要画的那串点读的是 LockState.typed，不是这里的 text。
    TextInput {
        id: field

        anchors.fill: parent
        opacity: 0
        echoMode: TextInput.NoEcho
        activeFocusOnPress: true
        onTextChanged: LockState.typed = field.text.length
        enabled: !LockState.checking && !LockState.unlocking

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                LockState.submit(field.text);
                field.text = "";
                event.accepted = true;
            }
        }
    }

    // 提交之后把输入框清掉：PAM 在验的时候继续打字是没有意义的，
    // 验完了也不该留着上一次的内容。
    onSubmitted: {
        LockState.submit(field.text);
        field.text = "";
    }

    // 验失败之后光标要还在输入框里，否则得先点一下才能重打
    Connections {
        target: LockState

        function onFailedAttempt() {
            field.text = "";
            field.forceActiveFocus();
        }

        // 屏幕熄着的时候按键照样送得进来 —— 那一下是用来把屏幕叫醒的，
        // 不是密码的一部分。亮回来就从头开始打。
        function onWoke() {
            field.text = "";
            field.forceActiveFocus();
        }
    }
}
