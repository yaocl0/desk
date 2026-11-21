#!/usr/bin/env bash
# 从壁纸生成 themes/material.json 并切过去。
#
#   ./tools/wallpaper-theme.sh ~/Pictures/wall.jpg          # 暗色
#   ./tools/wallpaper-theme.sh ~/Pictures/wall.jpg light    # 亮色
#
#   --theme-only  只重算配色，不设置壁纸也不切主题。
#                 core/Matugen.qml 换壁纸时就是这么调的 —— 如果照常走
#                 "设壁纸" 那条路，会把自己再触发一遍，变成死循环。
#
# 依赖：sudo pacman -S matugen
# 只写仓库内的文件，不碰系统配置。
set -euo pipefail
cd "$(dirname "$0")/.."

themeOnly=0
if [ "${1:-}" = "--theme-only" ]; then
    themeOnly=1
    shift
fi

img="${1:-}"
mode="${2:-dark}"
# matugen 4.x：一张图能抽出多个候选主色时，非交互环境必须显式指定偏好，
# 否则直接报 "Multiple source colors found"。saturation = 取最鲜艳的那个。
prefer="${PREFER:-saturation}"
# tonal-spot 是 M3 的默认方案：表面近中性、只有 accent 鲜艳，整体色调统一。
# 想要色相铺得更开（彩色药丸风格）可以 SCHEME=scheme-expressive 覆盖。
scheme="${SCHEME:-scheme-tonal-spot}"

if [ -z "$img" ]; then
    echo "用法: $0 <壁纸路径> [dark|light]" >&2
    echo "可选环境变量: PREFER=saturation|darkness|lightness|value|less-saturation" >&2
    echo "              SCHEME=scheme-tonal-spot|scheme-vibrant|scheme-expressive|..." >&2
    exit 1
fi
if [ ! -f "$img" ]; then
    echo "找不到文件: $img" >&2
    exit 1
fi
if ! command -v matugen >/dev/null 2>&1; then
    echo "缺少 matugen。安装: sudo pacman -S matugen" >&2
    exit 1
fi

out=themes/material.json
backup=""
if [ -f "$out" ]; then
    backup=$(mktemp)
    cp "$out" "$backup"
fi

cfg=$(mktemp --suffix=.toml)
trap 'rm -f "$cfg"' EXIT
sed "s|@ROOT@|$PWD|g" tools/matugen/config.toml > "$cfg"

matugen --config "$cfg" --mode "$mode" \
    --type "$scheme" --prefer "$prefer" image "$img"

# 模板填错会生成非法 JSON —— 宁可回滚也不要让 shell 退回灰色默认主题
if ! python3 -c "import json,sys; json.load(open('$out'))" 2>/dev/null; then
    echo "生成的 $out 不是合法 JSON，已回滚" >&2
    [ -n "$backup" ] && cp "$backup" "$out"
    exit 1
fi
[ -n "$backup" ] && rm -f "$backup"

printf '\033[32m%s 已生成\033[0m（mode=%s, 壁纸=%s）\n' "$out" "$mode" "$img"

if [ "$themeOnly" = 1 ]; then
    exit 0
fi

# 闭环：壁纸本身也交给 desk 显示（overlays/WallpaperLayer.qml）
abs=$(readlink -f "$img")

if qs -p . ipc call wallpaper set "$abs" >/dev/null 2>&1 &&
    qs -p . ipc call style theme material >/dev/null 2>&1; then
    echo "壁纸已设置，并切换到 material 主题"
else
    echo "quickshell 未运行。启动后执行："
    echo "  qs -p . ipc call wallpaper set '$abs'"
    echo "  qs -p . ipc call style theme material"
fi
