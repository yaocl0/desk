#!/usr/bin/env bash
# desk 的锁屏入口 —— hyprland.lua 的快捷键 / 自启动和 hypridle 的 lock_cmd 都指向它。
#
# 为什么不直接写 `qs ... ipc call lock lock`：
# 那条命令在 desk 没跑 / IPC 不通的时候会静默失败，而它失败的方式是**屏幕不锁**。
# 锁屏这件事上，「失败」必须是「退回一个能用的锁」，不能是「不锁」。
# 所以这里兜了一层：够不着 desk 就 exec hyprlock（配置仍在 ~/.config/hypr/hyprlock.conf）。
#
# 原来的三处调用点已备份在 ~/.config/hypr/backup-desk-lock-*/。
# 想整个退回去：把那三处改回 hyprlock 即可，这个脚本和 desk 都不用动。

DESK=/home/yao/workspace/desk

ipc() { qs -p "$DESK" ipc call lock "$1" 2>/dev/null; }

# --boot：开机自启动用。那会儿桌面还是空的（壁纸都没上来），拍屏当锁屏背景
# 只会得到一片死灰 —— 走不拍屏的入口，直接用模糊壁纸。
# 只有 hyprland.lua 的 autostart 该带这个参数。
LOCKFN=lock
[ "$1" = "--boot" ] && LOCKFN=lockBoot

# 等 desk 可达，最多约 4 秒。登录那一下 shell 往往还没起来，
# 不等的话每次开机都会退回 hyprlock。shell 已经在跑时这个循环第一次就过。
reachable=0
for _ in $(seq 40); do
    if [ -n "$(ipc isLocked)" ]; then
        reachable=1
        break
    fi
    sleep 0.1
done

if [ "$reachable" = 1 ]; then
    # 已经锁着就什么都不做 —— 等价于原来的 `pidof hyprlock || hyprlock`，
    # 避免 hypridle 多次触发时重复锁。
    [ "$(ipc isLocked)" = "true" ] && exit 0

    ipc "$LOCKFN" >/dev/null

    # 等锁屏真的挂上再返回。休眠前那条路（before_sleep_cmd）要的就是
    # 「这条命令返回时屏幕已经锁了」，提前返回就可能带着解锁的屏幕睡过去。
    for _ in $(seq 30); do
        [ "$(ipc isLocked)" = "true" ] && exit 0
        sleep 0.1
    done
    exit 0
fi

# 够不着 desk：退回 hyprlock
pidof hyprlock >/dev/null && exit 0
exec hyprlock
