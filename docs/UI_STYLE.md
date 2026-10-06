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
| pages/main/MyPage MoreRow | SettingsActionRow | HdsListItemCard、PrefixIcon、SuffixCustomBuilder、TextModifier、行高与边距 |
| component/SettingsPanel、common/DiskStorage、common/storage | SettingsPanel、DiskStorage、storage | 原版用户名、振动、材质、缓存顺序、滑块和卡片；单一 app_storage、内存缓存、旧偏好迁移 |
| pages/main/AppsPage commonHeader | components/DashboardSearch | 48vp 搜索框、背景、边框、130ms 弹簧按压；本应用内联筛选保留直接键盘输入 |
| resources/base、dark/element/color.json | 同名颜色资源、Theme | 直接复用相关底色、表面、文字、强调、边框、阴影与遮罩；不复制无关图表配色 |

主路由 HdsNavigation 覆盖完整主页；主页 HdsTabs 的五个 TabContent 分别承载独立 HdsNavigation/NavPathStack，详情压入主路由并使用 HdsNavDestination。Tab 切换保留各自导航位置；重复点击当前一级 Tab 使用参考工程的 300ms 滚动返回顶部。角色/计划、漫展筛选、装备/照片、作品/时间轴使用 HdsTitleBarSegment 包装原生 TabSegmentButtonV2，放在 titleBar.stackBuilder 的 50% 宽居中区域，尺寸沿用 Dashboard。标题栏、二级分段和浮动底栏保持固定，页面滚动只影响业务内容。各 TabContent 不对整块导航进行缩放或淡入动画。

“我的”标题菜单进入主路由的覆盖式设置 HdsNavDestination，隐藏主页 HdsTabs。设置第一组直接使用原版 SettingsPanel：用户名、支持设备上的振动强度、材质等级、清除缓存。原版光场行处于注释状态；工具继续使用持久化的 lightFieldLevel。外观与单手操作通过 SettingsPanel 的 additionalSettings builder 插入同一设置卡片、位于清除缓存之前，不再单独显示「操作偏好」分组；备份与帮助承载本应用功能；分组标题与卡片间距 8vp、分组间距 14vp，复用参考工程分组入场动画。列表分组间距、标题缩进和卡片圆角取自参考工程。

首页直接复用参考工程的时段问候、用户名/设备名回退、26vp 标题与 14vp 欢迎文字；欢迎文案中的品牌在资源中配置。

Icons 集中定义系统资源语义名称；新图标先确认本机 SDK 中的 media 资源类别与可用名称，不能把 symbol 名当作 media 名。详情操作栏的添加和封面使用 Icons 中的 SymbolGlyphModifier（plus / picture），以 sys.color.icon_primary 跟随深浅色；当前 HdsActionTabs 将其映射为 TabBarSymbol。照片与角色封面仍来自用户记录。

公共确认 Dialog 沿用 Dashboard LocalHtmlPage 的按钮颜色：取消使用 diff_content，确认删除或替换使用 v3_accent_red。均通过同名浅/深色资源解析，不在 Confirm 中保存另一套十六进制颜色；取消与确认的行为保持原有数据保护约定。

设置使用 Dashboard 的单一 Preferences 文件 app_storage；DiskStorage 按文件维护实例及内存缓存，写入 flush 成功后同步同名 AppStorage key。EntryAbility 在 loadContent 前加载偏好。旧 settings 文件中的主题、触觉、材质、握姿等通过显式迁移保留，既有目标值优先；Preferences 不保存业务实体。SettingsService 将这套偏好映射到应用状态。

HDR 仅在 API 24+、用户选“高亮”且发生按压时尝试；已声明 HDR_BRIGHTNESS。API 23 自动使用明亮光场，设备不支持或调用失败时保留普通光场。HDS 材质直接使用 API 23 能力，无 ArkUI API 26 uiMaterial 依赖。真实亮度、触觉与设备能耗仍需硬件体验验收。

## 安全区与密度

窗口保留原生避让布局，HdsTabs 使用 height(LayoutPolicy.matchParent) 和系统顶部/底部 ignoreLayoutSafeArea 承载沉浸内容。标题样式沿用 Dashboard 的 originalStyle / scrollEffectStyle；本工程外层 Tabs、内层 Navigation 与参考工程层级相反，显式设置 avoidLayoutSafeArea=true 保证标题避开状态栏，自定义二级分段在标题栏固定区域。主页浮动栏宽为 min(360vp, 窗口宽−32vp)，barBottomMargin 28vp、透明渐变遮罩高 92vp。

详情覆盖主页并使用独立 HdsTabs 浮动操作栏，不再叠加主底栏和 toolbar；滚动内容保留 110vp 底距。详情操作栏按动作数采用 min(max(168vp, 动作数×72vp), 窗口宽−32vp)，复用相同材质与底距。顶部使用参考工程的 Blank(100vp) 与容器间距（首页、设置、详情 14vp，搜索列表 12vp）；底部首页 96vp / 列表 110vp 留白放在滚动内容内部。衣柜照片和作品集使用惰性加载的照片行列表，筛选/统计作为首项一起滚动，末尾留白保证内容能滚到浮动栏上方。设置 Scroll 从顶部排列，原版常规滑块卡片高 68vp，330vp 以下使用窄屏布局。

照片统一使用 ManagedImage：沙箱路径经 MediaRepository 转为 file URI，缩略图与原图都报告加载/错误状态。原图文件不存在时保留补回提示。

缓存操作由 MediaRepository 完成，仅访问 cacheDir；原图与缩略图位于 filesDir/media。测试使用 verification-* 隔离目录；清除缓存经过用户确认。

依据：[Tabs 安全区说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-1584)、[Navigation 自定义区域](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/ui-design-navigation-customized-area)。真机安全区和固定区域几何验收以 VALIDATION.md 中最新记录为准，源码对齐不等于视觉验收通过。

## 2026-10-06 用户交互修正

主路由覆盖主页，Tab 导航保留在主页内部。角色、项目、资产、漫展、照片详情和设置均为独立 HdsNavDestination；详情动作使用 HdsActionTabs，点击触发操作并拦截页签内容切换。所有新增和编辑使用 bindSheet。

设置的偏好行也使用 PrefixIcon / IconSize.SYSTEM_ICON，与原版 SettingsPanel、SettingsActionRow 共用前后边距。外观固定跟随系统并提供说明；单手控件复用 Dashboard 的 190vp 三档 Slider 和 12vp 标签，顺序为左手、智感握持、右手。行高 68vp，330vp 以下改为 116vp 的上下布局。帮助组使用原版 MoreRow 卡片格式，实际使用说明和数据说明通过 Sheet 阅读。

原生视效独立开关移除，流畅档统一关闭材质、按压光场和 HDR 增强；轻柔/精美开启对应等级。偏好升级保留此前关闭视效的意图，手动左右手关闭感知；中间档权限拒绝时保留原选择。

分段控件按参考文件分别处理 $selectedIndex 与 onItemClicked：切换只更新外部选中状态，点击通过同一 HapticService 提供反馈，重复点击当前分段也遵循原版行为。HdsMiniBarButton 仅裁剪内部内容，外层保留参考原样，不额外裁剪按压光场。公共卡片沿用 0.985 缩放与 130ms 弹簧参数。

业务提示统一从 Index 调用复用的 showToastSafely；AppState.reportError / reportNotice 为每次报告递增反馈版本，使相同提示能再次显示。FormEditor 将校验异常交给这一入口，不在内容区插入错误文字或维护另一套提示组件。

计划详情复用相同 HdsTitleBarSegment，在标题栏 50% 居中区域切换准备 / 打包 / 照片；计划名称保留在滚动内容首部。底部 HdsTabs 只显示当前视图相关动作。新建计划优先显示角色、计划名称和可选日期，扩展信息通过「更多设置」展开；所有新增/关联继续使用 bindSheet。
