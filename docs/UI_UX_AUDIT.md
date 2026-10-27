# UI/UX 审计与整改建议

基线：**1.0.0-beta.1（10000001）**，源码 `38e97f6`（2026-10-08）；审计：2026-10-27。本文是**只读审计**的结论与建议，未修改任何界面代码。

证据分三类：源码 `file:line`、真机截图（`.shots/` 2026-10-07；`docs/validation/` 2026-10-07/08）、量化统计（字号/圆角/间距/对比度）。**截图与代码有漂移**（详见附录 B），凡冲突一律以代码为准；本文结论均可在当前工作区按行号复核。

---

## 0. 结论

配色和 HDS 外壳不是问题，甚至优于多数个人项目：五组浅深配色全部资源化、正文对比度 11.6–16.3:1、按压/材质/无障碍标签都有体系。**让人觉得"糟糕"的是三件事叠在一起**：

1. **没有视觉系统，只有散装样式。** 字号 185 处 / 18 档 / 0 个 token；圆角 11 种；间距 13 种 gap；图标来自 4 套体系，另有 41 处用 `＋ − ✓ ○ › ★` 文字符号冒充图标；"分组标题"有 4 套写法。同一角色的值不收敛（详情标题 19/20/21/23，列表正文 13/14/15/16/17），于是**每页都差 2vp，拼在一起就是"不是一套东西"**。
2. **层级读不出来。** 浅色卡片面/页面底 1.05:1、卡片描边 1.29:1、输入框填充 1.05–1.17:1；深色 `surface` 比 `bg` 更暗（1.11:1，方向反了），阴影用 40% 黑。界面只能靠阴影"隐约分层"，强光下糊成一片，深色下反而更平。
3. **交互反馈与保护仍是 demo 级。** 表单无草稿保护、无字段级错误；所有 Sheet 一律 LARGE；任何写操作都触发全屏 spinner + 2 秒 toast；详情底部的"动作栏"实际是 Tab 组件，删除和分享同级同色；空态与零值把新用户留在死端。

此外还有信息架构问题（首页 6 区块、Cos/衣柜/我的各装两类内容、详情页长列表），项目里已有一份**未执行**的 `docs/UX_RESTRUCTURE_PLAN.md` v2。但即使暂不做 IA 重构，上面三件事也能独立修掉大部分观感问题——**先补系统，再谈重排**。

---

## 1. 症状 → 根因

| 用户会怎么说 | 直接原因 | 证据 |
|---|---|---|
| "每页都差一点，不像成品" | 无字体/圆角/间距/图标 token | §2.1、§2.2、§2.3、§2.6 |
| "糊成一片，看不出几块内容" | 容器边界 1.05–1.29:1；深色层级反转 | `Surfaces.ets:27-28`、`base/color.json:5/11`、`dark/color.json:5/21` |
| "像 demo 数据没加载完" | 0/0、0%、¥0.00、0 B、单字占位图直出 | `ProjectCard.ets:50-63`、`LibraryPage.ets:63`、`ProjectDetailPage.ets:455-457` |
| "第一屏不知道能点哪" | 首页 3 个纯图标动作；待办行画成复选框却只能跳转 | `Dashboard.ets:387-404`、`TaskLinkCard.ets:17-24` |
| "主按钮在哪？" | 浅底胶囊按钮 44 处，实心主按钮仅 8 处；accent 文字 55 处 | `Theme.tint`/`Theme.accent` 统计见 §2.4 |
| "换主题像换了 App" | 五主题主按钮"白字/黑字"极性翻转；原生控件不跟主题 | `theme_colors.json`、`Theme.ets:69-82` |
| "深色模式更闷" | surface 比 bg 暗、阴影不可见、滑轨/次按钮消失 | `dark/color.json`、`.shots/90-dark.jpeg` |
| "开大字就废了" | 档位标签写死 40/64vp、行高写死 52–116vp | `settings-narrow-large-font-api26.png`、`SettingsChoiceSlider.ets:34` |
| "表单不敢填" | 下滑/点蒙层即丢输入；错误只弹 2 秒 toast | `FormEditor.ets:62-68,344-357`、`Dashboard.ets:543-547` |
| "删除和分享一样重" | 详情动作栏用 HdsTabs 渲染，5 项等权含删除 | `HdsActionTabs.ets:23-48`、`Dashboard.ets:462-466` |
| "滚动时标题和正文叠字" | HDS 半透明标题栏缺滚动 scrim（待复核材质档位） | `SystemCapability.ets:26-43`，`.shots/44-system.jpeg` 等 4 张 |

---

## 2. P0：先修，否则任何"美化"都是白费

### P0-1 全应用没有排版系统

- **证据**：`.fontSize(` 185 处，18 个不同值（8/10/11/12/13/14/15/16/17/18/19/20/21/24/25/26/30/32）；`Theme.ets:86-105` 只有布局尺寸，**0 个字号 token**。详情实体标题 4 个值（`EventDetailPage.ets:72`、`AssetDetailPage.ets:32`、`CosPage.ets:66`、`ProjectCard.ets:44`）；分组标题 4 套（`SettingsPage.ets:73-78`、`Surfaces.ets:47`、`SettingsPage.ets:91`、`DistributionChart.ets:110`）；26vp 同时是问候、统计数字和 `'›'` 箭头（`HomePage.ets:94`、`MePage.ets:53`、`CosPage.ets:69`）。
- **影响**：标题不压场、正文无节奏、小字（10/11vp）发虚；这是"说不出哪里不对"的第一来源。
- **修法**：落 7 级语义 scale（见 §4.1），`Surfaces.ets` 6 个公共组件先改，再按映射表批量替换；删除 8/10/11 三档。成本 M。

### P0-2 容器边界与深色层级不可读

- **证据**：浅色 `surface #FFFFFF` / `bg #F6F9FF` = **1.05:1**，卡片描边 `line #D8E4F2` / surface = **1.29:1**，输入框直接用 `Theme.bg` 填充（`Surfaces.ets:145/156`）= 1.05:1；深色 `surface #182231` 比 `bg #1A2B3C` 更暗（1.11:1），`shadow` 是 40% 黑（`dark/color.json:45`）。全仓"卡片"有 7 种处理：描边+阴影、只阴影、只描边、都没有（§2.4）。
- **影响**：一屏分不清"几组内容""哪块可点"；深色模式更闷、更塌。这是"糊成一片"的量化原因。
- **修法**：新增 `borderControl`（控件/输入 3:1）、`borderSubtle`（装饰卡边 1.5:1）、`surfaceRaised`（深色提亮到高于 bg）；输入改 `surface + 1vp borderControl`；阴影收敛为 2 级，深色改用明度表达层级。成本 M。

### P0-3 系统大字号（fontScale=2）下设置页崩坏

- **证据**：`settings-phone-large-font-api26.png`、`settings-narrow-large-font-api26.png` 中"关闭/灵动/硬朗""流畅/轻柔/精美"被拆成**单字竖排**，行结构塌陷；"缓存文件总大小：0 B"被右缘裁切。根因：`SettingsChoiceSlider.ets:34` 档位标签写死 40/64vp + `maxLines(2)`；`SettingsPanel.ets:645-694` 的清缓存行两侧文本无 `layoutWeight`；行高写死 52–116vp（`SettingsPanel.ets:354/477/597/632`）。
- **影响**：开大字号（长辈模式/无障碍）后设置页不可读、不可操作，属硬性无障碍缺陷。另：`docs/UI_STYLE.md:35` 写"实际两倍应用字号已验证完整显示"，与截图不符，建议改为"可读性验证"并补 2× 回归资产。
- **修法**：固定宽高改 `constraintSize(minWidth/minHeight)` 或自适应；档位标签宽度按 `fontScale` 派生；≥1.5 倍字号切换"标签在上、控件在下"；`maxLines(1)` 只留给可省略值；补 2× 字号回归截图。成本 M。

### P0-4 表单会丢数据，且错误无法定位

- **证据**：`FormEditor.ets:62-68` 关闭按钮只在 busy 时禁用，无脏检查；`common/sheet.ets:11-23` 用 `SheetOptions` 但未用 `shouldDismiss` 守卫，下滑/点蒙层/返回直接关闭；`Dashboard.ets:131-137` 每次 `edit()` 新建 `EditDraft`。校验失败只 `reportError` → 2 秒 toast（`FormEditor.ets:40-50`、`Dashboard.ets:543-547`），`Field` 没有 error 参数（`Surfaces.ets:131-165`），错误不会标在字段上，也不会滚动定位。活动表单 12+ 个控件。
- **影响**：一次误触丢数分钟输入；保存失败不知道哪一项错，只能逐项猜。
- **修法**：① `EditDraft` 加脏检查快照 + `shouldDismiss` 守卫，脏时确认"放弃本次填写？"，保存中禁关；② 本地草稿存 Preferences，再开可"继续填写"；③ `Field/Select/DateField` 增加 error 态（danger 文案 + 1vp 边框），保存前定位首个错误；④ toast 只留系统级失败。成本 M。

### P0-5 详情动作栏把"删除"做成了同级 Tab

- **证据**：`HdsActionTabs.ets:23-48` 用 `HdsTabs` + `BottomTabBarStyle` 渲染动作，全部 `Theme.ink` 同色；`Dashboard.ets:462-466` 计划 5 项（准备任务/从衣柜/编辑/分享/**删除计划**），`468-470` 角色页"新建计划"和"添加版本"共用同一个 `+` 图标；读屏语义是 tab，`scrollable(false)` + 72vp/项，大字号会截断。
- **影响**：破坏性操作与普通操作等权、常驻可点；用户把"编辑/分享"当导航点；角色页两个"+"无法区分。
- **修法**：底栏只保留 1 个当前视图主操作 + 1 个"更多"；编辑/分享/删除进标题栏菜单，删除用 danger 色并分隔；两个"+"换语义图标。成本 M。

### P0-6 空态死端与零值直出

- **证据**：`LibraryPage.ets:111-114`、`MePage.ets:108`、`PhotoGrid.ets:158-163` 三处空态只有文案没有按钮，添加动作只在标题栏纯图标里；空态卡塞在 `Scroll` 普通流里，不居中（`.shots/46-events.jpeg` 内容止于 29% 屏高、`.shots/04-me.jpeg` 止于 53%）；`ProjectDetailPage.ets:232-241/455-457` 直出 `0 / 0 件`、`0%`、`预计预算 ¥0.00`；`LibraryPage.ets:63` 无条件显示 `¥0.00`。
- **影响**：新用户在衣柜/作品集/时间轴无路可走；"0 值"被当成内容主角，形成"没做完"的第一印象。
- **修法**：抽 `EmptyStatePage`（不足一屏垂直居中：图标/标题/说明/主动作）；三处补 CTA；零值/空值统一"未记录/暂无"，不显示 0；`PhotoGrid` 筛选空态补"清除筛选"。成本 S–M。

### P0-7 首页待办不能完成，也看不到全部

- **证据**：`TaskLinkCard.ets:17` 每行以 20vp 空心圆开场（`Icons.pending = sys.symbol.circle`），整卡点击只跳详情（`HomePage.ets:180-204`），而 `togglePreparation/toggleChecklist` 已有真实回写；`HomePage.ets:176-206` 把待办截成 2+3+2 条，无总数，全仓无"查看全部待办"。
- **影响**：用户第一反应是点圆圈"勾掉"，结果被带离当前页；第 8 项之后的逾期任务在任何根页面都不可达——核心行动队列失效。
- **修法**：左 40vp 做真勾选（成功后行内反馈、失败行内重试），其余区域跳详情；`SectionHeading` 加"共 N 项 · 查看全部 ›"，落到最小完整待办页（逾期 → 今天 → 7 天内 → 未定期）。成本 M（聚合可复用现有三类筛选）。

---

## 3. P1：明显拖累品质

| # | 问题 | 关键证据 | 修法 |
|---|---|---|---|
| P1-1 | **强调色过载、主次倒置** | `accent` 作文字 55 处、`tint` 浅底按钮 44 处、实心主按钮仅 8 处（§2.4）；`ProjectDetailPage` 一页 14 处 accent 文字 | 定颜色分工：ink 主文字 / muted 次文字 / accent 仅链接与选中（≤3 处每屏）/ 主按钮 brandSolid；分组标题改 overline |
| P1-2 | **五主题主按钮极性翻转、原生控件不跟主题** | 蓝主题白字，绿/粉/橙/红黑字（`theme_colors.json`）；非蓝 brand 对白卡仅 1.86–2.39:1；标题栏钉死 `sys.color`、`DatePickerDialog/AlertDialog` 仍是系统蓝；蓝主题保系统默认强调色，与应用蓝 #1E6FCD 并存，"两个蓝"反而最明显 | 拆 `brandSolid/onBrandSolid`（用现成 accent 值 + 白字）；blue 也注入 nativeTheme；原生弹窗统一封装传色；底栏显式 labelStyle |
| P1-3 | **状态无语义色** | `StatusPill` 只有 label（`Surfaces.ets:90-103`），7 个调用点全部 accent-on-tint；danger 与红主题 accent 对比 1.07:1、warning 与橙主题 1.08:1 | 加 `tone`（neutral/info/success/warning/danger）+ 固定状态色；危险色不依赖主题色 |
| P1-4 | **图标 4 套体系 + 41 处文字符号** | `Icons.ets:13-58` 混用 sys.media（11）/sys.symbol（4）/app.media（21）；`＋`20 处、`−`7 处、`✓○`5 处、`›`4 处；底栏图标语义错位（Cos=人脸、活动=时钟、衣柜=抽象矩形） | 统一一套线性图标（启用零引用的自绘 SVG 或全换 sys.symbol）；`＋−✓○›★` 全部换图标；底栏重画语义；图标 16/20/24 三档 |
| P1-5 | **触控目标 <44vp（12 类 / 20+ 处）** | Sheet 关闭 36、色板 34 宽、帮助图标 22/24、默认按钮 40、日历格窄屏 38.3、滑块档位 40×17 | 统一 `touchMin=44`；色板 5 个 44 且间距≥8；行内动作容器 44 |
| P1-6 | **反馈体系：全局 spinner + 2 秒 toast，无行级状态** | `ApplicationState.ets:249-258` 所有写入共用 busy + 全量 refresh；`Dashboard.ets:548-552` 全屏 spinner；`reportError/notice` 同通道；振动/材质滑块失败不回滚（`SettingsPanel.ets:381-408/504-535`） | 操作返回 `{ok/failed/savedNotRefreshed}`；行内 pending/failed/重试；错误常驻条；刷新失败单独表达；滑块失败回滚 |
| P1-7 | **标题栏纯图标动作、语义静默变义** | 首页 3 个图标（+ / 时钟 / 相册，`Dashboard.ets:387-404`）；Cos/衣柜的"+"随分段变义；project 详情标题为空、其他详情有标题（两套模式） | 收成一个"+"打开带文字的动作面板；分段上下文在标题旁显示动作文字；详情标题栏统一 |
| P1-8 | **首页 6 区块 + 财务行 + 计划卡四重进度** | `HomePage.ets:91-235`：问候 26 + 全宽"花费统计 ¥0.00" + 计划卡（pill + x/y + 25vp % + 进度条）+ 两按钮 + 下一场活动 + 下一步 7 条 + 最近照片；计划卡内无日期 | 按 v2 §4.1 三块重排；财务行降为摘要文字；`ProjectCard` 只留完成数 + 日期，进度条仅 >8 项；问候降级 |
| P1-9 | **详情页长列表无概览/分段，标题重复** | 计划"准备"段含进度卡/任务/装备/参考图/团队/花费（`ProjectDetailPage.ets:539-551`）；角色/活动/装备详情标题栏与正文各写一次名字；`EventDetailPage.ets:144` 文案指向"标题栏的新建计划"，实际在底栏 | 按 v2 §3.8/§4 加概览与分段；正文首块改紧凑 meta 行；修正文案 |
| P1-10 | **设置页单卡混装 + 滑块术语** | `SettingsPanel.ets:261-327` 一张卡塞用户名/振动/材质/主题/外观/操作模式/清缓存；分组标题统一 14 Bold accent；"灵动/硬朗""流畅/轻柔/精美"无解释 | 拆"个人资料/外观与反馈/存储"；分组标题改 overline；两个滑块加"?"说明与当前档位文字 |
| P1-11 | **筛选双轨、语义混装** | 标题栏分段 + 页内 `Select` 并存（`EventsPage.ets:70-78`、`CosPage.ets:92-98`）；"进行中/已完成/日期待定"互斥混在一个下拉；日历模式丢筛选与计数 | 一级筛选统一到标题栏分段；状态与日期分离；日历模式显示当前范围与清除 |
| P1-12 | **宽屏分栏错位、比例失衡** | `DashboardSplitLayout.ets:22-28` 左栏 `justifyContent(Center)`，左列垂直居中、与右列起点差约 60px；4:6 宽度下右列挤 3 个区块；其余四个根页不分栏 | 左栏顶部对齐、5:5 或 42:58；左右各自滚动；≥1200vp 多列；先用真机平板复核再定 |
| P1-13 | **删除确认不点名对象，删计划清空整个返回栈** | `Confirm.ets:6-18` 无对象名；`Dashboard.ets:154-159` 删除 project/character 后 `detailStack.clear()` | 确认标题带对象名与真实数量（N 个清单项/照片/花费）；只弹出失效路由，保留父级上下文 |
| P1-14 | **标题栏滚动重影（待复核）** | 设置页滚动后上一行模糊透出并与标题/返回钮叠压（`.shots/33/44/81/90`）；`SystemCapability.ets:32/39` 标题栏背景透明 + `enableScrollEffect: false` | 加随滚动 0→1 的底色 scrim；或内容顶部加等高不透明渐变；先对比三档材质复核是否预期 |

---

## 4. P2：打磨清单

| # | 问题 | 证据 | 修法 |
|---|---|---|---|
| P2-1 | 分段选中态 1.19:1，几乎不可见 | `segmented_color_selected #22666666`；选中文字色未传（`HdsTitleBarSegment.ets:44`） | 选中文字 accent + 胶囊 tint + 1vp 边；或加粗 |
| P2-2 | 卡片层级 7 种、border+shadow 叠层 | §2.4；`InteractiveCard` 同节点叠 border+shadow+visualEffect+HDR | 收敛 L1 内容卡（surface+borderSubtle）/ L2 浮层卡（surface+elevation2） |
| P2-3 | 动效约 1–1.3s 且不响应"减少动效" | `motion.ets:26-42`、`constants.ets:22-26`；全仓 0 处 reduce-motion；照片卡内外两层按压 | 接 `isAnimationEnabled`；stagger 降到 2 组/60ms；去嵌套双反馈 |
| P2-4 | 图表格式与配色 | 轴 18624 无 ¥/无千分位（`InteractiveLineChart.ets:378-391`），正文 ¥x.xx，第三套格式；浅色下第一系列用浅 brand（1.86–2.39:1） | 统一 `formatMoney`；轴取整到 1/2/5×10ⁿ + 单位；新增固定 6 色 chart_series；选中行加"选中"样式 |
| P2-5 | 日历月份不居中、42 格像键盘 | `EventCalendar.ets:23-54` 行内"‹ 月 › 今天"导致月份左偏；每格 48vp 圆角 14 带底色 | 月份与箭头单独居中；日期格去底色；事件点加大或改底部短横 |
| P2-6 | 设置身份块占首屏、清除缓存 0 B | `SettingsPage.ets:150-179` 96vp 图标 + 26vp 名 + 16vp 英文；`SettingsPanel.ets:645-694` 0 B 直出 | 手机端压到 48–56vp 或移入"关于"；0 B 显示"暂无缓存" |
| P2-7 | 日期三种格式、倒计时无上限 | ISO（`HomePage.ets:78`）/ 中文拆列（`EventsPage.ets:45`）/ `2026.10.07`（`format.ets:10`）；"26663 天后见" | 新增 `formatDateLabel`；>365 天显示日期或"明年" |
| P2-8 | 返回/滚动恢复被动、分段共用 Scroller | 全仓无偏移存取；`Dashboard.ets:110-124`；切换分段不 `scrollTo(0)` | 显式保存每 Tab/每段偏移；分段切换回顶；搜索词按段拆分 |
| P2-9 | Sheet 一律 LARGE | `common/sheet.ets:10`；帮助/3 字段表单下半屏全空 | 按内容选 MEDIUM/LARGE；短表单 MEDIUM |
| P2-10 | 读屏 role/键盘 | `accessibilityRole` 5 处、`onKeyEvent` 0；设置行父子重复朗读 3–4 层 | 可点节点补 role；父级 group + 子级 no；卡片支持 Enter/Space |
| P2-11 | 缩略图 fallback 像图裂；照片一律 4:5 | `ProjectCard.ets:26-39` 单字 + Lighter；`PhotoGrid`/首页强制 0.8 比例 | 剪影/相机占位 + 字母角标；网格保留比例裁切但详情可看全图 |
| P2-12 | 空态缺口与孤立标题 | 角色版本 0、花费分类、装备复用计划只有标题 | 抽 `SectionEmpty`；"出现标题必须有空态分支" |
| P2-13 | topInset 三套常量 | 100 / 90 / 112（`constants.ets:134-136`），与 HDS 标题栏高度无推导 | `PageScaffold` 从实际标题栏 + 安全区推导 |
| P2-14 | token 命名与死资源 | `diff_content` 当 brand、`v3_chart_grid` 当分割线、`scrim` 0 使用、11 个 SVG 零引用且写死 `#598C72` | 归一命名；启用或删除死资源；`start_window_background` 对齐 bg |

---

## 5. 设计系统处方（可直接落地）

### 5.1 字体（7 级）

| token | vp | 字重 | 行高 | 用途 |
|---|---|---|---|---|
| `fontDisplay` | 32 | Medium | 40 | 首页倒计时/活动日期（每屏至多 1 处） |
| `fontTitle` | 24 | Bold | 32 | 页面主标题/统计大数 |
| `fontHeading` | 19 | Medium | 26 | 详情实体标题/Sheet/图表标题 |
| `fontSubheading` | 16 | Medium | 22 | 卡片标题/设置行/空态标题 |
| `fontBody` | 14 | Regular | 21 | 正文/值/按钮 |
| `fontLabel` | 13 | Regular | 19 | 表单标签/次级正文 |
| `fontCaption` | 12 | Regular | 17 | 元信息/状态药丸/说明 |

分组标题 = `fontCaption` + Medium + `letterSpacing 0.3`（overline）；删除 8/10/11vp。数字用 Medium 而非 Lighter——Lighter 只保留在真正的 hero 数字（32），25vp 的"进度百分比"降为 16/20 内联。

### 5.2 间距 / 圆角 / 层级

- 间距：4 网格 `4/8/12/16/24/32`；`pagePadding 14→16`、`sectionSpacing 14→16`、`cardPadding 16`；去掉 5/7/11/18/20 奇数档。
- 圆角 4 档：`radiusSm 8`（徽章/chip）、`radiusMd 12`（输入/卡内媒体）、`radiusLg 16`（卡片/面板）、`radiusFull 999`（药丸/头像）；禁止再写 14/18/20/22。
- 层级 2 档：L1 内容卡 = surface + `borderSubtle` + 无阴影；L2 浮层/可点卡 = surface + `elevation2`；深色用 `surfaceRaised` 明度表达，不用 40% 黑阴影。

### 5.3 颜色语义（在现有 12 键上扩展）

| 新增 token | 用途 | 建议值（浅色，均按 WCAG 计算） |
|---|---|---|
| `borderControl` | 输入/控件边界 3:1 | 蓝 `#5D97DB`、绿 `#5CA287`、粉 `#CF7C9A`、橙 `#BB8C5F`、红 `#CC7E8A` |
| `borderSubtle` | 装饰卡边 1.5:1 | 蓝 `#C8D4E1`、绿 `#BBD9CB`、粉 `#ECC7D5`、橙 `#E3CEB7`、红 `#EBC8CB` |
| `brandSolid` / `onBrandSolid` | 实心主按钮（避免极性翻转） | 直接用现有 accent 值（`#1E6FCD/#167A54/#B63866/#995310/#B33E50`）+ 白字 |
| `surfaceRaised` | 深色浮起面（高于 bg） | 蓝 `#233A50`、绿 `#284740`、粉 `#4B3444`、橙 `#483A2C`、红 `#4C363A` |
| `statusInfo/Success/Warning/Danger/Neutral` | 状态（跨主题固定） | 文字色 + 10% tint 底，对比 4.6–4.8:1（见审计报告 §4） |

规则：`accent` 只用于链接/选中/可点文字（每屏 ≤3 处）；大数字改 `ink` 或 `brandSolid`；`danger/warning` 不随主题变化，且不单靠颜色（配图标与文字）。

### 5.4 图标 / 触控 / 动效

- 图标：一套线性图标（`sys.symbol` 或启用修复现有 SVG 的 `currentColor`），尺寸 `16/20/24` 三档；`＋ − ✓ ○ › ★` 全部替换；底栏重画语义（首页=房子、计划=角色/计划、日程=日历、衣柜=衣架、我的=人像）。
- 触控：可点目标 ≥44vp（HOS 建议 48）；色板 5 个 44 且间距 ≥8；Sheet 关闭 44；帮助图标外扩命中区。
- 动效：页面入场最多 2 组、间隔 60ms；接系统"减少动效"；可点卡内不再嵌套第二层按压反馈。

---

## 6. 整改批次（依赖明确）

| 批次 | 内容 | 预估 | 依赖/风险 |
|---|---|---|---|
| **A. 令牌与硬伤** | 新增 Type/Spacing/Radius/Elevation/Touch token；输入框改 `surface+borderControl`；`brandSolid` 替换 8 处主按钮；深色 surface 提亮 + 补 `dark/media/question.png`；分段选中色；blue 注入 nativeTheme；10/11vp 升 12 | 1–2 天 | 低风险，不动结构；先落 token，后续所有改动依赖它 |
| **B. 交互止血** | 表单脏检查 + `shouldDismiss` + 本地草稿 + 字段错误/滚动定位；详情动作栏 1 主操作 + 更多（删除进菜单）；首页待办真勾选；`EmptyStatePage` + 三处死端 CTA；行级 pending/failed | 3–4 天 | 依赖 A；`FormEditor`/`HdsActionTabs`/`Dashboard` 与 C 有文件交集，需串行 |
| **C. 页面重排** | 首页三块 + 财务行下沉 + `ProjectCard` 去重（含日期）；详情页概览/分段（计划/角色/活动）；设置页拆卡与滑块说明；筛选统一；图标替换 + Tab 图标；宽屏对齐/比例（真机复核后） | 5–8 天 | 依赖 A、B；`ProjectCard`/`Surfaces` 会被改两次，勿在 B 前动 |
| **D. IA 重构（可选，下一步）** | 按 `docs/UX_RESTRUCTURE_PLAN.md` v2：入口改 计划/日程/衣柜/相册、首页三块定稿、收录原语、今天模式 | 1–2 周 | 依赖 C；不要先于 A/B/C |
| **E. P2 打磨** | §4 的 14 项 + 图表/日历/Sheet/读屏/日期格式/死资源 | 2–3 天 | 可分散在 A–C 之间 |

**不建议**：只调配色/动画/圆角（截图 91/93 已证明材质与主题本身没问题）；或在 A/B 之前重写 `ProjectCard`/`EmptyState`/标题栏（会返工两遍）。

### 验收建议

- 每批：`./scripts/build.sh` 通过即可（默认档，不跑设备套件）。
- 静态门禁：`grep -c '\.fontSize([0-9]'` 只剩 token 引用；`grep -c 'borderRadius([0-9]'` = 0；`grep -rn "Text('›')"` = 0。
- 扩展 `python3 scripts/test_theme_colors.py`：为每套 palette 校验 `borderControl` ≥3:1、`onBrandSolid/brandSolid` ≥4.5:1、状态色 ≥4.5:1。
- 新增截图资产：设置页 2× 字号、详情动作栏 2× 字号、空库各页、五主题主/次按钮并排、宽屏真机整页。
- 若要做交互回归（批次 B 后），只选一个直接相关设备套件（建议 `settings-layout-test` 或 `ui-polish-test`），不叠跑。

---

## 附录 A：值得保留的底座

1. HDS 原生外壳方向正确：HdsNavigation/HdsTabs 材质、浮动栏、覆盖式详情、返回振动统一（`DetailDestination.ets`、`HdsMiniBarButton.ets`）。
2. 颜色 100% 资源化：全仓 `.ets` **0 个 hex 字面量**，五组 × 浅深 68 个键在 `resources/{base,dark}`；主题切换即时生效。
3. 文字对比度达标：正文 11.6–16.3:1、次级 4.51–8.97:1、按钮字 4.99–7.83:1（仅 4 个临界项需微调）。
4. 公共组件雏形已存在：`InteractiveCard/SectionHeading/EmptyState/StatusPill/FactRow/Field`，改 token 只需动这 6 个即可覆盖大部分页面。
5. 按压/动效参数集中（`pressFeedback.ets`、`motion.ets`、`visualEffects.ets`），没有散落魔法数。
6. 读屏基础扎实：172 处 `accessibilityText`、装饰元素 `accessibilityLevel('no')`、分段与日历有播报。
7. 空态文案有性格（"让每一件装备有归处""每一张，都是一次登场"）——问题在位置与 CTA，不在文案。
8. 宽屏不是从零开始：Home/Me/Settings 已有 4:6 分栏，`PhotoGrid` 已按宽度 2/3/4 列，只差统一策略与对齐。

## 附录 B：证据边界

- **代码基线** `38e97f6`（2026-10-08）。工作区仅 `.DS_Store` 改动，审计期间未改源码。
- **截图滞后**：`.shots/*` 拍于 2026-10-07 00:xx，比代码旧约 26 小时。已知差异：项目卡首卡从"0%/0 件装备可用"改为"准备进度"（`ProjectCard.ets:50-63`）、"漫展"改"活动"（`constants.ets:107`）、活动页从标题栏三段改为"列表/日历"（`Dashboard.ets:503`）、设置页"应用外观"拆成主题配色 + 外观（`PreferenceSettings.ets:20-60`）、"云同步在路线图中"改为"尚未接入"（`SettingsPage.ets:196-204`）、版本号 1.0.0 → 1.0.0-beta.1。**凡与当前代码冲突，以代码为准。**
- **测试台截图**：`docs/validation/home-wide-*`、`task-axis-*`、`settings-narrow*`、`settings-wide*`、`settings-*-large-font*` 来自 ohosTest 布局测试台（顶部有"窄屏/手机/宽屏/设置/首页"调试按钮，页面渲染在 320/378/920vp 画布内再缩放裁切）。画布外空白是测试台背景，**不是应用缺陷**；画布内的错位/拆字/裁切是真实组件行为。
- **排除证据**：`.shots/60-dashboard*` 是 Dashboard 参考工程、`.shots/94-state.jpeg` 是系统锁屏、`docs/validation/device-calendar-confirm-api26.png` 是系统日历页；`theme-palettes-api26.png` 是控件参考页（非产品页面），仅用于五主题对照。
- **待复核**：宽屏分栏结论来自 920vp 测试画布，生产平板/折叠屏需真机整屏截图；标题栏重影需对比三档材质；五主题主按钮极性需真机页面截图；`Select` 弹层与日期选择器的实际渲染色以系统实现为准。

## 附录 C：审计明细

本次审计由 4 个只读并行审计 + Lead 复核组成，原始明细（含每条 file:line、截图、成本）：

- 一级页面与主页面组件：21 条（P0×3 / P1×12 / P2×6）
- 详情页/表单/设置：24 条（P0×3 / P1×13 / P2×8）
- 视觉系统/主题/无障碍：20 条（P0×2 / P1×9 / P2×9），含五主题 × 浅深对比度表与令牌清单
- 截图渲染审查：26 条（P0×3 / P1×11 / P2×12），含证据口径校正

本文是它们的去重、复核与优先级收敛结果；原始报告位于工作区 `.audit/`（未纳入版本控制，可随时删除或重新生成）。
