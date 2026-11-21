import "root:/core"
import "root:/ui"

// 栏最左那颗发行版徽标，点一下开 / 关启动器。
//
// 分工和栏上别的组件一样：画什么全在主题的 logo 段（字形 / 图标 / 色调 /
// 大小），这里只认「点了之后发生什么」。
//
// 走 core/LauncherState 而不是直接去碰某个面板：list 和 ring 是两套平行
// 实现，共用这一个开关 —— 于是换启动器形态、快捷键、IPC 都不用管这个按钮。
IconButton {
    id: root

    glyph: Style.logoGlyph
    source: Style.logoIcon
    iconSize: Style.logoSize
    hPadding: Style.logoPadding
    tone: Style.logoTone
    moduleKey: "logo"

    // 开着的时候亮起来，和右边那颗齿轮是一个意思。
    // 注意环形启动器盖满整屏（连栏一起压暗），这时看不见也不要紧 ——
    // 列表启动器只盖到栏下沿，那一档才是真用得上的反馈。
    active: LauncherState.open
    onClicked: LauncherState.toggle()
}
