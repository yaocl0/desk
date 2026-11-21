pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// 当前主题的 token。ui/ 是唯一读它的层。
Singleton {
    id: root

    // ── token 分组 ──────────────────────────────────────────
    readonly property var color: root.tokens.color
    readonly property var module: root.tokens.module
    readonly property var shape: root.tokens.shape
    readonly property var space: root.tokens.space
    readonly property var font: root.tokens.font
    readonly property var launcher: root.tokens.launcher
    readonly property var motion: root.tokens.motion
    readonly property var effect: root.tokens.effect

    // ── 派生值 ──────────────────────────────────────────────
    // motion.enabled 为 false 时时长归零，组件里不用写 if
    // 全部用可选链 + 兜底：QML 单例是惰性初始化的，Defaults.tokens 在首次
    // 求值时可能还没准备好，tokens 会是空对象。不兜底的话这些派生值全变
    // undefined，日志里刷一片 "Unable to assign [undefined]"。
    readonly property int durFast: root.motion?.enabled ? root.motion.fast : 0
    readonly property int durNormal: root.motion?.enabled ? root.motion.normal : 0

    // 壁纸转场时长。故意不被 motion.enabled 门控 —— 那个开关管的是界面动效，
    // 壁纸转场是内容本身的过渡，极简主题下也该有。设 0 则瞬切。
    readonly property int wallpaperDuration: root.motion?.wallpaper ?? 2000

    readonly property int easing: ({
            linear: Easing.Linear,
            outQuad: Easing.OutQuad,
            outCubic: Easing.OutCubic,
            outExpo: Easing.OutExpo,
            outBack: Easing.OutBack,
            inOutCubic: Easing.InOutCubic
        })[root.motion?.easing] ?? Easing.OutCubic

    // 字体回退链。token 里 font.family 可以写成字符串或数组，
    // 数组时取第一个「本机确实装了的」—— 主题就能首选 Inter / SF Pro，
    // 没装自动落到 Noto Sans，而不是直接掉到系统默认。
    //
    // 注意不能用 font.families：那是 C++ QFont 的 API，
    // QML 的 font 值类型没有这个属性（会报 non-existent property）。
    // 缺字形（比如 Nerd Font 图标）仍由 Qt/fontconfig 自己逐字回退。
    readonly property string fontFamily: {
        const f = root.font?.family;
        const list = Array.isArray(f) ? f : [f ?? ""];
        const avail = Qt.fontFamilies();
        for (const name of list) {
            if (name && avail.indexOf(name) !== -1)
                return name;
        }
        return list[list.length - 1] || "sans-serif";
    }

    // 栏本体圆角，-1 表示跟随 radiusL
    readonly property int barRadius: {
        const r = root.shape?.barRadius ?? -1;
        return r < 0 ? (root.shape?.radiusL ?? 0) : r;
    }

    // 栏底可以比弹层更透明（"几乎只剩壁纸"的风格）
    readonly property real barOpacity: root.effect?.barOpacity ?? root.effect?.opacity ?? 1.0

    // 药丸上的文字色。主题没写 module 段时继承 onSurface —— 这样不关心
    // 这套配色的主题（gruvbox / glass / material）视觉完全不变。
    readonly property color moduleOn: {
        const c = root.module?.on;
        return (c === undefined || c === "") ? (root.color?.onSurface ?? "#d0d0d0") : c;
    }

    // 悬停底色上的文字色。主题没写就是 onSurface —— 深色 hover 的主题
    // （gruvbox / glass / material）完全不用管这个 token。
    readonly property color hoverOn: {
        const c = root.color?.onHover;
        return (c === undefined || c === "") ? (root.color?.onSurface ?? "#d0d0d0") : c;
    }

    // 组件自己的药丸底色。主题没给就退回 surfaceAlt，
    // 所以不关心这套配色的主题完全不用写 module 段。
    function moduleColor(key: string): color {
        const c = root.module?.[key];
        return (c === undefined || c === "") ? (root.color?.surfaceAlt ?? "transparent") : c;
    }

    // JSON 里的颜色是字符串，乘上主题透明度后给 Rectangle.color
    function alpha(c, a: real): color {
        const col = Qt.color(c ?? "transparent");
        return Qt.rgba(col.r, col.g, col.b, col.a * a);
    }

    // ── 加载与合并 ──────────────────────────────────────────
    readonly property var tokens: root.merge(Defaults.tokens, root.override)

    readonly property var override: {
        let raw;
        try {
            // 绑定首次求值时 FileView 可能还没构造完，取值会抛
            raw = file.text();
        } catch (e) {
            return ({});
        }
        if (!raw)
            return ({});
        try {
            return JSON.parse(raw);
        } catch (e) {
            console.warn(`[Style] themes/${Config.theme}.json 解析失败，退回默认主题: ${e}`);
            return ({});
        }
    }

    // 只深合并一层分组（token 树就两层，够用）。
    // over 必须兜底成 {}：否则 tokens 会是 undefined，整棵 token 树连带
    // 所有派生值一起塌掉，日志里会刷一片 "Unable to assign [undefined]"。
    function merge(base, over): var {
        const o = over ?? {};
        const out = {};
        for (const group in base) {
            out[group] = Object.assign({}, base[group], o[group] ?? {});
        }
        return out;
    }

    FileView {
        id: file

        path: `${Quickshell.shellDir}/themes/${Config.theme}.json`
        watchChanges: true
        onFileChanged: reload()
    }
}
