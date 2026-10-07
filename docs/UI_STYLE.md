# Dashboard 统一风格

2026-10-06，按用户要求直接复用 `/Users/raychen/Develop/Dashboard/dashboard-HarmonyOS` 的写法。参照工程只读，本工程独立维护，运行时不依赖其路径。

| 参照文件 | 本工程接入 | 接入范围 |
|---|---|---|
| pages/Dashboard.ets | pages/Index、SystemCapability | HdsTabsController、BottomTabBarStyle、缓存、浮动栏、28vp 底距、渐变遮罩、titleBar originalStyle/scrollEffectStyle、标题菜单、返回振动 |
| component/HdsMiniBarButton.ets | components/HdsMiniBarButton | 直接复制迷你材质栏、弹簧按压、点光源和滤镜；增加全局视效开关，适配无障碍文案 |
| component/HdsTitleBarSegment.ets | components/HdsTitleBarSegment | 直接复用 TabSegmentButtonV2、材质选中背景、尺寸和动画；改为状态管理 V2 输入/回调 |
| common/vibration.ets | common/vibration | 原文件直接复制；软/硬预置、硬件/效果缓存、返回反馈去重；业务通过 HapticService 接入 |
| common/visualEffects.ets | common/visualEffects、InteractiveCard | 复制点光源、暗淡/明亮/高亮强度和 API 24 HDR 隔离；按原要求加上官方 pressShadow，接入视效开关 |
| common/motion.ets | common/motion、HomePage、详情、表单 | 原文件直接复制；三组入场、弹簧过渡、130ms 按压与分页动效 |
| common/scroll.ets | common/scroll、五个主页、SettingsPage | 原文件直接复制；滚轮 / 触控板纵向事件转发，保留 Ctrl、横向输入与异常降级逻辑 |
| pages/main/MyPage MoreRow | SettingsActionRow | HdsListItemCard、PrefixIcon、SuffixCustomBuilder、TextModifier、行高与边距 |
| component/SettingsPanel、common/DiskStorage、common/storage | SettingsPanel、DiskStorage、storage | 原版用户名、振动、材质、缓存顺序、滑块和卡片；单一 app_storage、内存缓存、旧偏好迁移 |
| pages/main/AppsPage commonHeader | components/DashboardSearch | 48vp 搜索框、背景、边框、130ms 弹簧按压；本应用内联筛选保留直接键盘输入 |
| resources/base、dark/element/color.json | 同名颜色资源、Theme | 直接复用相关底色、表面、文字、强调、边框、阴影与遮罩；不复制无关图表配色 |

主路由 HdsNavigation 覆盖完整主页；主页 HdsTabs 的五个 TabContent 分别承载独立 HdsNavigation/NavPathStack，详情压入主路由并使用 HdsNavDestination。Tab 切换保留各自导航位置；重复点击当前一级 Tab 使用参考工程的 300ms 滚动返回顶部。角色/计划、活动列表/日历、装备/照片、作品/时间轴使用 HdsTitleBarSegment 包装原生 TabSegmentButtonV2，放在 titleBar.stackBuilder 的 50% 宽居中区域，尺寸沿用 Dashboard。标题栏、二级分段和浮动底栏保持固定，页面滚动只影响业务内容。各 TabContent 不对整块导航进行缩放或淡入动画。

“我的”标题菜单进入主路由的覆盖式设置 HdsNavDestination，隐藏主页 HdsTabs。设置第一组直接使用原版 SettingsPanel：用户名、支持设备上的振动强度、材质等级、清除缓存。原版光场行处于注释状态；工具继续使用持久化的 lightFieldLevel。外观与单手操作通过 SettingsPanel 的 additionalSettings builder 插入同一设置卡片、位于清除缓存之前，不再单独显示「操作偏好」分组；备份与帮助承载本应用功能；分组标题与卡片间距 8vp、分组间距 14vp，复用参考工程分组入场动画。列表分组间距、标题缩进和卡片圆角取自参考工程。

首页直接复用参考工程的时段问候、用户名/设备名回退、26vp 标题与 14vp 欢迎文字；欢迎文案中的品牌在资源中配置。

Icons 集中定义系统资源语义名称；新图标先确认本机 SDK 中的 media 资源类别与可用名称，不能把 symbol 名当作 media 名。详情操作栏的添加和封面使用 Icons 中的 SymbolGlyphModifier（plus / picture），以 sys.color.icon_primary 跟随深浅色；当前 HdsActionTabs 将其映射为 TabBarSymbol。照片与角色封面仍来自用户记录。

公共确认 Dialog 沿用 Dashboard LocalHtmlPage 的按钮颜色：取消使用 diff_content，确认删除或替换使用 v3_accent_red。均通过同名浅/深色资源解析，不在 Confirm 中保存另一套十六进制颜色；取消与确认的行为保持原有数据保护约定。

设置使用 Dashboard 的单一 Preferences 文件 app_storage；DiskStorage 按文件维护实例及内存缓存，写入 flush 成功后同步同名 AppStorage key。EntryAbility 在 loadContent 前加载偏好。旧 settings 文件中的主题、触觉、材质、握姿等通过显式迁移保留，既有目标值优先；Preferences 不保存业务实体。SettingsService 将这套偏好映射到应用状态。

HDR 仅在 API 24+、用户选“高亮”且发生按压时尝试；已声明 HDR_BRIGHTNESS。API 23 自动使用明亮光场，设备不支持或调用失败时保留普通光场。HDS 材质直接使用 API 23 能力，无 ArkUI API 26 uiMaterial 依赖。真实亮度、触觉与设备能耗仍需硬件体验验收。

## 安全区与密度

窗口保留原生避让布局，HdsTabs 使用 height(LayoutPolicy.matchParent) 和系统顶部/底部 ignoreLayoutSafeArea 承载沉浸内容。标题样式沿用 Dashboard 的 originalStyle / scrollEffectStyle；本工程外层 Tabs、内层 Navigation 与参考工程层级相反，显式设置 avoidLayoutSafeArea=true 保证标题避开状态栏，自定义二级分段在标题栏固定区域。主页浮动栏复用 Dashboard 四项 250vp 的每项密度：五项为 Theme.mainTabsWidth（312.5vp），窄窗以窗口宽−32vp 为上限；barBottomMargin 28vp、透明渐变遮罩高 92vp。

详情覆盖主页并使用独立 HdsTabs 浮动操作栏，不再叠加主底栏和 toolbar；滚动内容保留 110vp 底距。详情操作栏按动作数采用 min(max(168vp, 动作数×72vp), 窗口宽−32vp)，复用相同材质与底距。顶部使用参考工程的 Blank(100vp) 与容器间距（首页、设置、详情 14vp，搜索列表 12vp）；底部首页 96vp / 列表 110vp 留白放在滚动内容内部。衣柜照片和作品集使用惰性加载的照片行列表，筛选/统计作为首项一起滚动，末尾留白保证内容能滚到浮动栏上方。设置 Scroll 从顶部排列，原版常规滑块卡片高 68vp，330vp 以下使用窄屏布局。

照片统一使用 ManagedImage：沙箱路径经 MediaRepository 转为 file URI，缩略图与原图都报告加载/错误状态。原图文件不存在时保留补回提示。

缓存操作由 MediaRepository 完成，仅访问 cacheDir；原图与缩略图位于 filesDir/media。测试使用 verification-* 隔离目录；清除缓存经过用户确认。

依据：[Tabs 安全区说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-1584)、[Navigation 自定义区域](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/ui-design-navigation-customized-area)。真机安全区和固定区域几何验收以 VALIDATION.md 中最新记录为准，源码对齐不等于视觉验收通过。

## 2026-10-06 用户交互修正

主路由覆盖主页，Tab 导航保留在主页内部。角色、项目、资产、漫展、照片详情和设置均为独立 HdsNavDestination；详情动作使用 HdsActionTabs，点击触发操作并拦截页签内容切换。所有新增和编辑使用 bindSheet。

设置的偏好行也使用 PrefixIcon / IconSize.SYSTEM_ICON，与原版 SettingsPanel、SettingsActionRow 共用前后边距。外观固定跟随系统并提供说明；单手控件复用 Dashboard 的 190vp 三档 Slider 和 12vp 标签，顺序为左手、智感握持、右手。行高 68vp，330vp 以下改为 116vp 的上下布局。帮助组使用原版 MoreRow 卡片格式，实际使用说明和数据说明通过 Sheet 阅读。

原生视效独立开关移除，流畅档统一关闭材质、按压光场和 HDR 增强；轻柔/精美开启对应等级。偏好升级保留此前关闭视效的意图，手动左右手关闭感知；中间档权限拒绝时保留原选择。

分段控件按参考文件分别处理 $selectedIndex 与 onItemClicked：切换只更新外部选中状态，点击通过同一 HapticService 提供反馈，重复点击当前分段也遵循原版行为。HdsMiniBarButton 同步 Dashboard 2026-10-07 的阴影修复：HdsTabs 材质背景单独以实际高度（barHeight − 12）的一半为圆角裁剪，阻止灰色矩形背景外露；背景层不参与命中测试，前景按压光场保持独立。TabSegmentButtonV2 显式关闭背景模糊，统一由迷你栏提供材质。公共卡片沿用 0.985 缩放与 130ms 弹簧参数。

业务提示统一从 Index 调用复用的 showToastSafely；AppState.reportError / reportNotice 为每次报告递增反馈版本，使相同提示能再次显示。FormEditor 将校验异常交给这一入口，不在内容区插入错误文字或维护另一套提示组件。

计划详情复用相同 HdsTitleBarSegment，在标题栏 50% 居中区域切换准备 / 打包 / 照片；计划名称保留在滚动内容首部。底部 HdsTabs 只显示当前视图相关动作。新建计划优先显示角色、计划名称和可选日期，扩展信息通过「更多设置」展开；所有新增/关联继续使用 bindSheet。

## 2026-10-06 全局一致性修正（安全区 / 外观 / 弹层 / 动效）

### 安全区：以首页为唯一基准

一级页面与二级页面使用同一套规则：**HdsNav 标题栏避让系统顶部，内容区上下全屏沉浸**。

- 外层 `HdsNavigation`、内层每个 Tab 的 `HdsNavigation`、以及 `HdsNavDestination` 都显式 `.ignoreLayoutSafeArea([SYSTEM], [TOP, BOTTOM])`。
- 标题栏 `avoidLayoutSafeArea` 必须分级设置：内层 HdsNavigation 传 `true`（外层 HdsTabs 已忽略安全区，不避让标题会进入状态栏）；HdsNavDestination 传 `false`（与 Dashboard AppDetailPage 相同，HDS 自身已避让，再开一次会把标题栏整体下移一个状态栏高度 33vp）。`SystemCapability.titleBar` 的 `avoidSafeArea` 参数就是为此保留。
- 滚动内容的第一项是 `Blank()`，最后一项也是 `Blank()`，不留底部 padding：
  - 一级页面（首页、Cos、活动、衣柜、我的）：`Theme.contentTop`(100vp) + `Theme.homeContentBottom`(96vp) / `Theme.contentBottom`(110vp)。
  - 二级页面：`Theme.detailTop`(100vp) 与一级页面一致；标题栏内还有分段按钮时用 `Theme.detailTopWithSegment`(112vp)（分段会向下溢出标题栏，计划详情的准备/打包/照片与计划照片列表）。
- `scrollEffectOpts.enableScrollEffect` 与 Dashboard 一致保持关闭。

### 应用外观：天蓝（浅色）/ 雾蓝（深色）/ 跟随系统

- 三档顺序固定为**天蓝 / 跟随系统 / 雾蓝**（索引 0 / 1 / 2），对应 **浅色 / 跟随系统 / 深色**，默认跟随系统。`APPEARANCE_LIGHT='sky'`、`APPEARANCE_DARK='mist'`、`APPEARANCE_SYSTEM='system'`；持久化字符串不变。
- 实现方式是 `context.getApplicationContext().setColorMode(...)`：天蓝 → `COLOR_MODE_LIGHT`，雾蓝 → `COLOR_MODE_DARK`，跟随系统 → `COLOR_MODE_NOT_SET`。切换后系统按 ColorMode 解析 `base` / `dark` 资源，全应用立即刷新。
- **不新增颜色资源**：`resources/base|dark/element/color.json` 与 Dashboard 逐项一致（仅多 `on_accent`，Dashboard 无同名 token），没有第二套调色板。
- 深浅色偏好持久化在 `app_storage` 的 `appearance`，`SettingsService.load` 在启动时应用，`EntryAbility` 不再强制 `COLOR_MODE_NOT_SET`。
- 颜色一律走 `Theme.*`；`common/Theme.ets` 的 `@ObservedV2` 单例只提供 Dashboard 同名资源，组件读 `Theme.*` 即可，深浅色由 ColorMode 决定。

### 图标

- 设置页 `HdsListItemCard` 的图标**一律使用 `app.media` 里的浅/深两版 PNG**，与 Dashboard MyPage / SettingsPanel 的用法一致：`user`（用户名、操作模式、华为账号）、`vibrate`、`immersive`、`light`、`trash`（清除缓存、清空本地数据）、`tutorial`（使用说明）、`privacy`（隐私协议）、`cloud`（云同步）、`export`（导出元数据 JSON）、`load`（从元数据备份恢复），行尾箭头用 `right`（Dashboard MoreRow 同款），不使用 `sys.media` 的系统图标。
- `cloud` / `export` / `load` 为本应用新增（浅深各一版）；`tutorial` / `privacy` / `right` 直接从 Dashboard 的 `AppScope/resources/base|dark/media` 复制，保证同一套风格。
- 一级导航、标题菜单与详情动作栏继续使用系统符号（`sys.media` / `sys.symbol`），跟随系统色调。
- 图标统一在 `common/Icons.ets` 注册，页面只引用语义名。

### 弹层

- 内容型弹层一律 `bindSheet`，并且**右上角必须是关闭按钮**（`components/SheetHeader`），因此关闭系统自带关闭按钮（`showClose: false`）。
- `common/sheet.ets` 的 `appSheetOptions()` 统一 Sheet 高度、圆角拖拽条、遮罩色与 `onDisappear`；返回键与侧滑关闭同样走 `onDisappear`，调用方状态一定复位。
- 破坏性动作（删除、清空、替换封面）继续使用系统确认 Dialog，不与内容弹层混用。

### 动效与反馈

- `animStep` 分组出现动画：**一级 HdsTabs 页面在进入应用后只播放一次**（`enterPlayed` 守卫 + `@Monitor('active')`），**二级页面每次进入都播放**（`aboutToAppear` 起、`aboutToDisappear` 取消并归零）。分组数按页面内容 2–4 组。
- 所有可点元素都有短振动：卡片走 `InteractiveCard` 内置反馈，详情操作栏在 `HdsActionTabs` 统一反馈，迷你栏在 `HdsMiniBarButton` 反馈，确认弹窗在 `Confirm.confirm` 反馈，其余按钮/下拉/自绘可点行调用 `vibration.dotVibration()`（内部读取用户振动强度，强度为关闭时静默）。返回、页签切换、分段点击沿用 `HapticService`。
- 返回有三重保障：底部/标题栏返回按钮（`content.backIcon.action`，与 Dashboard AppDetailPage 一致）、`onBackPressed`（自行消费并出栈）、以及路由 `customNavContentTransition` 的 POP，去重由 `vibration.backVibration` 的 120ms 窗口负责。
- `common/vibration.ets` 在原 Dashboard 实现上增加回落：`haptic.effect.*` 不受支持或查询失败时改用时长振动（`type: 'time'`），保证有振动硬件的设备不会静默无反馈。
- 有文字的可点元素都要 `accessibilityText`；装饰性文字（`›`、`★`、`○`、首字占位）标 `accessibilityLevel('no')`。

### 顶部 SegmentButtons 宽度

一级页面与计划详情统一使用 Theme.titleSegmentWidth（`'50%'`），直接复用 Dashboard.appsTitleSegment 的 normalWidth / experimentalWidth 和居中 builder。移除按标题长度、项数计算及 320vp 封顶，英文标题不再缩窄分段，大窗口仍占标题栏一半。标题、菜单和分段的可见边界与固定位置须通过布局测试核验；系统大字体和真实多窗另行验收。

### 信息层级：去掉大标题 + 小标题

- 页面标题只出现在导航标题栏；内容区不再重复 26–32vp 的实体大标题。
- 分组标题统一 `SectionHeading({ title, trailing })`：15vp Medium + 次级色，一行，数量/状态放 `trailing`；`subtitle` 参数已删除。
- 详情页的「标签：取值」改用 `FactRow`；空状态标题降到 16vp。
- 设置页分组标题复用 Dashboard MyPage 的 14vp Bold + 强调色。

### 设置页结构（自上而下）

应用图标 + 中文名 + 英文名 → 分割线 → 华为账号（登录/退出 + 云同步状态）→ 数据与备份 → 设置（用户名、振动强度、材质等级、应用外观、操作模式、清除缓存）→ 帮助（使用说明、隐私协议）→ 版本与版权信息。外观（天蓝=浅色 / 雾蓝=深色 / 跟随系统）与操作模式插在同一张设置卡片内、清除缓存之前，复用 `SettingsChoiceSlider` 的 190vp 三档表达；三档滑块一律用 `$$` 双向绑定（拖动连续跟随手指、松手才提交），与 Dashboard 振动强度滑块写法一致，材质等级滑块也用镜像值做到同样效果。

### 华为账号

`services/account/AccountService.ets` 使用 Account Kit 的 `authentication`（`HuaweiIDProvider` / `AuthenticationController`）获取本机可离线使用的 OpenID / UnionID，只保存标识与昵称占位，不保存 authorizationCode / idToken。未在 AGC 为当前包名与签名开通 Account Kit 时系统返回 1001500001，界面按错误码给出可读提示且不写入登录态。云空间云同步尚未实现，设置页只显示「暂未开启」说明，不做假入口。

### 设置分割线与宽屏布局

SettingsPanel 内部 0.5vp 分割线使用 Theme.divider / 同名 border，动作组内使用 Theme.groupDivider / v3_chart_grid，来自 Dashboard 对应浅深色资源。普通卡片边框继续使用 nd_card_border，不复用为设置分割线。

SettingsPage 在 840vp 以上直接复用 Dashboard MyPage 的左右布局：左侧应用图标、名称与版本固定，右侧账号、数据、设置与帮助单独滚动；左右权重 4:6、间距 16vp、最大内容宽 1440vp。较窄窗口保留原有单列顺序；末尾保留底部留白。这里只声明源码实现，运行验收见 VALIDATION。

首页与设置通过 DashboardSplitLayout 共用该分栏：840vp 断点、4:6 权重、16vp 间距、1440vp 上限、14vp 两侧边距都从 Dashboard 保留。首页左侧问候、花费与当前计划固定，右侧活动、待办、最近照片独立滚动；左侧顶部 80vp，右侧 110vp，底部 96vp。问候恢复原版 26vp Bold + 14vp 资源欢迎文案。导航仍沿用参考工程的 Stack，页面内容响应式与导航分栏分别验收。

活动倒计时在 64vp 数字列中使用 16–32fp 自适应字号与 maxLines(1)，避免较远日期的数字折行；不限制系统字体缩放。[华为 Text 文档](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V13/arkts-common-components-text-display-V13)说明 minFontSize / maxFontSize 需与 maxLines 或布局约束配合。本机 SDK 的 text.d.ts 标注两者 since 7、SystemCapability.ArkUI.ArkUI.Full，无额外权限，满足最低 API 23。

Cos、活动、衣柜装备、时间轴以及角色 / 装备 / 照片详情的末尾留白统一为滚动内容中的 Blank，移除页面底部 padding。照片惰性列表首项和末项也使用 Column 中的 Blank；保留原有顶部距离，不调整卡片内边距。

settings-layout-test.sh 在临时工程副本中把不导出的 SettingsLayoutAbility 加入主模块，使用正式资源上下文与未启动业务服务的内存 AppState 渲染真实 SettingsPage / HomePage；测试结束自动恢复正式包。正式源码与正式 HAP 不包含该测试 Ability。320 / 378 / 920vp 画布在当前手机中缩放展示，用于验证窄屏换行、普通行密度、左右滚动隔离，以及首页宽窄切换和末尾留白；这不等于真实平板、折叠、多窗安全区验收。

首页准备、打包与选片待办统一使用 TaskLinkCard，内部复用 InteractiveCard 的 0.985 按压缩放、130ms 弹簧、按压阴影 / 点光源 / HDR 隔离和点击触觉；最近照片也走相同卡片封装，与衣柜照片一致。页面只提供标题、详情与原任务视图路由，不再在待办 Button 或照片 Column 中维护另一套外观或振动。未完成圆圈用 Icons.pending（sys.symbol.circle），尾部箭头用既有 Icons.chevronRight，装饰图标不参与读屏。circle 名称已核对本机系统资源索引，正式编译确认 symbol 类别。

五个主页和设置根容器使用原版 scrollByAxis，把纵向输入转发到各页已有 Scroller。设置宽窄布局共用同一 Scroller，首页宽屏时转发到右侧滚动内容；不把导航、标题栏、分段或底栏纳入滚动容器。真实触控板与 2in1 体验仍须硬件验收，测试注入的鼠标事件不替代实机设备形态验证。

外观 / 操作模式的 SettingsChoiceSlider 标签保留 Dashboard 的 12fp、40 / 64vp 宽度和 190vp 控件宽度，允许最多两行。默认字号仍是一行；两倍字号时完整显示四字档位，与原版振动 / 材质标签的自然换行一致。禁止通过缩小字号或锁定字体倍率隐藏裁切。

大字体组件测试仅在隔离主模块中调用 ApplicationContext.setFontSizeScale(2)，由 Text 探针高度确认实际缩放，再检查卡片边界与四字标签的两行高度。测试恢复到 1 并停止测试进程，不修改系统字号或 app_storage；这一证据不代表系统字体跟随、原生导航大字体与全部业务页面已经验收。
