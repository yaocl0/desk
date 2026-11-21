-- desk —— Hyprland Lua 配置片段
--
-- Hyprland 0.5x 的 Lua 配置（hyprctl systeminfo 里 configProvider: lua）用这个，
-- 同目录的 desk.conf 是给老式 .conf 配置用的，两者二选一。
--
-- 在 ~/.config/hypr/hyprland.lua 里加一行：
--
--   dofile("/home/yao/workspace/desk/hypr/desk.lua")
--
-- 用 dofile 而不是 require：require 只在 ~/.config/hypr/ 下按模块名找，
-- 够不到仓库里的文件。
--
-- 另外还要做两件事（这个文件管不了）：
--   1. 注释掉 hl.exec_cmd("waybar")        否则两条栏叠在一起
--   2. systemctl --user mask dunst.service
--      dunst 是 D-Bus 按需激活的，不 mask 的话它会抢走
--      org.freedesktop.Notifications，desk 的通知就收不到

-- ── 模糊 ──────────────────────────────────────────────────
-- 装一次就不用再碰：之后切不切玻璃主题只由 themes/*.json 的
-- effect.opacity / effect.barOpacity 决定（为 1.0 时模糊不可见）。
--
-- match 是正则，必须写 ^desk$ 精确匹配 ——
-- 写成 desk 会连 desk-wallpaper（壁纸层）一起糊掉。
hl.layer_rule({
    name         = "desk-blur",
    match        = "^desk$",
    blur         = true,
    ignore_alpha = 0.1,
    -- popup（托盘菜单、壁纸/样式面板）是 layer surface 的 xdg_popup，
    -- 默认不吃上面那条 blur，必须单独开这个才会跟着糊。
    blur_popups  = true,
})

-- ── 可选：加强模糊（玻璃效果）────────────────────────────
-- 注意 decoration.blur 是**全局**的，会影响所有开了模糊的窗口，不只是 desk。
-- Hyprland 的默认 size=3 / passes=1 太弱，glass 主题的「液态玻璃」几乎看不出来。
--
-- passes 越高越糊也越吃 GPU。集显上卡顿的话先把 passes 降到 2。
-- 不想要就把下面整段注释掉，栏会退回半透明但不模糊。
hl.config({
    decoration = {
        blur = {
            size     = 10,    -- 默认 3
            passes   = 3,     -- 默认 1
            vibrancy = 0.45,  -- 默认 0.1696，提高背景饱和度，macOS 的关键
        },
    },
})

-- ── 自启动 ────────────────────────────────────────────────
-- -n：已有同一份配置在跑就直接退出，避免起两份。
-- 路径写死：exec_cmd 不保证展开 ~。
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -n -p /home/yao/workspace/desk")
end)
