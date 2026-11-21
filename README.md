# desk

基于 [Quickshell](https://quickshell.org) 的 Hyprland 桌面环境。

**样式与组件分离**：功能组件（workspaces、时钟、音量…）写一遍，在两条正交的轴上复用。

| 轴 | 是什么 | 在哪 | 怎么换 |
|---|---|---|---|
| **主题 theme** | 颜色 / 圆角 / 间距 / 字体 / 动效 / 透明度 | `themes/*.json` | 热重载，不重启 |
| **布局 layout** | 窗口数量与几何形态 | `layouts/*.qml` | 重载窗口 |

主题：`gruvbox`（极简单色）、`glass`（macOS 风）、`material`（壁纸取色）、`pastel`（彩色药丸条）
布局：`topbar`（顶栏）、`island`（灵动岛）、`dock`（顶栏 + 底部 Dock）

```bash
qs ipc call style list            # 看当前与可选
qs ipc call style theme glass     # 换主题
qs ipc call style layout dock     # 换布局
```
也可以直接编辑 `config.json`，存盘即生效——IPC 和手改文件汇到同一份 JSON，不存在两个事实来源。

## 安装

```bash
sudo pacman -S quickshell          # 0.3.2，官方 extra 仓库
quickshell -p ~/workspace/desk
```

在 `~/.config/hypr/hyprland.conf` 里 source 一次（含模糊规则与自启动）：

```
source = ~/workspace/desk/hypr/desk.conf
```

**模糊装一次就不用再碰**：所有窗口固定 `WlrLayershell.namespace: "desk"`，layerrule 常开；
玻璃与否只由主题的 `effect.opacity` 决定（为 `1.0` 时模糊不可见）。切主题不需要重配 Hyprland。

## 结构

```
shell.qml                入口 + 布局注册表
ring.qml                 环形启动器的独立预览入口（单独调环，不重载整个 shell）
lock.qml                 锁屏的独立预览入口（普通 Overlay，锁不住，只验手感和 PAM）
config.json              { "theme": "gruvbox", "layout": "topbar" }
hypr/desk.conf           Hyprland layerrule + 自启动（老式 .conf 配置）
hypr/desk.lua            同上，给 Lua 配置用（configProvider: lua），两者二选一
hypr/desk-lock.sh        锁屏入口：够不着 desk 就 exec hyprlock —— 失败不能是「不锁」
core/                    shell 自身的配置与样式解析
  Defaults.qml    [S]    内置 token 兜底树（中性灰，一眼看出主题没加载上）
  Config.qml      [S]    config.json 读写 + 热重载
  Style.qml       [S]    themes/<name>.json 合并到 Defaults，暴露 token
  Wallpaper.qml   [S]    当前壁纸路径 → URL，以及 wallpaperDir 下的候选列表
  WallpaperRotator.qml   定时换下一张（wallpaperInterval 分钟）
  Matugen.qml            换壁纸 → 重算 material 配色
  LauncherState.qml [S]  启动器开没开、开在哪块屏（IPC 与窗口层的交汇点）
  LockState.qml   [S]    锁屏状态 + PAM 认证（service 用 login，注意 pam_faillock）
  Ipc.qml                qs ipc call style / wallpaper / launcher …
themes/
  gruvbox.json           极简单色：直角、不透明、无动画
  glass.json             macOS 风：贴边方角菜单栏、比例字体、系统蓝 accent
  material.json          壁纸取色：matugen 按当前壁纸重算，见「壁纸取色」一节
  pastel.json            彩色药丸条：栏底全透（只剩药丸浮在壁纸上）、大号粗体、每组件一色
ui/                      样式原语 —— 唯一读 Style 的层
  IconButton.qml         栏里的图标按钮（可挂弹出面板）；字形或图标二选一，可放大
  StyledPopup.qml        通用弹出面板
  Card.qml               桌面卡片（和弹层同一套壳，但不是弹层）
  MenuRow.qml            菜单式可选行：对勾 + 可选图标 + 文字
  Tile.qml               设置首页的磁贴：图标 + 标题 + 当前值
  ResultRow.qml          列表里的一条结果：图标 + 标题 + 副标题 + 类型标签
  StyledInput.qml        单行输入框：主题色光标与选区，按键原样抛给使用方
  Slider.qml             横向滑条：图标 + 细轨圆钮 + 百分比，只发 moved 信号
  WallpaperView.qml      壁纸显示 + 像素扩散转场
  shaders/spread.frag    转场着色器（.qsb 由 tools/build-shaders.sh 编译）
  Dot.qml                纯装饰色块：圆点 / 色条 / 分隔线
  PetalShape.qml         参数化的花瓣 / 曲奇形状（Material 3 Expressive 的圆形变体）
  BlobShape.qml          一圈圆并成一坨，相邻的互相叠住
  Starfield.qml          星空 + 星云：一整块 Canvas，只在尺寸变化时重绘
  Surface.qml            圆角/描边/透明度/阴影/交互
  StyledText.qml         role（label|body|title）+ tone（normal|dim|accent|…）
  StyledIcon.qml         Nerd Font 字形 或 图标主题
  Pill.qml               Surface + 内边距 + 横向排列
  StyledMenu.qml         用 QML 重画的 DBusMenu（托盘右键菜单）
services/                系统数据，零视觉
  Audio.qml              Pipewire 默认输出
  Batt.qml               UPower 电池
  Net.qml                Quickshell.Networking（NetworkManager 后端）
  Sys.qml                CPU / 内存，Timer 轮询 /proc
  Apps.qml               .desktop 条目归一化 + 模糊打分（启动器用）
  Mpris.qml              MPRIS 播放器，多个时挑正在放的那个
  Weather.qml            Open-Meteo，城市名由使用方喂进来
  Backlight.qml          屏幕亮度：读 sysfs，写走 logind
  Notif.qml              通知服务端 + 历史（最多 50 条）
  Windows.qml            合成器里开着的 toplevel；和 Apps 分工：装了什么 vs 开着什么
modules/                 功能组件：只用 ui/ + services/，零字面视觉值
  LauncherButton.qml     栏最左的发行版徽标，点一下开 / 关启动器
  Workspaces.qml         动态工作区：有窗口 / 正在显示 / urgent 的才列出
  ActiveWindow.qml  Clock.qml
  Volume.qml  Battery.qml  Tray.qml
  Network.qml            信号格数 + SSID，showLabel 控制窄处是否只留图标
  Cpu.qml  Memory.qml    占用率 / 已用容量，超阈值切 alert 色位
  Dock.qml               打开中的窗口，按 appId 去重，点击唤起
  NotificationToast.qml  单条通知卡片
  SettingsPanel.qml      设置：首页磁贴 + 四个二级页，栏上唯一入口
  Launcher.qml           启动器面板：一个输入框，应用 / 窗口两种来源
  RingLauncher.qml       环形启动器面板：和上面共用 LauncherState，另一种形态
  RingItem.qml           环上的一格：只管「我是第几度、我画什么」
  WallpaperGrid.qml      壁纸缩略图网格（设置面板的一页）
  DesktopWidgets.qml [S] 桌面组件目录：key → 标签 / 图标 / Component
  CalendarCard.qml       日历
  WeatherCard.qml        实况 + 当日高低温 + 未来 4 小时
  MediaCard.qml          正在播放：封面 / 标题 / 上下首 / 进度
  AlbumCard.qml          壁纸相册：当前壁纸 + 下一张
  LockScene.qml          锁屏画面编排：什么东西摆在哪
  LockBackdrop.qml       锁屏背景：锁那一刻的截屏糊掉 + 暗罩（stars 时不截屏）
  LockClock.qml          锁屏时间，精度只到分钟 —— 可能挂一整夜
  LockInput.qml          密码条：随状态变形的锁 + 「打了几下」
layouts/
  parts/TopBar.qml       顶栏窗口部件，被 TopBarLayout 和 DockLayout 共用
  TopBarLayout.qml       只有一条顶栏
  IslandLayout.qml       左岛（工作区）+ 中岛（时钟，悬停展开）
  DockLayout.qml         顶栏 + 底部 Dock（一个布局 = 两个窗口）
overlays/                不随布局切换的全屏层
  WallpaperLayer.qml     壁纸（WlrLayer.Background）
  DesktopLayer.qml       桌面组件（WlrLayer.Bottom）
  NotificationLayer.qml  右上角通知栈
  LauncherLayer.qml      启动器窗口（Overlay 层 + 独占键盘 + 遮罩）
  RingLauncherLayer.qml  环形启动器窗口（与上面平行的实现）
  LockWindow.qml         真·锁屏：WlSessionLock，自己管所有屏幕，不进 Variants
  LockLayer.qml          锁屏预览层：普通 Overlay，Esc 能退，配 lock.qml 用
tools/
  check-style.sh         分层 lint
  wallpaper-theme.sh     从壁纸生成 material 主题
  matugen/               matugen 配置与 token 模板
```

`[S]` = QML Singleton。

## 壁纸取色（Material You）

```bash
sudo pacman -S matugen                                  # 装一次
./tools/wallpaper-theme.sh ~/Pictures/wall.jpg          # 暗色
./tools/wallpaper-theme.sh ~/Pictures/wall.jpg light    # 亮色
```

一条命令完成闭环：**设壁纸 → 提取配色 → 整个 shell 换色**。
壁纸由 `overlays/WallpaperLayer.qml` 自己显示（`WlrLayer.Background`），
不需要 swww / hyprpaper 之类的外部守护进程。

单独换壁纸不换主题：

```bash
qs ipc call wallpaper set /abs/path/to/image.png
qs ipc call wallpaper next     # 按文件名顺序推进一张，到底回绕
qs ipc call wallpaper clear
```

壁纸路径存在 `config.json` 里，和 theme / layout 同一份事实来源。
栏上的 `󰒓` 设置面板里有「壁纸」一页，缩略图点击即换。
壁纸目录由 `config.json` 的 `wallpaperDir` 指定，留空则是 `~/Pictures`。

### 定时轮换

栏上的 `󰒓` 设置 → 壁纸页，缩略图下面就是**自动切换壁纸**的开关和间隔档位
（10 分钟 / 30 分钟 / 1 小时 / 3 小时）。对应 `config.json`：

```json
{ "wallpaperDir": "", "wallpaperAuto": true, "wallpaperInterval": 30 }
```

**开关和间隔分开存**，不是用 `interval = 0` 表示关。否则关掉再打开就不知道
原来设了多久，只能猜一个默认值回填。`setWallpaperInterval` 因此把下限夹在 1。

存盘即生效，不用重启。顺序就是选择器里的顺序（按文件名），到底回绕。
手动换一张（选择器点击 / `ipc call wallpaper set`）会重新开始计时，
免得刚挑完的图几秒后就被顶掉。目录里不足两张时定时器根本不启动。

`autoTheme` 开着时每次轮换都会重跑一遍 matugen。配 `material` 主题的话
配色也跟着每轮变一次 —— 不想要就把 `autoTheme` 关掉，或者换个固定主题。

脚本只写仓库内文件，不碰系统配置。
`tools/matugen/material.json` 是 token 模板，颜色是 matugen 占位符、
尺寸/动效是手写的 M3 风格值 —— 想调圆角或栏高改模板，下次生成就带上。

生成的 JSON 会先做合法性校验，不合法自动回滚，避免 shell 退回灰色默认主题。
仓库里已有一份手搓的 M3 暗色基线，装 matugen 之前也能直接用。

matugen 4.x 的两个坑（脚本已处理）：

- **非交互环境必须给 `--prefer`**。一张图能抽出多个候选主色时，没有偏好且检测不到
  终端就直接报 `Multiple source colors found`。脚本默认 `saturation`，
  可以用 `PREFER=darkness ./tools/wallpaper-theme.sh ...` 覆盖。
  配色方案同理：`SCHEME=scheme-vibrant`。
- **配置里不接受相对路径**，否则报 `Failed to get the input and output paths from hashmap`。
  所以 `tools/matugen/config.toml` 用 `@ROOT@` 占位，脚本运行时替换成绝对路径写到临时文件。

## 设置面板

栏上只有 `󰒓` 一个入口，点开是 2×2 磁贴，每块显示当前值；点进去是二级页，
左上角 `‹` 返回。四页分别是**壁纸**（缩略图网格）、**主题**、**布局**、**桌面组件**。

```
󰒓 ─► [壁纸 3.png] [主题 glass]      ─► 壁纸    3 列缩略图，点击即换
     [布局 topbar] [桌面组件 4 个]   ─► 主题    gruvbox / glass / material / pastel
                                    ─► 布局    topbar / island / dock
                                    ─► 桌面组件 勾选要显示哪几张卡
```

四页不是 `StackLayout` 而是几块并排按 `visible` 切 —— `StackLayout` 的
`implicitHeight` 取所有页的最大值，弹层会永远按最高那页（壁纸网格）撑开，
翻到只有三行的「布局」页时下面空一大片。弹层宽度则固定成 `space.popupWidth`，
否则壁纸页和布局页宽度差一倍，翻页时忽胖忽瘦。

首页磁贴下面是**亮度滑条**（`ui/Slider`）。图标和百分比在轨道**外面**，
轨道本身只剩一条细线加一颗圆钮 —— 满值时不会变成一整块 accent 色压住整个面板。
圆钮位置按「可走行程 = 宽度 − 钮径」算，所以钮始终跟在指针底下，
而不是在两端差半个钮。百分比那一栏用 `TextMetrics` 按 "100%" 定宽，
否则 9% → 100% 时整条会左右抖。没有背光设备时整条不出现。

页面内容都是既有的原语：`ui/Tile`（磁贴）、`ui/MenuRow`（带对勾的可选行）、
`ui/Slider`（滑条）、`modules/WallpaperGrid`（缩略图网格）。
它们都只发信号，不认识 `Config`，也不认识任何 service。

### 亮度

`/sys/class/backlight/*/brightness` 是 root 独占的，所以**写走 logind 的
`SetBrightness`** —— 不要 root，也不用往系统里塞 udev 规则（装 brightnessctl 也行，
但那是多一个外部依赖，logind 本来就在跑）。读还是直接读 sysfs，
配 Timer 轮询，因为 sysfs 不发 inotify，Fn 键改了亮度只能靠轮询发现。

busctl 一次只留一个在途：拖动期间攒下的最新值在 `onExited` 里补发，
否则一路拖过去会 spawn 出几十个进程。拖动时先乐观更新 `value` 不等回读，
否则滑块跟不上手。只管内置屏，外接显示器要走 DDC/CI，是另一套东西。

## 桌面组件

壁纸之上、窗口之下的一层卡片（`WlrLayer.Bottom`）。栏上的 `󰒓` 面板里勾选即可增删，
**按住卡片上沿即可拖到屏幕任意位置**（鼠标移上去会变成抓手），右上角悬停出现 `×` 删除。

```json
{
    "desktopWidgets": [
        { "key": "weather",  "x": 69,  "y": 309, "w": 0 },
        { "key": "calendar", "x": 700, "y": 120, "w": 520 }
    ]
}
```

坐标相对「栏下面那块可用区域」的左上角。**每张卡都有自己的坐标，没有自动排列。**
老格式（纯字符串数组）读得进来，补位之后立刻写成新格式。

```bash
qs ipc call desktop list
qs ipc call desktop toggle weather
qs ipc call desktop move calendar 700 120
qs ipc call desktop width calendar 520     # 0 = 自然宽度
```

`ipc call desktop add` 这种拿不到坐标的入口，会先写 `x = -1`；桌面层看到就按
`desktopMargin + 序号 × space.l` 补一个错开的位置并**立刻写回**，所以
「没有坐标」只是个过场状态，不会留在 config 里。补位不看卡片尺寸，
因此没有「等它量出高度」那类竞态 —— 这一点踩过坑，见下。

### 曾经踩过的两个坑

**一、按量到的高度算位置，行不通。** 卡片是异步加载的，天气卡取到数据前只有
城市名那一行（实测 `56x49`），之后才长到 `240x176`。按没长大的高度铺开，
下一张就叠在它身上。加等待时间只是换个数字赌：从国内访问 open-meteo 要两次往返，
1.6 秒都不够。所以现在的补位**只看序号，不看尺寸**。

**二、中途试过「没坐标的卡挂进一个 `Column` 自动排」。** 高度问题是解决了，
但那样一部分卡挂在 `Column` 下、一部分挂在 `field` 下，`Repeater` 维持
delegate 兄弟顺序时会刷一片 `stackAfter` 警告，还得换成 `Instantiator` 绕开。
取消自动排列之后，所有卡又都是 `field` 的兄弟，`Repeater` 也就能用回来了。

### 改尺寸：内容重排，不是缩放

悬停时卡片右下角出现角标，横向拖它改**宽度**，宽度存在每项的 `w` 里
（`0` = 用卡片自己的自然宽度）。**高度不给拖** —— 内容重排之后高度是算出来的，
让用户拖只会拖出一片空白。

**下限就是卡片自己的自然宽度，只能往大拖。** 上限是 `cardWidth` 的 3 倍。
拖到底时存回的是 `0` 而不是某个具体数值 —— 这样「最小」始终由卡片自己定义，
换主题或内容变了也还贴着它的下限。

自然宽度**只能在卡片没被指定宽度时量**，而且要持续量：

```qml
readonly property real holderW: holder.implicitWidth
onHolderWChanged: if (slot.cw <= 0) slot.natW = slot.holderW
```

两个理由。一是**防止自己污染自己**：卡片越宽 → 天气的逐小时列数越多、实况块
放大倍数越大 → `implicitWidth` 跟着涨 → 「下限」跟着涨 → 越拖越宽再也缩不回去。
实测 `w=480` 时 `holderW` 变成 480，而 `natW` 冻在 267，正是要的效果。
二是**异步加载**：天气卡取到数据前只有城市名那一行，持续量才能等到真值。

已知缺口：卡片带着一个大于自然宽度的 `w` 启动时，`natW` 来不及量，下限暂时退回
`space.cardWidth`。拖到底一次就会存回 `0`、量到真值，自愈。
另外 `ipc call desktop width` 不走这个下限（那是「我知道我在做什么」的入口）。

一开始做的是 `scale` 缩放整张卡（字和图标一起变大）。那样一个机制就能管住所有
卡片，但放大的是像素不是信息量 —— 日历还是那七列、天气还是那四个小时。
现在是真的改宽度，内容跟着铺开：

| | 自然宽度 | 拖宽之后 |
|---|---|---|
| 日历 | 7 列挤在 240 里 | 格子变大，字号不变 |
| 天气 · 逐小时 | 4 列 | 460px 下自动铺成 10 列 |
| 天气 · 实况块 | — | 整体按比例长大（见下） |
| 正在播放 | 封面三行字高 | 封面跟着宽度长 |
| 壁纸相册 | 缩略图 240 宽 | 缩略图跟着铺开 |

**有可铺的内容就铺，没有就长大。** 这两种反应在天气卡上同时存在：逐小时那行
靠多铺几列吃掉宽度，所以字号不用动；而实况块（城市 / 大温度 / 描述 / 高低温 /
图标）没有可铺的东西，多出来的宽度只会变成中间一片空白、图标被推到最右边 ——
所以它按 `contentWidth / 自然内容宽` 算一个倍数（夹在 1～2）整体放大。

判断标准就一条：**这块内容能不能用更多宽度装下更多信息**。能，就铺；不能，才放大。

#### 一个会让「铺」悄悄失效的坑

`Layout.fillWidth: true` 设了也可能纹丝不动。实测过的一次：

```
hero.w=443  hero.fill=true                      ← 实况行填满了
hour.w=341  hour.fill=true  hour.implicit=341   ← 逐小时行一动不动
```

两行写法一样，差别在子项。逐小时每一列是个 `ColumnLayout`，它的三个子项当时
全是 `Layout.alignment: Qt.AlignHCenter`。**带 alignment 的子项不会被拉伸**，
于是这个 `ColumnLayout` 算出来的 `maximumWidth` 被封死在最宽子项（29），
外层 `RowLayout` 的最大宽度跟着被封死 —— `fillWidth` 再真也长不开。

规律：**嵌套布局的最大宽度来自它的子项**。想让一层能被撑开，它至少得有一个
子项是能撑开的。修法是把「布局对齐」换成「文字自身居中」：

```qml
StyledText {
    Layout.fillWidth: true                   // 让这一列有东西能撑开
    horizontalAlignment: Text.AlignHCenter   // 视觉上还是居中
}
```

改完每列从 29 撑到 41、整行从 341 填满 450。

排查手段也记一笔：这种问题看截图只能猜，**直接把 `width` / `implicitWidth` /
`Layout.fillWidth` 打到 `qs log` 里量一遍**，一次就定位了。

**怎么传下去的。** `ui/Card` 多了两个属性：

```qml
property int fixedWidth: 0                       // 外部指定，0 = 自然撑开
readonly property int contentWidth: (fixedWidth > 0 ? fixedWidth : Style.space.cardWidth) - pad * 2
implicitWidth: fixedWidth > 0 ? fixedWidth : body.implicitWidth + pad * 2
```

`contentWidth` 故意**不从 `implicitWidth` 推** —— 那样「宽度 → 日历格子 → 内容宽 →
宽度」会成环。桌面层用一个 `Binding` 把宽度喂进 `holder.item.fixedWidth`，
这等于约定了**每个桌面组件的根必须是 `ui/Card`**。

卡片内部要重排的地方读 `contentWidth`：日历的格子是它七等分，相册缩略图等于它，
天气按 `contentWidth / 列宽` 算显示几列（服务那边一次给 12 个小时，够铺）。

### 这次绕不开 mask

自由定位要求窗口**铺满**整块可用区域，卡片之外的桌面就被挡住了。
所以必须抠输入区：`mask` 只留各卡片的矩形，其余穿透。

`Region` 没法用 `Repeater` 生成（那只认 `Item`），所以每张卡自己带一个
`Region` 子对象，创建时登记、销毁时注销，窗口的 `mask` 绑那个数组。
用 `Region.item` 而不是手写 x/y，省得自己操心坐标系换算。

**手势进行中必须把 mask 整个关掉**（`mask: null`）。卡片跟着鼠标走的时候 `Region`
也跟着变，等于在指针抓取期间不停改 surface 的输入区；鼠标一快就跑到区外，
compositor 发 `leave`，抓取当场断掉 —— 表现就是「拖快了卡片不动了」。
手势期间整个屏幕反正都归这一次操作，收下所有事件没有副作用。

### 拖动与吸附

拖动条是卡片顶部 `space.l` 高的一条透明带，没有可见手柄。

**这条带必须用 `DragHandler`，不能用 `MouseArea`。** 它会压住日历的「‹ 月份 ›」
那一行，而 `MouseArea` 一按下就独占抓取，月份再也翻不了。`DragHandler` 在超过
拖动阈值之前只做被动抓取：「点一下」照常落到下面的按钮上，「按住拖」才接管。
右上角的 `×` 同理，不受影响。

位移按 `centroid.scenePosition − centroid.scenePressPosition` 算，不用
`activeTranslation`：卡片拖动时自己在动，在它的坐标系里算位移会和自身位移互相喂，
越拖越飘。用 `scenePressPosition` 当基准还顺带消掉了「越过阈值那一瞬间跳一下」。

吸附候选位：屏幕左 / 右 / 居中，以及其它卡片的左右（上下）边缘对齐、紧贴两侧。
阈值 `space.s + space.xs`。

坐标会夹在可用区域内 —— 换分辨率或插拔显示器后卡片可能落到屏幕外，夹一下至少
还看得见、还拖得回来。**但不写回 config**：接上外屏再拔掉，不该把原来的位置悄悄改掉。

### 目录在 modules，选择在 core

「有哪些组件可选」是一份目录（`modules/DesktopWidgets.qml`），
「用户勾了哪几个、摆在哪」是一个数组（`config.json` 的 `desktopWidgets`）。
面板照着目录列选项，桌面层按 key 从目录取 `Component` —— 两边读同一份，
不会出现「面板里能勾、桌面上不出现」。

目录没放 `core/` 是因为它装的是 `Component`，而 `core/` 不许反向依赖视觉层。
代价是 `qs ipc call desktop add` 校验不了组件名：拼错的名字加进数组后没人认领，
`Loader` 拿到 `null` 就什么都不加载，不会出错。要带校验的入口就用齿轮面板。

**加一张卡 = 在目录里加一行 + 一个 `Component`，就这一处。**
删除和拖动都不用管 —— `×` 和拖动条都在 `overlays/DesktopLayer.qml` 里套在每张卡
外面，`ui/Card.qml` 不认识 `Config`，也不知道自己能被删被拖。

### 天气

数据源 Open-Meteo，免费不要 key。两步：城市名 →（geocoding）经纬度
→（forecast）实况 + 逐小时 + 当日高低温，经纬度只在城市名变了时解析一次。

`services/` 是叶子读不到 `core/`，所以 `weatherCity` / `weatherInterval` 是
`modules/WeatherCard.qml` 用 `Binding` 喂进服务的。顺带的好处：**把天气卡删掉，
`Binding` 跟着销毁，city 还原成空串，请求就真的停了** —— 不是在后台空转。

**失败要退避重试，不能等下一个周期。** 开机时 Hyprland 的 `exec-once` 和
NetworkManager 几乎同时跑（实测两边都落在开机后第 9 秒），DNS 往往还没就绪，
第一发必然 `curl 6`。只按 `weatherInterval` 轮询的话，要等满 15 分钟才有第二次
尝试 —— 表现就是「每次重启天气都挂、过一会儿又自己好了」。挂起唤醒掉线同理。

所以失败分两类：**传输失败**（DNS / 连接 / 超时）按 5s → 10s → 20s → 40s → 60s
退避快重试，成功后归零退回正常周期；**数据失败**（城市拼错、返回体不对）重试
多少次都一样，只报错不进退避，免得每分钟空打一发。两类都 `console.warn`，
`qs log -p .` 里看得到 —— 原先失败只写进卡片，日志里查不到。

`curl` 失败时 stdout 是空的，所以两个 `StdioCollector` 都先判空直接 return，
把原因交给 `onExited` 说 —— 否则会先报一个误导的「解析失败」。

### 同一棵组件树，四种观感

示例卡里一个字面视觉值都没有，所以四套主题下自动变样。以日历的「今天」为例：

| | gruvbox | glass | material | pastel |
|---|---|---|---|---|
| 卡片 | 直角不透明 | 圆角玻璃 | 圆角玻璃 | 圆角、字大一号 |
| 今天 | 只有文字变橙 | 实心蓝方块 | 蓝紫圆形药丸 | 黄色圆形药丸 |

靠的就是 `color.selected` / `onSelected` 这对 token：gruvbox 把 `selected` 设成
`transparent`，底色自动隐形，组件里不用写 `if`。圆不圆来自 `shape.radiusFull`。

相关 token：`space.desktopMargin`（距屏幕边缘）、`space.desktopGap`（卡片之间）、
`space.cardWidth`（卡片宽度，日历的 7 列由它七等分反推）。

## 启动器

一个输入框，两种来源，靠前缀切：

| 输入 | 来源 | 回车做什么 |
|---|---|---|
| （无前缀） | `DesktopEntries` 里的应用 | **总是开新实例**；`Shift+Enter` 才切到已有窗口。已经开着的应用右侧标签是「运行中」—— 那是状态，不是动作 |
| `/` 开头 | 已经打开的窗口 | `activate()` 切过去 |

键盘：`↑↓` / `Ctrl+J K` / `Tab` 移动，`Enter` 执行，**`Shift+Enter` 切到已有窗口**，
`Esc` 关闭，`Ctrl+U` 清空，`PageUp/Down` 翻一屏。
鼠标点一行等同回车（`Shift+` 点击同理），点面板外面关掉。

**默认开新的，不是切过去** —— 和 rofi / wofi 一致：「搜应用」通常就是「要一个新的」；
「回到那个已经开着的」是另一件事，交给 `Shift` 和 `/` 窗口模式。
想换回「默认切过去」，把 `run()` 里的 `alt` 取反即可。

### 为什么没有「跑一条 shell 命令」

做过一版 `>` 前缀交给 `sh -c`，又拿掉了：**输出看不见，连失败都看不见。**

Hyprland 的 `exec-once` 把 quickshell 的 stdout/stderr 都接到了 `/dev/null`
（`ls -l /proc/<pid>/fd/1` 直接能看到），`Quickshell.execDetached` 起的子进程原样继承这两个 fd。
于是 `qs log` 里没有（那只收 QML 的 `console.*`），journal 里也没有，退出码也拿不到 ——
`systemctl suspend` 这类「发出去就完事」的还行，`ls` / `make` 等于白跑。

要补救得挑一条：用 `Process` 收输出 + `notify-send` 弹通知（desk 自己就是通知服务端），
或者 `kitty -e sh -c "...; read"` 丢进终端。两条都不难，但一个**看不到结果的命令行入口不如不给** ——
真要跑命令，`SUPER + Return` 开终端是更诚实的路径。

```bash
qs ipc call launcher toggle    # 开/关
qs ipc call launcher open      # 只开
qs ipc call launcher state     # 现在开没开、开在哪块屏
```

**快捷键是 `SUPER + D`**，绑在 `~/.config/hypr/hyprland.lua`（用户自己的配置，不在本仓库）——
那里原来绑的是 `hyprlauncher`，现在把 `menu` 变量换成了这条 IPC，旧的一行注释着留在原地。
`toggle` 是幂等的，再按一次就关。

换个键或者换台机器的话，`.conf` 配置下是：

```
bind = SUPER, D, exec, qs -p /home/yao/workspace/desk ipc call launcher toggle
```

### 排序：打分为主，频率为辅

`services/Apps.qml` 给每个条目打一个分，**分档而不是连续**，让强匹配永远压过弱匹配：
完全相等 > 名字前缀 > 词首 > 首字母缩写 > 子串 > 子序列（连着的字符加分）。
字段权重 名字 > 通用名 > 关键词/分类 > 说明 > 命令行，**取最大值而不是累加** ——
累加的话，说明写得长的应用会靠「哪儿都沾一点」压过名字正好对上的那个。

实测：`fi` → Firefox 第一（名字前缀）而不是 Dolphin（子序列）；
`ccs` → CC Switch（首字母缩写）；`ter` → kitty（通用名 Terminal）。

启动次数记在 `config.json` 的 `launcherUsage` 里，**只保留最高的 40 条**。
空输入时就是纯频率榜，有输入时只当同分的断连器。
切窗口不记账 —— 否则一直开着的终端会把榜单压死。

`services/` 是叶子读不到 `core/`，所以频率表是由 `modules/Launcher.qml`
当参数喂进 `Apps.search()` 的，和天气卡用 `Binding` 把城市喂给服务同一个路子。

### 四种主题，四种形态

组件树只有一棵，差异全在 `themes/*.json` 新增的 `launcher` 段：

| token | gruvbox | glass | material | pastel |
|---|---|---|---|---|
| `width`（0 = 铺满一行） | `0` | `560` | `600` | `620` |
| `align` | `top` | `center` | `center` | `center` |
| `rowHeight` / `rows` | `24` / `12` | `40` / `7` | `56` / `6` | `52` / `7` |
| `iconSize`（0 = 不画） | `0` | `24` | `32` | `30` |
| `subtitle` / `hint` | 都关 | 都开 | 都开 | 都开 |
| `scrim`（背景压暗） | `0` | `0.25` | `0.32` | `0.35` |
| `opacity`（面板自己） | `1.0` | `0.95` | `0.96` | `0.96` |

于是 gruvbox 是**贴着栏下沿、铺满一行、没有图标的 dmenu 条**，选中只是文字变橙；
glass 是居中的 Spotlight；material 是大圆角 M3 卡；pastel 大字 + 琥珀色药丸。
选中行还是那对老 token：`color.selected` / `onSelected`。

**`launcher.opacity` 为什么不跟 `effect.opacity`。** 栏和弹层底下通常是壁纸，
启动器底下是任意窗口 —— 同一个 `0.7`，在壁纸上是玻璃，在一屏代码上就是看不清。
设 `-1` 可以退回跟随 `effect.opacity`。实现是 `ui/Surface` 的 `opacityOverride`。

### 两条踩过的坑

**一、`themes/material.json` 是生成物，加 token 必须同时改模板。**
写完四个主题的 `launcher` 段之后，壁纸刚好轮换了一次，matugen 按
`tools/matugen/material.json` 重新生成，material 的 `launcher` 段当场消失。
新增任何 token 都要在**两处**都写：主题文件和模板。

**二、这台机器上 `layerrule = blur` 其实没生效，别指望模糊保证可读性。**
实测顶栏区域的边缘能量保留 0.78，而纯 alpha 合成的理论值是 0.75 —— 也就是说
背景根本没被模糊，整条栏和所有弹层都一样（不是启动器引入的）。
启动器因此靠 `launcher.opacity` 自己撑可读性，四个主题都压到 0.95 以上 ——
没有模糊托底的时候，0.88 那档在壁纸和代码上都还透得能读出背后的字。要查这类问题别靠眼睛，
截两张图量边缘能量：

```python
from PIL import Image, ImageFilter, ImageStat
r = Image.open(shot).convert("L").crop(box)
print(ImageStat.Stat(r.filter(ImageFilter.FIND_EDGES)).mean[0])
```

### 「切换到已有窗口」踩的三个坑

**一、动作必须等面板 unmap 之后再发，否则焦点被合成器抢回去。**
面板是 `keyboardFocus: Exclusive` 的 layer surface：它还挂着的时候合成器不会把焦点
让给别的窗口；而它关掉的那一刻，焦点又会被还给**原先那个**窗口 —— 正好盖掉刚发出去的
`Toplevel.activate()`。表现是「标着切换，回车毫无反应」。

`Qt.callLater` 不够（还在同一轮事件循环，unmap 的请求可能都没发出去）。
现在是 `dismissed()` 之后挂一个 80ms 的 Timer 再执行，连做三次都稳定。
验的时候要把两件事拆开：先用一个临时 IpcHandler 直接调 `activate()`（不经过启动器），
确认 API 本身没问题，再去查竞态 —— 否则会误以为是 Quickshell 的 bug。

**二、appId 和 .desktop 的 id 对不上的情况比想象中多。** 三条规则挨个试：

1. `appId` 直接等于 id，或等于条目里的 `StartupWMClass`
2. 只差一个前缀段：反向域名（`org.mozilla.firefox` ↔ `firefox`）或自定义 class
   （`kitty --class floating-kitty`）。**按分隔符切一刀再比尾段**，不是裸 `endsWith` ——
   否则 `mykitty` 也会被当成 kitty
3. 还不行就问 `DesktopEntries.heuristicLookup()`（Dock 用的就是它）

这台机器上实测：`kitty`、`google-chrome` 第一条就中；`floating-kitty` 要靠第二条，
`heuristicLookup` 对它返回空。

**三、动作推迟到 Timer 之后，参数也得跟着推迟。**
`activate()` 只记下 `pending` / `pendingAlt` 就关面板，真正执行在 80ms 后的
`onTriggered` 里 —— 那里漏了第二个参数（写成 `run(it)` 而不是 `run(it, root.pendingAlt)`），
于是 `alt` 永远是 `undefined`，Shift 那一路静默退回「开新的」。
**验的时候必须看可观测的差别**：窗口数变没变、焦点去了哪。
只看函数回显的那行字会被自己骗过去 —— 第一次就是这么漏掉的。

### 为什么开关状态放在 core/

`core/Ipc.qml` 要能开关它，而 `core/` 不许反向依赖 `overlays/`。
于是开关是 `core/LauncherState.qml` 这个单例，IPC 和窗口层都认它。
它还在**打开那一瞬间锁定一次当前屏**（`Hyprland.focusedMonitor`）而不是一直绑着 ——
绑着的话，鼠标跟随焦点的配置下光标划到另一块屏，启动器会连人带输入一起跳过去。

查询串**不**放在这里：那是面板自己的瞬态，关掉就该忘掉。

## 分层规则

```
layouts ──► modules ──► ui ──► core/Style ──► themes/*.json
overlays ──┘       └──► services
```

`tools/check-style.sh` 强制这几条：

- `modules/` 和 `layouts/` 不得出现 hex 色值、字面字号/圆角/边框，不得直接用裸 `Rectangle`/`Text`
- **`services/` 是叶子**：只读外部系统状态（Pipewire / UPower / NM / /proc / 通知），连 `core/` 都不许依赖
- `core/` 不得反向依赖视觉层

`services/` 和 `core/` 的分界：**外部系统状态归 services，shell 自己的配置归 core**。
所以「当前壁纸」在 `core/Wallpaper.qml` 而不是 `services/` —— 它读的是 `config.json`，不是系统。

## hover 和 onHover 是一对

`color.hover` 是悬停底色，`color.onHover` 是它上面的文字色（空 = 继承 `onSurface`）。
`selected` / `onSelected` 早就是一对，`hover` 原来却是光杆一个 —— 直到 pastel 把它设成
**不透明的近白色** `#f0f6fc`，而文字还是 `onSurface` 的近白 `#e5ecf3`：**白底白字**。

```
gruvbox  hover=#3c3836    深色   → 白字能读
glass    hover=#26ffffff  半透明 → 白字能读
material hover=#303638    深色   → 白字能读
pastel   hover=#f0f6fc    亮色   → 必须翻成深色字 onHover=#101c28
```

深色 hover 的三个主题完全不用写 `onHover`，视觉零变化 —— 和 `module.on` 一个路子。

**凡是在 hover 底色上放字/图标的地方都要用这个 tone**，不是只有启动器：
`ui/ResultRow`、`ui/MenuRow`、`ui/Tile`、`ui/IconButton`（栏上的齿轮，pastel 下悬停原本
会把深色字翻成白字）、`ui/StyledMenu`（托盘右键菜单）、`modules/SettingsPanel` 的返回条、
`modules/Dock` 查不到图标时的首字母、`modules/CalendarCard` 的月份条。
`modules/NotificationToast` 的操作按钮比较特殊：它把 hover 色当**常驻底色**用，所以文字
一直是 `onHover`，不分状态。

验的时候别用眼睛扫截图，也别在 `onHoveredChanged` 里直接读 `tint` ——
**信号处理器可能比绑定先跑**，读到的是旧值（这次就被骗了一回，以为绑定失效了）。
挂个 200ms 的 Timer 等绑定稳定下来再打日志，同时截图。
鼠标可以用 `hyprctl dispatch 'hl.dsp.cursor.move({x=960, y=430})'` 挪上去，
warp 一样会触发 hover。

## Token 设计里几个关键点

这些是"一套组件撑起多种风格"真正成立的地方：

- **`color.selected` / `color.onSelected`** —— 选中项的底色与其上文字色。
  gruvbox 把 `selected` 设成 `transparent`，选中就只是文字变橙；
  glass 把它设成 accent，选中就是一颗实心蓝药丸。**同一棵组件树**。
- **`space.barMargin`** —— `0` 贴边，`>0` 悬浮。悬浮栏不是另一个布局，是另一个主题。
- **`shape.barRadius`** —— 栏本体圆角，`-1` 表示跟随 `radiusL`。
  单独拆出来是为了 macOS 风格的「栏方、弹层圆」：菜单栏贴边且直角，
  但菜单和面板是圆角的。其它主题不填就是原样。
- **`motion.enabled: false`** —— `Style.durNormal` 自动归零，组件里不写 `if`。
- **`effect.opacity`** 只作用在 `level 2`（弹层），`level 0`（栏底）走单独的
  **`effect.barOpacity`** —— 想让栏"几乎只剩壁纸"又不把通知卡片一起稀释掉。
  pastel 干脆设成 `0`：栏底彻底消失，只剩一排彩色药丸浮在壁纸上，而弹层
  仍然是 `opacity` 那档 `0.72`。注意 `0` 要走 `??` 才传得下去（`||` 会把它
  当成"没填"退回 `effect.opacity`），`core/Style.qml` 的 `barOpacity` 用的正是 `??`。
  栏内组件（level 1）始终不透明，否则选中高亮会被二次稀释成一团糊。
- **`logo` 段** —— 栏最左那颗徽标画什么：`glyph`（Nerd Font 字形，默认是 Arch 的
  `nf-linux-archlinux`，跟着 `onSurface` 走，所以是单色的）、`icon`（图标名或绝对路径，
  非空时顶掉 glyph）、`tone`（空 = 跟随药丸，填 `accent` 可单独染成品牌色）、
  `size`（0 = 跟随 `font.sizeL`）。药丸底色走 `module.logo`，和其它组件同一个规矩，
  设成 `transparent` 就只剩徽标本身。换发行版不用改组件 ——
  `modules/LauncherButton.qml` 只认「点了之后开启动器」。

  `icon` 填**名字**而不是绝对路径：查不到的名字会退回 `glyph`，查不到的路径
  只会什么都不画 —— 一个留着退路，一个开天窗。四个主题里 pastel 用的就是
  `"icon": "archlinux-logo"`（官方那枚蓝色 SVG，`/usr/share/pixmaps` 归
  `filesystem` 包，Arch 上一定有），另外三个保持单色字形。

  另外三个 token 管它**占多大、站哪**：`padding`（左右内边距）、`inset`
  （距栏左沿多远）、`gap`（和右边工作区那组的间距），都是 `-1` = 跟随
  `space.xs` / `space.barPadding` / `space.s`。拆出来是因为栏上通用的那套
  间距是给一行状态药丸用的，套在徽标身上就显得空旷 —— 它是钉在角上的标记，
  该比别人更贴边。四个主题各按自己的尺度填：

  ```
            徽标                    内边距 / 距左沿 / 间距
  gruvbox   glyph 奶白 #ebdbb2          4  /  6  /  4
  glass     glyph 纯白单色              4  /  6  /  6   ← 像 macOS 那样钉在左上角
  material  glyph 跟随 onSurface        5  / 10  /  6   ← 栏是悬浮圆角的，给圆弧让开
  pastel    icon  官方蓝色 SVG，20px     5  /  8  /  6
  ```

  徽标在 `layouts/parts/TopBar.qml` 里不进 `leftGroup` 那条 `RowLayout`，
  自己锚左沿 —— 一条 RowLayout 只有一个 `spacing`，想让「徽标↔工作区」比
  「工作区↔窗口标题」更紧，就不能和它们挤在同一条里。
- **`module` 色组** —— 每个组件自己的药丸底色（`clock` / `network` / `cpu` / …），
  外加 `module.on` 作为这些药丸上的文字色。
  **不写就是透明**，`module.on` 留空则继承 `onSurface` ——
  所以 gruvbox / glass / material 完全不受影响，只有 `pastel` 填了这一段。
  组件进入告警态时换的是**色位**（`alert`）而不是染文字色，这样在彩色底上才读得清。

主题文件可以只写想改的字段：`core/Style.qml` 会合并到 `Defaults` 上，
写错 JSON 或缺字段都会退回默认值，shell 不崩（日志里有 WARN）。

## glass 的 macOS 配色出处

配色取自 [kelian-4/lickintosh](https://github.com/kelian-4/lickintosh)
（macOS Tahoe for Quickshell）的 liquid glass 变体，关键值：

| | 值 | 来源 |
|---|---|---|
| accent | `#1c7aff` | 其 `accent`，macOS 系统蓝 |
| 次级文字 | `#a0ffffff` | 其 `textSecondary`，63% 白 |
| 悬停底 | `#26ffffff` | 其 `fillHover` 加强一档 |
| 分隔/描边 | `#20ffffff` | 其 `panelRim` |
| 栏高 | 30 | 其 `barHeight` |
| 弹层透明度 | 0.85 | 其 `panelOpacity` |

`success` / `warning` / `error` 用的是 macOS 暗色模式系统色
（`#30d158` / `#ff9f0a` / `#ff453a`），不在该仓库里，是 Apple HIG 的标准值。

几个让它「像 macOS」的点：

- **`surfaceAlt: transparent`** —— 菜单栏项目没有药丸底，只有文字和图标，
  悬停才出现浅色高亮。这是和 `pastel` 最根本的区别。
- **`barMargin: 0` + `barRadius: 0`** —— 贴边、直角、全宽。
- **`radiusFull: 0`** —— 高亮是圆角矩形（8px）而不是胶囊。
- **比例字体** —— `Noto Sans CJK SC` 替代 SF Pro（本机没装）。
  Nerd Font 图标靠 fontconfig 按字形回退到 JetBrainsMono NF，实测正常。

## pastel 的配色怎么来的

六个主色位用 **OKLCH 等亮度等彩度**生成（`L=0.885, C=0.085`），**只变色相**：

| 色位 | 色相 | | 色位 | 色相 |
|---|---|---|---|---|
| battery | 150 绿 | | memory | 80 琥珀 |
| network | 205 青 | | cpu | 355 玫 |
| window | 250 蓝 | | volume | 295 紫 |

等亮度是关键：六块颜色的"轻重"一致，才会读成一套而不是六个独立装饰。
挑完还逐个验了与文字色的对比度，最低 7.4:1（WCAG AAA 是 7:1）。

另外两个是故意破例的：

- `clock` 居中、是视觉锚点 → 更亮更淡（`L=0.945, C=0.028`）
- `alert` 必须跳出来 → 压暗提彩度（`L=0.78, C=0.165`）

想加新组件或换配色，照这个方法挑一个没被占用的色相即可，不用凭感觉试。

## 托盘菜单为什么要自己画

`SystemTrayItem.display()` 弹的是**原生 Qt QMenu**（QtWidgets），由 Qt 平台主题渲染，
完全不经过我们的 token —— 结果就是菜单和栏像两套系统。

`ui/StyledMenu.qml` 用 `QsMenuOpener` 拿到 DBusMenu 的数据模型，自己用 `ui/` 原语重画：
分隔线、禁用态、勾选/单选指示、图标、子菜单都支持，整体跟着主题走。

三个踩过的坑：

- **QML 禁止组件自引用**。子菜单不能写 `sourceComponent: StyledMenu {}`，
  会报 `instantiated recursively`。必须用 `Loader.source` 按 URL 加载，绕开静态检查。
- **菜单行不能带描边**。`Surface` 默认继承 `shape.borderWidth`，密集堆叠时一片碎框。
  为此给 `Surface` 加了 `bordered` 开关。
- **popup 的模糊要单独开**。菜单和弹出面板是 layer surface 的 **xdg_popup**，
  `layerrule = blur` 管不到它们 —— 一开始我据此把菜单写死成不透明。
  实际上 Hyprland 另有 **`blur_popups`**（.conf 里是 `layerrule = blurpopups`），
  开了之后 popup 就跟着糊，可以和栏一样做成半透明。实测确认有效。
  没开这个选项时千万别让 popup 半透明，文字会直接压在壁纸上。

## 嵌套 Surface 的 hover 必须用 HoverHandler

`ui/Surface.qml` 的 `hovered` 走 **`HoverHandler`**，不是 `MouseArea.containsMouse`。

因为 MouseArea 的 hover 是**被顶层消费**的：灵动岛的胶囊里放着时钟/音量这些 Pill，
每个 Pill 内部都有自己的 MouseArea，光标压在上面时胶囊的 `containsMouse` 直接变 false。

于是形成正反馈 —— 这就是灵动岛"鼠标放上去一直闪"的根因：

```
光标压在子药丸上 → 胶囊判定未悬停 → 收起
   → 布局一动，光标落到胶囊内边距 → 判定悬停 → 展开
   → 光标又压回子药丸 → 收起 → …
```

用逐 y 坐标扫描才定位出来（`y=8` 和 `y=43` 的内边距处 true，中间时钟所在的
`y=15/25/35` 全是 false）—— "偶尔放对了是好的"正是光标恰好停在内边距上。

PointerHandler 不受这个限制，父子能同时收到。同时把 MouseArea 的
`hoverEnabled` 收窄成只在 `clickable` 时开，不可点的 Surface 不再白白拦截父级。

另外灵动岛里 `capsule.expanded = hovered || picker.active`：
切换面板开着时要保持展开，否则光标移进面板就离开了胶囊，
胶囊一收起，面板赖以定位的那个按钮就没了。

## Lua 配置下 hyprctl keyword 不可用

Hyprland 0.5x 用 Lua 配置时（`hyprctl systeminfo` 里 `configProvider: lua`），
`hyprctl keyword` 直接返回 **`unknown request`** —— 运行时改配置要走 `hl.config`：

```bash
# 无效（但不会报错到显眼处）
hyprctl keyword decoration:blur:size 10

# 有效
hyprctl dispatch 'function() hl.config({ decoration = { blur = { size = 10 } } }) end'
```

改完用 `hyprctl getoption decoration:blur:size -j` 读回确认，别只看命令的返回值。

## Hyprland 版本依赖

Hyprland 0.5x 起 `dispatch` 换成了 Lua API，旧的字符串语法会被拒绝：

```
dispatch("workspace 5")   →  error: ')' expected near '5'
```

本项目用的是 Lua 写法（见 `modules/Workspaces.qml`）：

```qml
Hyprland.dispatch(`hl.dsp.focus({workspace=${id}})`)
```

两个容易踩的点：

- 切换工作区在 **`hl.dsp.focus`** 下，不在 `hl.dsp.workspace` 下 ——
  后者（`change_id` / `rename` / `move` / `swap_monitors` / `toggle_special`）是改编号和属性的
- 参数必须是 Lua table，传 `3` 或 `"3"` 都会被拒

排查用的小技巧（Hyprland 会把 Lua 错误原样回显）：

```bash
# 列出所有 dispatcher 分类
hyprctl dispatch 'function() local t={} for k,_ in pairs(hl.dsp) do t[#t+1]=k end table.sort(t) error(table.concat(t,", "),0) end'
# 探某个 dispatcher 的参数形状
hyprctl dispatch 'hl.dsp.focus(1)'   # → expected a table, e.g. { direction = "left" }
```

如果以后降级到 0.4x，这行要改回 `Hyprland.dispatch(\`workspace ${id}\`)`。

## 壁纸转场（像素扩散）

换壁纸时，新图从若干随机种子点生长、吞噬旧图，边缘不规则且带辉光。
GPU 片元着色器实现，见 `ui/shaders/spread.frag`。

**改了着色器必须重新编译**，热重载不会帮你做：

```bash
./tools/build-shaders.sh     # ui/shaders/*.frag → *.frag.qsb
```

Qt6 的 `ShaderEffect` 只吃 `qsb` 预编译产物（依赖 `qt6-shadertools`，
通常已被 qt6-declarative 带进来）。

转场参数全在主题 token 里，所以**每个主题的转场观感都不一样**：

| token | gruvbox | glass | material | 含义 |
|---|---|---|---|---|
| `motion.wallpaper` | 1200 | 2200 | 3000 | 时长 ms，0 = 瞬切 |
| `effect.wallpaperCell` | 1 | 3 | 5 | 格子边长 px，越大越像马赛克 |
| `effect.wallpaperGlow` | 0.35 | 0.85 | 1.0 | 边缘辉光强度 |
| `effect.wallpaperSeeds` | 5 | 8 | 12 | 生长原点数量 |

辉光颜色直接取 `Style.color.accent` —— 换主题，连转场边缘一起变色。

`motion.wallpaper` 故意**不**被 `motion.enabled` 门控：那个开关管的是界面动效，
壁纸转场是内容本身的过渡，极简主题下也该有。

着色器里几个值得记的做法：

- **软归一化 `t/(t+k)`** 把生长时间场从 `[0,∞)` 映到 `[0,1)`。
  这样 `progress=1` 时必定全部揭示，不会因为估错最大距离而在末尾硬切。
- **量化要按宽高比修正**：x 用 `cell`，y 用 `cell * aspect`，否则非正方屏上格子是长方形、生长是椭圆。
- **端点必须闭合**。打毛项 `tn += (hash-0.5)*irregular` 会把 `tn` 推出 `[0,1]`，
  于是 `progress=0` 时有散点提前露出 newTex、`progress=1` 时有散点还停在 oldTex。
  解法是把 progress 映射到 `[-m, 1+m]`（`m = irregular/2 + 0.01`）。
  辉光同理要在 `progress→1` 时淡出，否则最后一帧还挂着一圈光，交换缓冲后突然消失。

### 为什么是 ping-pong 双缓冲

`WallpaperView` 用 img0 / img1 轮流当「前景」和「后备」，转场结束**只交换角色**。

最初的写法是转场结束把新图回写进旧图槽位（`oldImg.source = newImg.source`）再把
`progress` 归零。那会触发一次异步解码，而 `progress=0` 恰恰要显示那张正在解码的图
—— 动画末尾就会闪一下。双缓冲下不存在任何重新加载。

验证方法：抓底部缝隙 `1920x2` 连续 80 帧，统计相邻帧的**逐像素**差异
（求平均会把稀疏散点平均掉，测不出来）。修好后前沿扫过的 6 帧有变化，
其余 73 帧差异恒为 0。

## 通知

Quickshell 自己当通知服务端，所以**必须先停掉 dunst / mako 等其他通知守护进程**，
否则 `org.freedesktop.Notifications` 被占用，日志里会出现：

```
WARN: Could not register notification server, presumably because one is already registered.
```

对方退出后 Quickshell 会自动重试注册，不用重启。

行为：普通通知按 `expireTimeout` 自动消失（为 `-1` 时回退 5 秒），
**critical 不自动消失**，点击任意一条即关闭。
注意 `keepOnReload: false` —— 改代码触发热重载会清空当前通知，调试时别误判成 bug。

## 已验证

- 两个主题 × 两个布局自由组合，切换时 `modules/` 代码零改动
- 改 `themes/*.json` 存盘 → 2 秒内生效，不重启
- 非法 JSON → 退回中性灰默认主题 + WARN，shell 存活
- Hyprland 模糊、系统托盘（左键激活 / 右键菜单）、Pipewire 音量（点击静音 / 滚轮调节）、UPower 电池
- 启动器：`ipc call launcher open` 后输入框当场拿到键盘焦点（独占 layer 焦点可用）；
  `Enter` 开新实例（窗口数 +1）、`Shift+Enter` 切到已有窗口（窗口数不变、焦点和工作区都跟着走）、
  `/` 窗口模式都按窗口数和焦点落点验过；四个主题各截一张，形态确实不同
- 启动器的**物理按键**（↑↓ / Enter / Esc）没法在这台机器上自动验 —— 没装 wtype/ydotool，
  验到的是「焦点拿到了 + 按键处理函数接得对」，真按还得人手试一次
