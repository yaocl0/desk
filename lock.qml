//@ pragma UseQApplication

import QtQml
import Quickshell
import Quickshell.Io
import "root:/core"
import "root:/overlays"

// 锁屏的独立预览入口，和 ring.qml 同一个路子：
//
//   qs -p ~/workspace/desk/lock.qml
//
// 起来就是锁屏画面。Esc 退出，或者
//   qs -p ~/workspace/desk/lock.qml ipc call lock open / close
//
// ⚠️ 它锁不住任何东西 —— overlays/LockLayer 用的是普通 Overlay 窗口，
// 不是 WlSessionLock。拿它来验手感和 PAM，不要拿它当锁屏用。
//
// PAM 走的是 login 这个 service，认证是真的。Arch 的 /etc/pam.d/login 里有
// pam_faillock：连续输错会锁账户（默认 3 次、10 分钟），别拿它乱试密码。
Scope {
    QtObject {
        Component.onCompleted: {
            Quickshell.watchFiles = true;
            LockState.lock();
        }
    }

    IpcHandler {
        target: "lock"

        // 名字不能叫 show：qs 的 CLI 里 `ipc show` 本身是个子命令，
        // `ipc call lock show` 会被当成「列出所有 handler」，函数根本不执行，
        // 而且不报错 —— 只是打印一份清单。用 open / close，和启动器那套对齐。
        function open(): string {
            LockState.lock();
            return "lock -> 显示（预览，锁不住）";
        }

        // 模拟开机那一下：不拍屏，背景走模糊壁纸。
        // 对应 hypr/desk-lock.sh --boot 走的那条路。
        function openBoot(): string {
            LockState.lock(false);
            return "lock -> 显示（开机模式，不拍屏）";
        }

        function close(): string {
            LockState.abort();
            return "lock -> 退出";
        }

        // 模拟「屏幕亮回来」那一下。真机上这条是 hypridle 的 on-resume 调的，
        // 这里留一个同名的，手上就能验：打几个字 → wake → state 应该回到 0。
        function wake(): string {
            const had = LockState.typed;
            LockState.wake();
            return `lock -> 已清空输入（原有 ${had} 个字符）`;
        }

        function state(): string {
            return LockState.wanted ? `显示中，已输入 ${LockState.typed} 个字符` : "未显示";
        }
    }

    Variants {
        model: Quickshell.screens

        LockLayer {
            required property var modelData

            screen: modelData
        }
    }
}
