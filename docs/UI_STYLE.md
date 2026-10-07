# 界面实现参考

版本基线：**1.0.0-beta.1（10000001）**；文档核对：2026-10-08。现状与历史证据；最终构建、签名与交付结论见 [打包记录](RELEASE.md)。

本文记录当前设计来源与实现位置，供修改相关页面时查阅。它不冻结交互、参数或组件选择；后续任务以用户的当次要求和实际效果为准，无需为调整历史方案额外请求确认。

## Dashboard 参考

本轮参照 `/Users/raychen/Develop/Dashboard/dashboard-HarmonyOS` 的工程组织、HDS 导航、偏好管理和公共工具。ElvaCos 独立维护，运行时不依赖该路径。

| Dashboard 来源 | ElvaCos 接入 | 当前用途 |
|---|---|---|
| pages/Dashboard | pages/Dashboard、SystemCapability | 五个 Tab、标题区、导航与滚动状态 |
| HdsMiniBarButton、HdsTitleBarSegment | component 下同名组件 | 浮动栏、分段、材质与按压反馈 |
| common/vibration、visualEffects、motion、scroll | common 下对应工具 | 触觉、光场、入场、鼠标与触控板滚动 |
| SettingsPanel、DiskStorage、storage | component / common | 用户名、材质、振动、偏好持久化 |
| MyPage MoreRow | SettingsActionRow | 设置入口与 HDS 图标/控件列 |
| AppsPage commonHeader | DashboardSearch | 搜索外观与反馈 |
| base/dark color.json | 同名资源、Theme | 浅深色解析 |
| AppLogPage、LocalHtmlPage | pages/more 下对应页面 | 版本记录与本地隐私正文 |
| charts/InteractiveLineChart、OverviewSection DistributionPanel | component/charts | 月度花费折线、照片状态环形分布、Canvas 动画与选点/图例反馈 |

## 当前页面与交互

主页五个 HdsTabs 各有独立 HdsNavigation / NavPathStack；外层主栈承载覆盖式详情和设置。详情显示时隐藏主页底栏，业务详情保留 HdsActionTabs 动作栏；更新日志与政策为阅读页。更新日志标题栏提供 Beta / RC / 正式版三个独立开关，复用 Dashboard 的开启/关闭图标、Toast 与触觉；包含空结果、正式版标识和卡片按压反馈，设置入口使用 app_log 图标。表单、关联选择、帮助使用 bindSheet 与 SheetHeader，删除/替换通过确认 Dialog。

标题分段使用原生 TabSegmentButtonV2，当前宽度为标题区的 50%。选中变化和重复点击分别处理，切换保留各页查询、滚动和路由上下文。页面承载多于一类内容家族时的分段设计（哪些页面分段、分段与筛选的分工）见 [体验重构规格 v2](UX_RESTRUCTURE_PLAN.md) 第 3.8 节，尚未执行。

颜色由 base/dark 成对资源、ThemePalettes 和 Theme 提供，包含透明背景；图标通过 Icons 提供语义入口。主题配色可选蓝、绿、粉、橙、红，每组均有浅色与深色；应用外观独立选择浅色、深色或跟随系统。蓝色保留原资源值；新增配色采用薄荷绿、图标同色系樱花粉、杏橙、珊瑚红，明亮填充与可读强调文字独立。设置保存在 app_storage，沿用 sky / mist / system 外观值，新增 themeColor 缺省蓝色，写入成功后更新 AppStorage。根 WithTheme 同步原生控件强调色。方案与色值见 [主题实现](THEMES.md)。

## 响应式与阅读

首页与设置以实际容器宽高判断布局：宽度达到 840vp 且高度达到 600vp 时为 4:6 分栏，最大宽度 1440vp；较窄或较矮窗口为完整单列滚动。业务列表/详情最大宽度 1440vp，阅读和统计内容最大宽度 840vp。PhotoGrid 根据可用宽度选择 2/3/4 列；ReferenceGallery 保留横向图片预览。

设置普通行当前为 68vp，窄屏上下排布为 116vp；滑块宽度 190vp。档位文字允许换行，实际两倍应用字号已验证完整显示。原生花费条形图使用整数分计算比例，并支持分类筛选和取消筛选。

花费统计增加近半年月度趋势，按记账日期分组、以整数分累计后换算元，缺少记录的月份补零，随所属计划筛选变化。作品页增加全部照片的处理分布，包含已归档且各组互斥；作品列表仍只包含成片与已发布，筛选使用「全部作品 / 成片 / 已发布」。两处图表移植 Dashboard Canvas 的资源色、入场动画与交互，适配 V2 和 Theme，并在环境或配色变化后重绘。照片卡片的说明区左右 12vp、底部 14vp 留白。

安全区由 HDS 导航与标题参数协调，内容使用 Theme 中的顶部/底部留白。当前内层导航 titleBar 避让安全区，覆盖详情由 HDS 自身避让；历史上双重避让曾导致标题下移，调整时可参考这一原因，而不是固定沿用所有数值。

## 公共反馈与生命周期

InteractiveCard、PressFeedback、HapticService 和 motion 复用既有按压光场、0.985 缩放与 130ms 弹簧。流畅档关闭增强视效；HDR 在支持的 API/硬件上降级处理。页面和复用控件提供中文播报标签，筛选项包含选中状态，装饰元素退出读屏。

PressFeedback 的点光源和合成滤镜直接绑定可观察按压状态，AttributeUpdater 只负责触摸与缩放，避免通过属性更新器设置 HDS 光效时实机不显示。轻点保留至少 140ms，取消触摸立即复位。日历日期使用表面背景承接点光源。光效沿用 Dashboard pointLight，不额外叠加 pressShadow。PhotoGrid 保持稳定的数据源，通过 onDataReloaded 通知筛选、批量选择与列数变化，避免下拉框改变而懒加载照片仍显示旧内容。

主页与设置页入场记录由启动会话共享，每次进入应用只播放一次；其他详情按显示生命周期重播，Sheet 每次打开重播。设置页的 HdsListItemCard、列表分组容器及行内按钮/滑块/标签不绑定 PressFeedback 或额外 clickEffect，保留原生触摸与选择操作，避免事件冲突。Timer 和过期异步回写在退出时取消，握姿在后台/离开相关任务时停止。光场/HDR 的人工观感与其他设备体验尚未等同于自动化通过。

## 已遇到的实现问题

带参数的匿名 BuilderParam 回调直接构造组件曾在真机触发 `class constructor cannot called without new`。当前采用明确的 @Builder 绑定衔接 V1 设置与 V2 页面；这是已有 bug 的修复依据，不是要求今后所有回调都采用同一形式。

HDS 自定义卡片的外层 id 可能不进入 TestKit 组件树，且组件边界会被视口裁切。相关布局回归按实际文字逐段滚动，让完整行进入视口后检查高度。

当前 API 与设备验证来源见 [CAPABILITIES](CAPABILITIES.md) 和 [VALIDATION](VALIDATION.md)。后续按实际修改选择必要检查，不重复历史清单。

## Beta 打包核对

2026-10-08 以当前五 Tab、覆盖详情、Sheet、五组主题与两处 Canvas 图表作为 Beta 界面基线。Release 编译保留现有资源与反馈，不更换导航，也未执行正式版体验提案。页面冒烟与硬件视觉体验分别记录；构建警告及未覆盖设备见 RELEASE / VALIDATION。
