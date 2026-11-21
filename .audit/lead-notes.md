# Lead 独立核对笔记（外壳/跨页面/设计系统）

核对基准：git 38e97f6（2026-10-08 之后未再改源码），截图取 .shots 与 docs/validation（部分落后于代码，已在条目里标注）。

## A. 外壳与导航（Dashboard.ets）
1. **详情动作栏 = 用 Tab 伪装的操作栏**：`HdsActionTabs` 用 `HdsTabs` + `BottomTabBarStyle` 渲染 5 个动作（HdsActionTabs.ets:24-44），图标/文字颜色 selected = unselected = Theme.ink（:31-33）；"删除计划"与"编辑/分享"同级（Dashboard.ets:462-466）。视觉上像 5 个 tab，破坏性动作没有任何区分（无 danger 色、无菜单收纳）。截图：70-project.jpeg 底部。
2. **全应用级 busy 遮罩**：任何写操作 set `busy`（ApplicationState.ets:249-258），根导航覆盖居中 `LoadingProgress`（Dashboard.ets:548-552, 706），按钮全部 `.enabled(!busy)`；刷新是 13 个集合全量 reload（ApplicationState.ets:231-240 附近）。单次勾选任务也会让整页进入"转圈+禁用"。
3. **错误/成功都只走 Toast**：`reportError` → `error` → Dashboard `@Monitor` 弹 2s toast（Dashboard.ets:543-547）。表单保存失败、批量改照片失败没有就地错误位，2 秒后消失；用户无法知道哪一条失败。
4. **统一 LARGE Sheet**：`appSheetOptions` 固定 `SheetSize.LARGE`（common/sheet.ets:10）。改一条备注/勾一个字段也是接近全屏的 bottom sheet，内容常只占顶部 1/3，中部大片空白（41-formsheet.jpeg）。
5. **一级页标题栏动作不可发现**：首页标题栏 3 个纯图标（+ / 时钟 / 相册，Dashboard.ets:403），Cos/活动/衣柜各 1 个、我的 1 个齿轮；无文字、无 tooltip，跨页语义不同却长相相近（Icons.ets:17-20）。
6. **Tab 图标语义错位且三套图标体系混用**：Cos = `ohos_user_auth_icon_face`（人脸），活动 = 时钟，衣柜 = `rectangle_filled_and_line_horizontal_and_rectangle`（Icons.ets:17-21）；同时存在 sys.media 旧图标、sys.symbol 符号、app.media PNG 三套（Icons.ets 全文件）。
7. **一级页结构重复**：五个页面各自复制 `Blank(topInset) + Scroll + Column(padding) + 入场动画`（HomePage:243-268, CosPage:72-128, EventsPage:61-108, LibraryPage:76-123, MePage:72-118）。没有共享 PageScaffold，标题区/内容顶部留白只能靠页面各自维护。
8. **宽屏分栏利用率低**：DashboardSplitLayout 左侧 overview 垂直居中（DashboardSplitLayout.ets:26-30），右侧独立滚动；home-wide-start-api26.png 右栏内容结束后下半屏全空，左栏内容悬在垂直中央。
9. **项目详情标题栏特例**：project 详情标题传空串、分段塞进标题栏（Dashboard.ets:309-316），其他详情是"标题文字"；两套详情标题模式。
10. **返回/滚动恢复靠组件不销毁被动保留**，无显式偏移量；跨 Tab 返回位置未显式契约。

## B. 设计系统缺口（跨页面）
11. **字号无 token**：`fontSize()` 共 185 处、18 个不同值（8/10/11/12/13/14/15/16/17/18/19/20/21/24/25/26/30/32）；12/13/14 占 117 处；`ProjectDetailPage` 一页 28 处。Theme 只提供颜色/布局尺寸，没有字体层级（Theme.ets:78-106）。
12. **圆角无 token**：`Theme.cardRadius=16` 只用了 13 次，硬编码 radius 30+ 次、11 种值（4/5/6/10/11/12/14/16/18/20/22）。同一页里装备行 18、团队行 16、花费行 16、打包行 20（ProjectDetailPage.ets:381/441/483/535）。按钮是胶囊（默认），卡片 16，图片 14，输入框默认 —— 三种几何语言。
13. **"分组标题"有三套**：`SectionHeading` 15 medium muted（Surfaces.ets:42-55，43 处）；设置页 groupTitle 14 bold **accent**（SettingsPage.ets:73-78）；帮助 Sheet 16 medium ink。
14. **强调色过载**：`Theme.accent` 同时承担链接、次要按钮、状态药丸、分区标题（设置）、大数字（26/32）、进度百分比、图片占位首字。真正的实心主按钮只有 8 处 `Theme.brand`，而 `Theme.tint` 浅底按钮 44 处 → 满屏浅蓝药丸，主次不分。
15. **StatusPill 不区分语义**：所有状态（准备中/已完成/待维修/已借出/想买/门票待确认/已结束）同一个 accent-on-tint（Surfaces.ets:90-103），只能用文字读。截图 70-project 的"准备中"与"门票已确认"观感相同。
16. **阴影/描边叠两层**：InteractiveCard 同时 `border 1px + shadow(12, y3)`（Surfaces.ets:27-28）；EmptyState 只有 shadow(8)、设置卡片只有 shadow(8)；同层级容器 1-2 种做法。
17. **前景/背景分离度极低**：浅色背景 #F6F9FF / 卡片 #FFFFFF，卡片描边 1.29:1（#D8E4F2/白），border 1.51:1；阴影 10% alpha。层次几乎全靠阴影，强光/低质屏幕会"糊成一片"。
18. **非蓝主题主按钮极性翻转**：蓝色的 brand=#1E6FCD + onAccent=白；绿/粉/橙/红 brand 是浅色（#58C89B/#F391B5/#F2B16E/#EF8B96）+ onAccent=深色（theme_colors.json）。同一个"主按钮"组件在 5 套主题里一半白字一半黑字；且粉/绿/橙的 brand 与 tint 次要按钮同为浅色，主次对比消失（theme-palettes-api26.png 可直接看到）。
19. **accent-on-tint 处于临界**：蓝 4.52、绿 4.79、粉 4.80、橙 5.22、红 4.83；这些组合大量用于 12-13vp 状态药丸/链接/次要按钮，字号越小越吃力。
20. **深色阴影用 40% 黑**（#66000000，dark/color.json），深底上的卡片阴影是不可见的脏边；同时 dark 卡片面 #182231 比背景 #1A2B3C 更暗，只靠 1.28:1 描边分离。
21. **间距非网格**：pagePadding 14、sectionSpacing 14、卡片 padding 14/16/18/20/24 混用（constants.ets:140-144 + 各页 `.padding()`）；没有 4/8 节奏。
22. **图标三族 + 文字符号冒充图标**：`Text('›')`（HomePage:82、CosPage:69、AssetDetailPage:63）、`Image(Icons.chevronRight)`（TaskLinkCard:22）、HDS 原生 chevron（菜单）；`'★'`、`'＋'`、`'✓'`、`'○'`、`'−'` 直接当图标（ProjectDetailPage:312/300/336 等）。照片多选的选中态是文字 "✓ 已选 / ○ 点选"（PhotoGrid.ets:135）。
23. **照片比例写死 4:5**：ManagedImage `aspectRatio(ratio>0?ratio:loadedRatio)`，而 ratio 默认 0.8 永远 >0 → `loadedRatio` 是死代码（ManagedImage.ets:20-21,51）；横构图照片在网格/最近照片里被裁剪。
24. **最小字号**：10/11vp 用于"准备进度"（ProjectCard:62）、分类完成数（ProjectDetailPage:272）、照片所属计划（PhotoGrid:137）；12vp 用于状态药丸、页脚。

## C. 内容状态与文案
25. **零值直出**：`0 / 0 件装备可用` + `0%` + `预计预算 ¥0.00 · 装备记录金额 ¥0.00`（70-project.jpeg / ProjectDetailPage:222-241,455-457）；三处 KPI 数字同屏（MePage:51-66）。
26. **首页信息过载**：问候语 26 + 全宽"花费统计 ¥xxx"按钮（HomePage:100-114）+ 当前计划卡（三重进度）+ 两按钮 + 下一场活动 + 下一步（最多 7 条混合类型）+ 最近照片 —— 6 个区块（HomePage:100-235）。
27. **缺少"查看全部"**：首页"下一步"只截 2/3/2 条（HomePage:180,188,195），没有总数与入口。
28. **空状态有的没有动作**：衣柜空态（LibraryPage:111-114）无按钮；照片空态（PhotoGrid:158-161）无按钮；时间轴空态（MePage:108）无按钮。Cos/活动/首页空态有按钮 —— 不一致。
29. **中文/英文混排**：Tab"Cos"、标题"Cos"、设置"Elva Cos"、数据名 "Genshin family"；同屏出现"漫展/活动"两种叫法（旧截图 46-events.jpeg vs MAIN_PAGE_TITLES）。
30. **Toast 文案承担错误信息**（ApplicationState.ets:241-258），且 `perform` 返回 boolean 被丢弃在部分调用点 → 失败只闪 2 秒。

## D. 值得保留
- HDS 原生材质导航/浮动 Tab 栏方向正确；浅深色 + 五主题的资源化没走硬编码色值（全仓无 hex 字面量）。
- InteractiveCard 的按压光场/缩放统一封装、读屏 role/label、大字号 maxFontScale、宽屏最大宽度 1440、空态文案有性格（"让每一件装备有归处"）。
- 动效参数集中（motion.ets / constants.ets），未散落。
