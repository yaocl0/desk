pragma Singleton

import Quickshell

// 应用目录 + 模糊匹配。和别的 service 一样是叶子：只读外部系统状态
// （这里是 XDG 的 .desktop 条目），不认识 core/，更不认识视觉层。
//
// 使用频率是 core/Config 的东西，所以不在这里读 —— 由调用方把那张表
// 当参数喂进 search()，和 WeatherCard 用 Binding 把城市喂给 Weather 服务同理。
Singleton {
    id: root

    // 一次按键要给几百个条目打分，所以小写串在这里先缓存好，
    // 不在打分函数里反复 toLowerCase。
    readonly property var list: {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay)
                continue;
            const name = e.name ?? "";
            const generic = e.genericName ?? "";
            const comment = e.comment ?? "";
            // keywords / categories 在 Quickshell 里可能是字符串也可能是数组，
            // 两种都接住，省得换个版本就全都匹配不上
            const kw = root.flatten(e.keywords) + " " + root.flatten(e.categories);
            out.push({
                kind: "app",
                entry: e,
                id: e.id,
                icon: e.icon ?? "",
                title: name,
                subtitle: generic || comment,
                lname: name.toLowerCase(),
                lgeneric: generic.toLowerCase(),
                lkeywords: kw.toLowerCase(),
                lcomment: comment.toLowerCase(),
                lexec: (e.execString ?? "").toLowerCase()
            });
        }
        return out;
    }

    function flatten(v: var): string {
        return Array.isArray(v) ? v.join(" ") : (v ?? "");
    }

    // ── 打分 ────────────────────────────────────────────────
    // 分数只用来排序，绝对值没有意义。分档的用意是「强匹配永远压过弱匹配」：
    // 输 "fi" 时 Firefox（名字前缀）必须排在「文件管理器」（comment 里有 fi）前面，
    // 而不是让两者的小数点后几位去较劲。
    function fieldScore(q: string, text: string): int {
        if (!text)
            return -1;
        if (text === q)
            return 1000;
        if (text.startsWith(q))
            return 850 - Math.min(100, text.length - q.length);

        // 词首：「code」能匹配到「Visual Studio Code」
        const words = text.split(/[\s\-_.]+/);
        for (const w of words) {
            if (w.startsWith(q))
                return 700 - Math.min(100, text.length - q.length);
        }

        // 首字母缩写：「vsc」→ Visual Studio Code
        if (words.length > 1) {
            const initials = words.map(w => w.charAt(0)).join("");
            if (initials.startsWith(q))
                return 650;
        }

        const idx = text.indexOf(q);
        if (idx >= 0)
            return 500 - Math.min(100, idx * 4);

        // 子序列：「frfx」→ firefox。连着的字符加分，跳得越远越不像。
        let ti = 0;
        let hits = 0;
        let run = 0;
        let bonus = 0;
        for (const ch of q) {
            const found = text.indexOf(ch, ti);
            if (found < 0)
                return -1;
            run = found === ti ? run + 1 : 0;
            bonus += run * 4;
            ti = found + 1;
            hits++;
        }
        return hits === q.length ? 200 + bonus - Math.min(80, ti - q.length) : -1;
    }

    // 字段权重：名字 > 通用名 > 关键词/分类 > 说明 > 命令行。
    // 取最大值而不是累加 —— 累加的话，一个说明写得长的应用会靠「哪儿都沾一点」
    // 压过名字正好对上的那个。
    function score(q: string, item: var): int {
        const fields = [[item.lname, 1.0], [item.lgeneric, 0.72], [item.lkeywords, 0.55], [item.lcomment, 0.4], [item.lexec, 0.34]];
        let best = -1;
        for (const [text, weight] of fields) {
            const s = root.fieldScore(q, text);
            if (s >= 0)
                best = Math.max(best, Math.round(s * weight));
        }
        return best;
    }

    // usage: { desktopId: 次数 }。空 query 时就是纯频率榜，
    // 有 query 时只当同分的断连器 —— 常用的那个排前面，但不至于压过更对的匹配。
    function search(query: string, usage: var, limit: int): var {
        const u = usage ?? ({});
        const q = (query ?? "").trim().toLowerCase();

        if (q === "") {
            return root.list.slice().sort((a, b) => (u[b.id] ?? 0) - (u[a.id] ?? 0) || a.title.localeCompare(b.title)).slice(0, limit);
        }

        const hits = [];
        for (const item of root.list) {
            const s = root.score(q, item);
            if (s >= 0)
                hits.push({
                    item: item,
                    s: s
                });
        }
        hits.sort((a, b) => b.s - a.s || (u[b.item.id] ?? 0) - (u[a.item.id] ?? 0) || a.item.title.localeCompare(b.item.title));
        return hits.slice(0, limit).map(h => h.item);
    }
}
