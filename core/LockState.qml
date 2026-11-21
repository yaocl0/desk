pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// 锁屏的状态 + 认证。和 core/LauncherState 一个道理：core/ 里放一份谁都能
// 引用的开关，overlays/ 负责把它画出来，两边不用互相认识。
//
// ⚠️ 现在这一版**锁不住**。真正的锁要 Quickshell.Wayland 的 WlSessionLock，
// 它向合成器声明「这块屏归我了」—— 一旦装上，这个进程崩了 / 被 kill 了，
// 合成器会**保持锁定**，只能切 TTY 用 loginctl 解。所以先做成一个普通的
// Overlay 窗口：长得一样、认证是真的，但 Esc 随时能退出去。
// 确认手感和认证都没问题之后再接 WlSessionLock，那是单独一步。
//
// PAM 用的是 login 这个 service。注意 Arch 的 /etc/pam.d/login 里有
// pam_faillock：连续输错会触发账户锁定（默认 3 次、锁 10 分钟），
// 调试的时候别拿真密码乱试。
Singleton {
    id: root

    // 锁屏界面是不是该显示
    property bool wanted: false

    // 认证通过、正在退出。单独一个状态是为了让界面能放一段「开锁」动画，
    // 而不是「啪」地消失。
    property bool unlocking: false

    // 输入框里有几个字符。只记长度不记内容 —— 界面要画的是「打了几下」，
    // 没有任何理由让它看到密码本身。
    property int typed: 0

    property bool failed: false
    property string message: ""
    readonly property bool checking: pam.active

    // 密码只在 submit() 到 PAM 应答之间的这一瞬存在，应答完立刻清掉。
    // 不暴露成 readonly property 给界面读。
    property string secret: ""

    signal failedAttempt

    // 屏幕亮回来了，把熄屏期间打进来的东西丢掉。由 wake() 发，界面接。
    signal woke

    // ── 锁屏背景：锁的那一刻抓一张屏 ──────────────────────
    //
    // 为什么不用合成器模糊（layerrule = blur）：那条规则只认 layer surface，
    // 而真锁屏用的 ext-session-lock 根本不是 layer；更要命的是锁上之后
    // 合成器把所有窗口都藏了，那时已经没有「当前窗口」可糊。
    // 所以只能在锁上之前把画面抓下来 —— hyprlock 的 `path = screenshot` 也是这么做的。
    //
    // 放 $XDG_RUNTIME_DIR：tmpfs、0700、注销即消失。它是一张锁屏前一刻的
    // 全屏截图，可能带着任何正开着的东西，所以解锁后立刻删，不留到下一次。
    readonly property string shotDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/desk-lock`

    function shotFor(name: string): string {
        return `${root.shotDir}/${name}.png`;
    }

    // 拍完才显示。顺序反过来的话截图里就会有锁屏自己，叠成套娃。
    // 代价是从按下快捷键到画面出现有一两百毫秒 —— 这段时间屏幕还是解锁的，
    // hyprlock 同样有这个窗口期，是这条路线固有的。
    function lock(capture_) {
        if (capture_ === undefined)
            capture_ = true;
        if (root.wanted)
            return;
        root.failed = false;
        root.message = "";
        root.typed = 0;
        root.unlocking = false;
        root.captured = false;

        // 背景是星空就根本不拍：那张图用不上，而它可能带着任何正开着的
        // 内容，没理由为一个不显示它的界面留一份在盘上。顺带省掉那一两百
        // 毫秒的延迟 —— 这条路可以立刻锁上。
        if (Config.lockBackground === "stars") {
            root.wanted = true;
            return;
        }

        // 不拍屏那条路：直接走 LockBackdrop 的壁纸兜底。
        //
        // 开机时 hyprland.lua 的自启动会很早调过来，那会儿桌面还是空的，
        // 拍到的是一块没铺壁纸的黑底，糊完是一片死灰。这种时候「模糊壁纸」
        // 本来就是对的背景。
        //
        // 由调用方说了算，不自己猜：这是唯一一个「现在没有桌面可拍」的
        // 调用点，它自己最清楚。试过让 shell 去判断壁纸加载完没有 ——
        // 那个信号依赖壁纸窗口真的渲染过，被全屏窗口遮住时就不成立，
        // 而它失败的表现是「从此不再拍截图」，静默降级，更难发现。
        if (!capture_) {
            root.wanted = true;
            return;
        }

        capture.running = true;
    }

    // 这一次锁屏到底拍没拍。LockBackdrop 据此决定是去读截图还是直接走壁纸，
    // 省掉「读一个不存在的文件」那条必然失败的路和它在日志里留的告警。
    property bool captured: false

    Process {
        id: capture

        // 逐个显示器拍，不是 grim 默认的「所有输出拼成一张」——
        // 多屏下每块屏的锁屏要贴自己那一块，拼图还得自己算裁剪。
        //
        // 不用 jq 解析 hyprctl -j：少一个依赖。-o 后面那个名字就是
        // Quickshell 里 screen.name 的同一个值。
        // -s 0.25：直接让 grim 出 1/4 分辨率。
        //
        // 背景反正要糊，全分辨率的信息一点都用不上，但代价很实在：
        // 1920×1080 的 PNG 有 1.2MB，Qt 异步解码要 ~100ms —— 锁屏已经立起来了
        // 而图还没好，于是先闪一下纯色底再弹出模糊背景。
        // 出 480×270 之后文件小一个数量级，解码几毫秒，可以同步加载，
        // 第一帧就是对的。顺带编码也快，锁屏前的等待跟着短。
        command: ["sh", "-c", `mkdir -p "$1" && rm -f "$1"/*.png
            hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}' | while read -r m; do
                grim -s 0.25 -o "$m" "$1/$m.png" 2>/dev/null || true
            done`, "sh", root.shotDir]

        // 不看退出码：grim 挂了也必须把锁屏放出来，
        // 否则「截图失败」会变成「锁不上」—— 那是最糟的失败方式。
        // 背景拿不到图时 LockBackdrop 会退回壁纸。
        onExited: {
            root.captured = true;
            root.wanted = true;
        }
    }

    Process {
        id: sweep

        command: ["sh", "-c", 'rm -rf "$1"', "sh", root.shotDir]
    }

    function submit(password: string) {
        if (!root.wanted || root.unlocking || pam.active || password === "")
            return;
        root.failed = false;
        root.message = "";
        root.secret = password;
        pam.start();
    }

    // ── 熄屏期间打的字不算数 ──────────────────────────────
    //
    // DPMS 把屏幕关掉之后，合成器照样把按键送进锁屏 —— 「随便按一下把屏幕
    // 叫醒」的那一下会原样落进密码框。屏幕是黑的，人看不见，于是醒来第一眼
    // 就是一个已经脏了的输入框，接着打完按回车，必然是「密码不对」。
    //
    // hypridle 的 on-resume 在把屏幕点亮的同时调这里（挂法见 hypr/desk.conf
    // 末尾那条），把这一段清掉。顺序是稳的：按键由合成器直接送到，几乎没有
    // 延迟；这条 IPC 要先 fork 一个进程再连 socket，晚几十毫秒。所以清掉的
    // 正好是「亮之前打的」，亮之后打的照常进去。
    //
    // 反过来的那种做法 —— 熄屏时立一个标志、醒来前一律吞掉按键 —— 效果一样，
    // 但多一个会卡住的状态：标志立起来之后那条「清掉」的通知没到（desk 重启过、
    // hypridle 没在跑），键盘就彻底打不进字了。锁屏上这个方向不能反，
    // 所以宁可选这种「没人叫我就什么都不做」的：不挂钩子 = 退回现在的样子。
    function wake() {
        if (!root.wanted || root.unlocking || pam.active)
            return;
        root.failed = false;
        root.message = "";
        root.typed = 0;
        root.woke();
    }

    // 认证通过之后由界面在开锁动画放完时调用
    function finish() {
        root.unlocking = false;
        root.typed = 0;
        root.wanted = false;
        sweep.running = true;
    }

    // 预览专用的逃生口：不认证直接退出。接了 WlSessionLock 之后这个函数
    // 必须删掉 —— 真锁屏上留一个「不用密码就能退」的入口就不是锁屏了。
    function abort() {
        root.secret = "";
        root.failed = false;
        root.message = "";
        root.typed = 0;
        root.unlocking = false;
        root.wanted = false;
        sweep.running = true;
    }

    PamContext {
        id: pam

        config: "login"

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root.secret);
                root.secret = "";
            }
        }

        onCompleted: result => {
            root.secret = "";
            if (result === PamResult.Success) {
                root.unlocking = true;
                return;
            }
            root.failed = true;
            root.message = result === PamResult.MaxTries ? "叩门太急，天门已闭" : result === PamResult.Error ? "天机紊乱，稍候再叩" : "道行尚浅，莫入此门";
            root.failedAttempt();
        }

        onError: {
            root.secret = "";
            root.failed = true;
            root.message = "天机紊乱，稍候再叩";
            root.failedAttempt();
        }
    }
}
