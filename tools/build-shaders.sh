#!/usr/bin/env bash
# Qt6 的 ShaderEffect 不吃 GLSL 源码，只吃 qsb 预编译出来的 .qsb。
# 改完 ui/shaders/*.frag 必须跑这个，热重载不会自动编译。
set -euo pipefail
cd "$(dirname "$0")/.."

QSB=${QSB:-/usr/lib/qt6/bin/qsb}
[ -x "$QSB" ] || QSB=$(command -v qsb) || {
    echo "找不到 qsb。安装: sudo pacman -S qt6-shadertools" >&2
    exit 1
}

shopt -s nullglob
found=0
for f in ui/shaders/*.frag ui/shaders/*.vert; do
    found=1
    "$QSB" --qt6 -o "$f.qsb" "$f"
    printf '  %s -> %s\n' "$f" "$f.qsb"
done

[ "$found" = 1 ] || {
    echo "ui/shaders/ 下没有着色器源文件" >&2
    exit 1
}
printf '\033[32m着色器编译完成\033[0m\n'
