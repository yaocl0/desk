import Quickshell
import "root:/layouts/parts"

// 只有一条顶栏。贴边还是悬浮由 space.barMargin 决定（主题的事，不是布局的事）。
Scope {
    id: root

    required property var screen

    TopBar {
        barScreen: root.screen
    }
}
