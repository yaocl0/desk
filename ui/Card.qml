import QtQuick
import QtQuick.Layouts
import "root:/core"

// 桌面卡片。和 StyledPopup 同一套观感（level 2 的面板：圆角 / 透明度 /
// 描边 / 阴影全跟主题），区别是它不是弹层 —— 没有锚点、没有焦点，
// 直接摆在桌面组件层上。
//
// 有这一层，modules/ 里的桌面组件就只管往里塞内容，
// 不用碰 padding、圆角、透明度 —— 换主题时卡片的「壳」自己会变。
Surface {
    id: root

    default property alias content: body.data

    // 外部指定的宽度；0 = 按内容自然撑开。桌面层拖右下角把手时改的就是它。
    property int fixedWidth: 0

    // 组件要按宽度重排时读这个（日历的 7 列、相册缩略图都是这么来的）。
    // 故意不从 implicitWidth 推 —— 那样「宽度→格子→内容宽→宽度」会成环。
    readonly property int pad: Style.space.m
    readonly property int contentWidth: (root.fixedWidth > 0 ? root.fixedWidth : Style.space.cardWidth) - root.pad * 2

    level: 2
    radius: Style.shape.radiusL
    implicitWidth: root.fixedWidth > 0 ? root.fixedWidth : body.implicitWidth + root.pad * 2
    implicitHeight: body.implicitHeight + root.pad * 2

    ColumnLayout {
        id: body

        anchors.fill: parent
        anchors.margins: root.pad
        spacing: Style.space.s
    }
}
