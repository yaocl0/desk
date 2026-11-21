pragma Singleton

import Quickshell
// ToplevelManager 在 Quickshell.Wayland 里，不在基础模块
import Quickshell.Wayland

// 已打开的窗口 + 「这个应用现在开着没有」的匹配。
//
// 和 services/Apps 的分工：那个管 XDG 的 .desktop 目录（装了什么），
// 这个管合成器里的 toplevel（现在开着什么）。两边都是叶子，
// 只读外部系统状态，不认识 core/，更不认识视觉层。
//
// 抽出来是因为两个启动器（modules/Launcher 的列表式、modules/RingLauncher
// 的环形）都要用。这套 appId ↔ .desktop 的启发式本来写在列表式里，
// 两份各存一份的话，哪天补了一种新写法只会补到其中一边。
Singleton {
    id: root

    // 打分复用 Apps 的那个，手感才一致（子序列、词首、首字母缩写都认）。
    // 返回的是中性数据，tag / glyph 这些由各自的界面自己贴。
    function search(query: string, limit: int): var {
        const q = (query ?? "").trim().toLowerCase();
        const hits = [];
        for (const t of ToplevelManager.toplevels.values) {
            const title = t.title || t.appId || "";
            const s = q === "" ? 0 : Apps.fieldScore(q, `${title} ${t.appId ?? ""}`.toLowerCase());
            if (s < 0)
                continue;
            hits.push({
                s: s,
                it: {
                    id: t.appId ?? "",
                    title: title,
                    subtitle: t.appId ?? "",
                    icon: DesktopEntries.heuristicLookup(t.appId)?.icon ?? "",
                    toplevel: t
                }
            });
        }
        hits.sort((a, b) => b.s - a.s);
        return hits.slice(0, limit).map(h => h.it);
    }

    // 只差一个前缀段的两个名字算同一个东西 —— 反向域名
    // （org.mozilla.firefox ↔ firefox）或自定义 class
    // （kitty --class floating-kitty）。按分隔符切一刀比尾段，
    // 不是裸 endsWith：否则 "mykitty" 也会被当成 kitty。
    function tailMatch(long: string, short: string): bool {
        if (short === "" || long.length <= short.length || !long.endsWith(short))
            return false;
        return "-_.".includes(long.charAt(long.length - short.length - 1));
    }

    // 这个应用现在有没有开着的窗口。三种写法都见过，所以挨个试：
    //   1. appId 就等于 .desktop 的 id，或等于条目里的 StartupWMClass
    //   2. 只差一个前缀段（见 tailMatch）
    //   3. 还不行就问 Quickshell 自己的启发式（Dock 用的就是它）
    function forApp(desktopId: string, startupClass: string): var {
        const id = (desktopId ?? "").replace(/\.desktop$/, "").toLowerCase();
        const cls = (startupClass ?? "").toLowerCase();
        for (const t of ToplevelManager.toplevels.values) {
            const app = (t.appId ?? "").toLowerCase();
            if (!app)
                continue;
            if (app === id || (cls !== "" && app === cls))
                return t;
            if (root.tailMatch(app, id) || root.tailMatch(id, app))
                return t;
            if (cls !== "" && (root.tailMatch(app, cls) || root.tailMatch(cls, app)))
                return t;
            if (DesktopEntries.heuristicLookup(t.appId)?.id === desktopId)
                return t;
        }
        return null;
    }
}
