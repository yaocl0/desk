#!/usr/bin/env bash
# 守住分层：modules/ 和 layouts/ 不得出现字面视觉值，
# 所有颜色 / 字号 / 圆角 / 间距必须走 core/Style 的 token。
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { printf '\n\033[31m%s\033[0m\n' "$1"; shift; printf '%s\n' "$@"; fail=1; }

# 1. hex 色值
if hits=$(grep -rnE '#[0-9a-fA-F]{3,8}\b' modules layouts 2>/dev/null); then
    report "字面 hex 色值（应改用 Style.color.*）:" "$hits"
fi

# 2. 字面字号 / 圆角 / 边框宽度
if hits=$(grep -rnE '(font\.pixelSize|font\.pointSize|radius|border\.width)\s*:\s*[0-9]' modules layouts 2>/dev/null); then
    report "字面字号/圆角/边框（应改用 Style.font.* / Style.shape.*）:" "$hits"
fi

# 3. 绕过 ui/ 直接用裸 Rectangle / Text
if hits=$(grep -rnE '^\s*(Rectangle|Text)\s*\{' modules layouts 2>/dev/null); then
    report "裸 Rectangle/Text（应改用 ui/Surface、ui/StyledText）:" "$hits"
fi

# 4. services/ 是叶子：只读外部系统状态，连 core/ 都不许依赖。
#    （「当前壁纸」这类自有配置属于 core/，不是 services/。）
if hits=$(grep -rnE 'import "root:/(ui|modules|layouts|overlays|core)"' services 2>/dev/null); then
    report "services/ 不是叶子了，它应该只读外部系统状态:" "$hits"
fi

# 5. core/ 不得反向依赖视觉层
if hits=$(grep -rnE 'import "root:/(ui|modules|layouts|overlays)"' core 2>/dev/null); then
    report "core/ 反向依赖了视觉层:" "$hits"
fi

if [ $fail -eq 0 ]; then
    printf '\033[32m分层检查通过\033[0m\n'
fi
exit $fail
