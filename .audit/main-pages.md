# 绮秀 ElvaCos · 一级页面与主页面组件 UI/UX 审计

- 审计对象：原生 HarmonyOS / ArkTS / ArkUI Stage，API 26，HDS 组件；只读审计，不改源码。
- 源码基线：commit `38e97f6`（2026-10-08 02:57，`feat: 1.0.0-beta.1 界面重构、主题配色与离线示例`）；工作区仅有 `.DS_Store` 改动。
- 审计范围：`pages/Dashboard.ets`（Tab 栏 / 标题栏 / 分段 / 根级菜单 / 空状态 / 加载遮罩），`pages/main/{HomePage,CosPage,EventsPage,LibraryPage,MePage}.ets`，`component/{ProjectCard,TaskLinkCard,DashboardSearch,PhotoGrid,DashboardSplitLayout,EventCalendar,HdsTitleBarSegment,HdsMiniBarButton,Surfaces}.ets`；为理解令牌查看了 `common/{Theme,constants,Icons}`、`model/{Rules,Schedule,ApplicationState,Entities}`、`docs/UI_STYLE.md`、`docs/UX_RESTRUCTURE_PLAN.md` 第 0/2 章与相关页面规格。
- 产出格式：每条 finding 固定含「严重度 / 证据 / 现象 / 用户影响 / 具体修法 / 成本」，编号 `P0-x`、`P1-x`、`P2-x` 可在整改批次与规格冲突表中互相引用。

## 0. 证据口径（先读）

1. **截图比代码旧约 26 小时**：`.shots/*.jpeg` 拍摄于 2026-10-07 00:xx，源码改到 10-08 02:xx。截图与当前代码已知不一致处：
   - 计划卡右侧：截图写「0% / 装备可用率 / 0 0 件装备可用」，代码已改为「准备进度 / N / M 项准备完成」（`ProjectCard.ets:50-63`）；
   - Tab 标签：截图第 3 项「漫展」，代码为「活动」（`Dashboard.ets:660`，`constants.ets:107`）；
   - 活动页：旧截图为标题栏三段「即将 / 过去 / 想去」+ 时钟图标，代码改为标题栏「列表 / 日历」+ 内容区 Select（`Dashboard.ets:503`、`EventsPage.ets:70`）；
   - 「我的」：旧截图有大标题「属于你的舞台」，代码已删除并加入照片分布图（`MePage.ets:49-69`）。
   **下文以 file:line 为第一证据，截图只作布局/视觉证据并标注「旧截图」。**
2. `.shots/60-dashboard.jpeg`、`.shots/61-dashboard-detail.jpeg` 是**参考工程 Dashboard**（“详情 / 下载增长榜”）的截图，不是 ElvaCos，本审计不作证据；`.shots/94-state.jpeg` 是锁屏，不可用。
3. `docs/validation/*.png` 顶部蓝色「窄屏 / 手机 / 宽屏 / 设置 / 首页」是测试面板覆盖层，不属于应用 UI；只取其下方分栏内容作证据。
4. `docs/UX_RESTRUCTURE_PLAN.md` 是**尚未执行**的目标规格；本审计用它对照「现状与规格冲突」，不把目标结构当作现状描述。

---

## 1. 一句话结论

它现在最像「按数据表铺出来的 HDS 组件样例」：五个一级入口里三个各装两个内容家族，首页把问候、花费、计划、活动、待办、照片纵向排成六块，同一张计划卡用四种方式重复同一个进度，待办行画成复选框却点不开，空态与图标动作把新用户留在死端——离成品感差的不是配色或动画，而是**每屏只回答一个问题的取舍**。

---

## 2. P0（阻断级：让人困惑 / 误操作 / 明显破）

### P0-1 「下一步」待办行左侧画成复选框，点它却跳详情

- **严重度**：P0
- **证据**：`component/TaskLinkCard.ets:17`（`SymbolGlyph(Icons.pending)`），`common/Icons.ets:50`（`pending = sys.symbol.circle`）；`pages/main/HomePage.ets:180-204`（三类待办的 `action` 全部是 `open('project' / 'packing' / 'projectPhotos')`）；旧截图 `.shots/95-final.jpeg`、`.shots/93-light-restored.jpeg` 首屏「下一步」三行，每行一个空心圆。规格要求见 `docs/UX_RESTRUCTURE_PLAN.md:230`（首页允许直接勾选低风险准备任务）。
- **现象**：每行以 20vp 空心圆开场，视觉与「未勾选的 checkbox」完全一致；但整卡 `onClick` 只跳转，页面没有勾选按钮，屏幕上也看不到「双击」——`双击继续准备` 只写进无障碍描述（`HomePage.ets:184,191,201`）。
- **用户影响**：用户第一反应是点圆圈完成「身份证件 / 门票 / 发网」，结果被带到计划或打包页并丢失当前位置；这是每天都会发生、且会重复发生的核心任务误操作。
- **具体修法**：`TaskLinkCard` 左侧改成真实勾选按钮：24vp 圆形 `Button` + `Icons.pending` / `Icons.check`，点击调用已有的 `state.togglePreparation(item)` / `state.toggleChecklist(item)`（`model/ApplicationState.ets:360,384` 已实现真实回写）；整卡其余区域仍跳详情，命中区分离（左 40vp 勾选，其余 100% 跳转）；成功后行内显示「已完成」并 1.5s 后移出，失败保留行 + 行内红字（不要只靠 toast，见 P1-5）；如需 spec 4.1 的短时撤销，用同一 toggle 真实回写反转（不要做假撤销按钮）。
- **成本**：S（数据层已具备，只改 `HomePage.ets` + `TaskLinkCard.ets`）

### P0-2 空库首次启动时，「衣柜」「作品集」「时间轴」是死端：空状态没有按钮

- **严重度**：P0
- **证据**：`pages/main/LibraryPage.ets:111-114`（`EmptyState` 未传 `button`/`action`）；`pages/main/MePage.ets:108`（时间轴空态同样无按钮）；`component/PhotoGrid.ets:158-163`（相册空态、筛选空态都无按钮）；空状态组件本身支持按钮（`component/Surfaces.ets:62-77`）；添加动作只在标题栏纯图标里（`Dashboard.ets:387-404`）；旧截图 `.shots/37-home-mist.jpeg`、`.shots/04-me.jpeg` 显示空卡片下没有任何动作；规格见 `docs/UX_RESTRUCTURE_PLAN.md:542`（真正无数据 = 一条原因说明 + 就地启动动作）。
- **现象**：释放版空库首次启动时，首页 / Cos / 活动都有「＋ 新建…」按钮，衣柜和「我的」三个空态只有一句说明；衣柜的空态文案「记录存放位置、状态和价格，再关联到计划」没有给出入口，作品集空态让用户「在照片中标记为成片」，但照片在哪、怎么标，页面上没有任何按钮或链接。
- **用户影响**：新用户在两个一级页面无路可走，只能猜右上角 40vp 的纯图标 +；这是「看起来像 demo」最直接的一处——每个空态都在描述功能，却没有一个能点的动作。
- **具体修法**：`LibraryPage`：`EmptyState({ button: '＋ 添加装备', action: () => this.add('asset','') })`；`MePage` 时间轴：加 `button: '＋ 新建 Cos 计划'` 并给 `MePage` 增加 `add` 事件从 `Dashboard.ets:623-633` 传入；`PhotoGrid` 增加 `emptyAction` 参数：相册空态跳「去计划的照片导入」，筛选空态做「清除筛选」（`this.filter = 0`）；`MePage` 作品集空态跳「去相册看全部照片」。三处均不需要新页面。
- **成本**：S

### P0-3 首页把待办截成 2+3+2 条，全应用没有「全部待办」出口

- **严重度**：P0
- **证据**：`pages/main/HomePage.ets:176-206`（准备 `slice(0,2)`、打包 `slice(0,3)`、选片 `slice(0,2)`，且无总数、无「查看全部」）；全仓检索「查看全部」只命中详情页 `pages/detail/ProjectDetailPage.ets:485`；规格见 `docs/UX_RESTRUCTURE_PLAN.md:63`（已核对基线：全仓无「查看全部待办」）与 `:235-240`（完整待办页）。
- **现象**：「下一步」最多显示 7 条，超出部分在任何根页面都无法看到；排序是先当前计划、再截止日期，没有分类/项目分组；首屏既不知道总共有几项，也没有入口到达完整列表。
- **用户影响**：对一个「行动队列」应用，这是核心数据不可达：用户无法知道还有多少没做，也无法找到第 8 项之后的逾期任务；用户只能逐个进计划详情翻，首页也失去可信度。
- **具体修法**：先在 `SectionHeading({ title: '下一步', trailing: '共 N 项 · 查看全部 ›' })` 加可点 trailing，`N` 由与列表同一份聚合求出（现在 `preparationTasks()` / `packingTasks()` / 照片待选中已有，可先抽成一个 `nextActions(state)` 纯函数）；点击打开最小完整待办页（`bindSheet` 或新 `NavDestination` 均可），按「逾期 → 今天 → 未来 7 天 → 未定期」排序，并复用行组件发送精确 route（`ProjectRoute {id, section}`）。首页列表按规格 4.1 收到 5 条。
- **成本**：M（聚合 + 新目的地；若先做 sheet 最小版为 S，但需要和 P1-5 的错误/空态一起考虑）

---

## 3. P1（明显拖累品质）

### P1-1 首页首屏的结论不是「现在最该做什么」：6 个区块顺排，财务行权重过高，计划缺时间锚点

- **严重度**：P1
- **证据**：`pages/main/HomePage.ets:91-164`（问候 26/14 双行 + 全宽「花费统计 · ¥0.00」按钮 + 「接下来这份计划」卡 + 两个按钮）；`165-209`（「下一场活动」+「下一步」）；`219-235`（「最近照片」）；`236-241`（宽屏右栏只放后两块）。旧截图 `.shots/95-final.jpeg` 首屏从上到下是：首页标题 / 晚上好 Ray / 花费统计 / 接下来这份计划 / 0% 卡 / 准备装备 + 开始打包 / 下一步 3 条。规格 `docs/UX_RESTRUCTURE_PLAN.md:217-233`：一屏三块（接下来 / 在途与待办 / 最近），不做 KPI 行、不做常驻财务区块，新用户不显示零值统计。
- **现象**：六个区块纵向堆叠；「花费统计 · ¥0.00」是全屏唯一整行填充色块，压过计划卡成为第二视觉焦点；计划卡内没有日期或倒计时，「下一场活动」的倒计时在另一块里，首屏直接看不到「还有多久」；空库时零值统计照旧显示。
- **用户影响**：打开 App 得到的结论是「你有个 0% 的计划、花了 0 元」，而不是「下一件事是什么、什么时候、还差什么」；预算这种长期次要信息占了黄金位置，用户每天要多扫一行无用信息。
- **具体修法**：按 4.1 重排为三块：(1) **接下来**：把当前计划压成一行——56vp 封面色块 + 名称/角色 + 「10月24日 · 还有 6 天」（来自 `planDate(project, events)`）+ 准备 `3/6`，下方保留一个主按钮「开始打包」和一个次要文字按钮「继续准备」；(2) **在途与待办**：5 条 + 查看全部 N 项（P0-3）；(3) **最近**：最近 1 张照片 + 「记一笔 / 收录」两个快捷；花费改成第三块底部 13vp 文本行「本月 ¥X · 统计 ›」，`expenseTotal === 0` 时整行不渲染；问候降到 17vp 或并入标题栏。
- **成本**：M（首页结构重写，可先用现有组件拼装）

### P1-2 计划卡把同一进度说四遍、0/0 时仍画空进度条、卡内没有日期

- **严重度**：P1
- **证据**：`component/ProjectCard.ets:42`（状态 pill）、`50-55`（「N / M 项准备完成」）、`57-63`（25vp 百分比 +「准备进度」）、`65-70`（Progress 条）；旧截图 `.shots/95-final.jpeg`（右侧 0% 与 0/0 同屏、下方空条）、`.shots/72-cos-root.jpeg`（同款卡在列表里；截图文字仍是旧的「装备可用率」，代码已改名但结构未变）；规格 `docs/UX_RESTRUCTURE_PLAN.md:244-248`（只保留完成数；进度条仅在任务数 > 8 时出现；卡片优先级为名称与角色 → 日期与阶段 → 准备完成数）。
- **现象**：一张卡同时给状态 pill、完成数、百分比大数字、进度条；`preparationProgress` 在 `total = 0` 时 `percent = 0`（`model/Preparation.ets:59-63`），右列显示「待设置」但进度条仍画 0%，语义变成「进度为零」而不是「尚未记录任务」；卡内完全没有日期（首页只在 SectionHeading trailing 里显示日期，Cos 列表页完全没有），而日期是规格里的第二优先级。
- **用户影响**：用户读不出「这场什么时候、还差什么」，只看到四个重复的 0%；空进度条让新建计划像坏数据；列表卡片在手机上因右列 + 76×96 封面挤压，`hero` 名称 23vp 在 390vp 屏就会折成两行（旧截图 95 的「Genshin / family」即如此）。
- **具体修法**：删除右侧百分比列；保留右上「3/6」一列 13vp；仅 `total > 8` 时显示 Progress；新增第三行日期「10月24日 · 距活动 6 天 / 日期待定」（`planDate(p, this.state.events)`）；`hero` 卡改为名称 20vp 单行 + 不放大、不显示封面大图或把封面缩到 48×48；两个 CTA 移出卡片到卡下方。
- **成本**：M（共用组件，首页 / Cos 列表 / 详情概览一起回归）

### P1-3 一级 Tab 与目标规格冲突：每个 Tab 装两个内容家族，照片没有独立入口，设置只在「我的」

- **严重度**：P1
- **证据**：`Dashboard.ets:656-664`（首页 / Cos / 活动 / 衣柜 / 我的）；`501-513`（角色|计划、列表|日历、装备|照片、作品|时间轴）；`405-418`（只有 index 4 的标题栏菜单是「设置」齿轮，其余是新建动作）；旧截图 `.shots/72-cos-root.jpeg`（Cos 页「角色 / 计划」分段 + 单图标 +）、`.shots/37-home-mist.jpeg`（我的页「作品 / 时间轴」）。规格 `docs/UX_RESTRUCTURE_PLAN.md:110-120`（一级入口 = 首页 / 计划 / 日程 / 衣柜 / 相册，设置齿轮在每个根页右上角）、`:281-290`（相册顶层两模式）。
- **现象**：用户要先记住「照片在 4 号衣柜的第二分段、成片在 5 号我的的第一分段、时间轴在 5 号我的的第二分段」；「Cos」一个词同时指角色和计划；活动 / 衣柜 / 我的的右上角主位都是新建动作，换主题、导出、清缓存必须回到「我的」；照片被拆进两个 Tab，词表还不一样（见 P2-4）。
- **用户影响**：Tab 标签无法预测内容——这正是规格第 2 章自己判定的基线问题；「我的照片在哪」需要三条路径试错，设置这种低频但全局的能力被藏在业务 Tab 里。
- **具体修法**：按规格执行：Tab 改为 计划（角色库作为首部文字入口）/ 日程 / 衣柜 / 相册；相册承接现有 `PhotoGrid` + `LibraryPage` 照片分支；四个根页的 `rootMenus` 统一为 1 个齿轮 → Settings，新建动作下沉到页内（P1-4）；作品集作为相册内「成片/已发布」筛选而不是独立 Tab。**过渡期最小改动**：先把「Cos」改为中文「计划」，四个根页标题栏加齿轮（`HdsNavigationMenuItemOptions` 可同时放 gear + add 两项），衣柜第二分段改名「相册」。
- **成本**：L（完整重构）/ S（过渡期改名 + 齿轮入口）

### P1-4 标题栏纯图标命令语义不明，且同一个「+」会静默变义

- **严重度**：P1
- **证据**：`Dashboard.ets:387-404`（首页 3 项：新建计划 `Icons.add`、添加活动 `Icons.event`、导入照片 `Icons.importPhoto`；Cos 的 `+` 在「新建计划 / 添加角色」间切换；衣柜的 `+` 在「添加装备 / 导入照片」间切换）；`common/Icons.ets:15,52`（event = clock，importPhoto = albums）；旧截图 `.shots/95-final.jpeg`、`.shots/91-dark-restart.jpeg` 首页右上三个圆形按钮（＋ / 时钟 / 相册），`.shots/72-cos-root.jpeg` Cos 页只有一个「+」。
- **现象**：三个按钮都没有可见文字：「+」尚可猜，「时钟」读作历史/提醒而不是「添加活动」，「相册」读作照片浏览而不是「导入照片」；Cos / 衣柜的「+」动作取决于当前分段，切换分段时按钮外观不变、行为变了；语义只写在 a11y label 里。
- **用户影响**：用户必须点开才知道会创建什么，误入「新建计划」表单后只能取消；同一位置不同语义没有任何可见提示，是「功能能跑但不可发现」的典型。
- **具体修法**：首页收成一个「+」，打开 `bindSheet` 三行文字动作：新建计划 / 添加活动 / 从相册导入（每行 56vp，图标 + 文字 + 副说明）；Cos / 衣柜保留上下文 `+` 但在标题栏分段旁或首屏显示当前动作文字（如「＋ 新建计划」），或改为带 label 的下拉菜单；验收标准：任意图标动作 3 秒内能说出结果。
- **成本**：S

### P1-5 失败反馈和加载反馈混在 2 秒 toast 里，成功与失败同款式；全局 busy 会弹整屏 spinner

- **严重度**：P1
- **证据**：`Dashboard.ets:543-547`（`state.error || state.notice` 同一个 2000ms toast）；`548-552`（busy 只有 40vp `LoadingProgress`，a11y 播报「操作进行中」）；`84-89`（ready 后 300ms 触发 `maintain`）；`model/ApplicationState.ets:241-242`（error 与 notice 同通道）、`249-258`（写入与 refresh 同一个 try，只返回布尔）；规格 `docs/UX_RESTRUCTURE_PLAN.md:541-546`（保存中按钮显示具体动作、保存失败页面持续错误条、保存成功但刷新失败分开表达）、`:565-569`。
- **现象**：保存失败、删除失败、示例数据提示共用同一种底部 toast，2 秒消失，没有可重试的持久错误；`perform` 全量刷新期间整屏 busy，标题栏菜单 disabled 并弹中央 spinner；一个内联勾选也会触发 `refresh()` 13 个集合（`ApplicationState.ets:231-240`）。
- **用户影响**：用户错过失败提示会以为保存成功（违反 H7 不谎报成功）；连续操作时每次小写入都被全屏 spinner 打断，且所有入口暂时失效。
- **具体修法**：`reportError` 改为页面级常驻错误条（`Theme.danger` 文字/背景 + 「重试」按钮，直到成功或关闭）；`notice` 继续 toast；`runOperation` 返回 `{ status: 'ok' | 'failed' | 'savedNotRefreshed', detail }`，刷新失败显示「记录已保存，页面未更新，点此刷新」；`maintain` 走静默（失败才 toast）；内联勾选只 `disabled` 当前行，不锁全局 `busy`；首载用骨架（P2-1）。
- **成本**：M（`ApplicationState` + `Dashboard` + 各页错误挂载点）

### P1-6 可点提示三种写法，反过来不可点元素却带按压光效

- **严重度**：P1
- **证据**：`component/TaskLinkCard.ets:22`（Image 16vp + opacity 0.55）、`HomePage.ets:82` / `CosPage.ets:69`（`Text('›')` 24/26vp）、`LibraryPage.ets:43-65` / `EventsPage.ets:43-60`（整卡可点但无任何箭头）；`component/Surfaces.ets:93-102`（StatusPill 绑了 `visualEffect` + `compositingFilter` + `attributeModifier`，但无 `onClick`）、`MePage.ets:68`（KPI 统计卡同样）、`LibraryPage.ets:45-55`（类型徽章同样）；旧截图 `.shots/95-final.jpeg`（下一步行是图标箭头）、`.shots/72-cos-root.jpeg`（计划卡无箭头）。
- **现象**：同一个「进入下一层」概念出现三种视觉：贴边小箭头、大号文字「›」、完全没有；反过来，状态 pill、KPI 统计块、衣柜类型徽章摸上去有按压缩放与点光源，却什么都不做；活动卡的「记得确认门票」是 tint 胶囊，看起来像可点动作，实际只是静态状态。
- **用户影响**：用户不知道哪些行能点；点了状态 pill 没反应会以为界面卡住；活动卡/装备卡整卡可点性不可发现，只能凭经验乱试。
- **具体修法**：统一可进入行的行尾提示为 `Image(Icons.chevronRight) 16×16 opacity 0.55`（或 `SymbolGlyph(chevron_right)`），所有可进入行（计划卡、活动卡、装备行、角色行、最近照片、日历当日活动）都加；删除 `StatusPill`、`MePage.ets:68`、`LibraryPage.ets:53-55` 的 `visualEffect/compositingFilter/attributeModifier` 三件套（装饰元素不绑定按压），或把 `StatusPill` 加 `onClick` 变成筛选 chip 后再保留反馈——二选一，不能既反馈又无动作。
- **成本**：S

### P1-7 筛选控件不一致：状态与日期互斥混在一个 Select；日历模式丢筛选和计数

- **严重度**：P1
- **证据**：`CosPage.ets:92-98`（`进行中 / 已完成 / 日期待定 / 全部` 一个 Select）+ `43-44`（互斥过滤）；`EventsPage.ets:68-78`（列表有「即将到来 / 已结束 / 日期待定」Select，`calendar` 模式下整个 Select 隐藏，`SectionHeading.trailing` 置空为 `''`）；`PhotoGrid.ets:54-55`（Select `layoutWeight(1)` 拉满整行）；规格 `docs/UX_RESTRUCTURE_PLAN.md:188-200`（分段承担视图，筛选承担可组合条件）、`:242-248`（日期待定是日期维度，不与已完成混为互斥状态）。
- **现象**：计划的「进行中 / 已完成」是状态，「日期待定」是日期维度，被塞进同一个单选且互斥：选「已完成」看不到已完成但日期待定的计划，选「日期待定」看不到已完成的；页面里存在两个位置不同的筛选（标题栏分段 + 内容 Select）；照片页 Select 被拉伸成整行，看起来像输入框而不是下拉。
- **用户影响**：用户以为「已完成」就是全部已完成；组合条件无法表达；控件位置/宽度不统一，页面像拼装。
- **具体修法**：计划页标题栏分段改为「进行中 / 已完成 / 全部」（3 段，符合 3.8），「日期待定」独立为筛选 chip（添加在搜索框右侧）或日期筛选；活动页保留「列表 / 日历」分段，列表筛选固定宽度 160vp 并与标题同行，日历模式在标题下显示「当前筛选：即将到来 · 清除」；照片页 Select 加 `constraintSize({ maxWidth: 200 })`，不要 `layoutWeight(1)`。
- **成本**：M

### P1-8 宽屏分栏：左栏垂直居中导致与右栏错位，屏幕下半 2/3 空白，左栏不可滚

- **严重度**：P1
- **证据**：`component/DashboardSplitLayout.ets:21-44`（左栏 `layoutWeight(4)` + `justifyContent(FlexAlign.Center)`、右栏 `layoutWeight(6)` + Scroll、整体 `maxWidth(1440)`）；`HomePage.ets:245-251`（840×600 断点进入分栏）；截图 `docs/validation/home-wide-start-api26.png`、`home-wide-bottom-api26.png`、`task-axis-home-wheel-api26.png`、`task-axis-home-wide-start-api26.png`（忽略顶部测试面板，只看分栏内容）。
- **现象**：左右两栏都只占屏幕上半部分：左栏问候/计划/按钮整体垂直居中在屏幕中段，右栏从顶部开始，两组内容基线错开；下半 2/3 全空，中间竖分隔线贯穿空白；左栏没有 Scroll，只是固定 Column；右栏内容短时也没有利用剩余空间。
- **用户影响**：宽屏下第一眼像「把手机页拆成两列后忘了排版」；视线在两列之间来回跳；高度 600–700vp 或大字号时，左栏内容会溢出且无法滚动（无障碍风险）。
- **具体修法**：左栏 `justifyContent(FlexAlign.Start)`，并把 `overviewTop`（80）与 `wideScrollTop`（110）对齐成 110；左栏包一层 Scroll（或 `constraintSize({ maxHeight: '100%' })` + 自适应）；分栏改 5:5 或 42:58，右栏内容 `constraintSize({ maxWidth: 720 })`；右栏内容不足时用「本周待办 / 最近作品」补位而不是留白；840–1000vp 区间左栏 < 400vp，断点提到 1000 或该区间退回单列。
- **成本**：M

### P1-9 主 Tab 栏与详情动作栏同构；选中态只有颜色；图标来自不同图标集且与含义不符

- **严重度**：P1
- **证据**：`Dashboard.ets:653-692`（`BottomTabBarStyle(Icons.home,'首页')` 等五项，无选中指示；`barWidth(Math.min(312.5, viewportWidth-32))`，宽屏固定 312.5vp；`constants.ets:149`）；`common/Icons.ets:13-17`（home = `return_home_fill`、cos = `ohos_user_auth_icon_face`、event = clock、library = 矩形组合、me = `person_badge_waveform`）；`component/HdsActionTabs.ets:28-37`（详情动作栏同为浮动胶囊 + 图标 + 文字，label/icon 统一 `Theme.ink` 无选中态）；旧截图 `.shots/95-final.jpeg`、`.shots/91-dark-restart.jpeg` 选中仅图标/文字变蓝；`.shots/70-project.jpeg`、`.shots/30-project.jpeg` 详情动作栏（含「删除计划」）与主 Tab 外观几乎一样。
- **现象**：选中项只靠颜色区分；五个图标实心/线框混用（首页实心门形、Cos 线框笑脸、活动线框时钟、衣柜混合矩形、我的实心人物+声波），「首页」图标是回首页的箭头门形而不是房子，「我的」用人物+声波与「Cos」的笑脸都与「人」有关；详情页底部动作栏（含破坏性删除）和主 Tab 同款，只在内容上不同。
- **用户影响**：分不清底部这排是「导航」还是「当前页动作」；色弱或强光下不知道当前在哪个 Tab；图标需要学习，「Cos / 我的」尤其容易混。
- **具体修法**：五个 Tab 改用同一套 `sys.symbol`（house / person / calendar / hanger 或 wardrobe / photo）；选中项加 32×32 圆角 10 的 `Theme.tint` 底 + label 12vp Medium，未选中图标 opacity 0.6（若 `BottomTabBarStyle` 不支持底块，用 `HdsTabs` 的自定义 tabBar 实现）；宽屏（>=840vp）时 `barWidth` 改用 medium/large 档（如 420vp）；详情动作栏改为「1 个主动作 + 溢出菜单」在结构上区分（与详情页审计交叉）。
- **成本**：M（HDS 选中样式需实测能力；图标替换 S）

### P1-10 「我的」三个 KPI 与下方作品集口径不同、无计数，KPI 卡还带假按压反馈

- **严重度**：P1
- **证据**：`MePage.ets:49-69`（「已完成计划 / 照片记录 / 衣柜装备」三个数字 + 照片分布图）；`79`（作品集只筛 `FINAL` / `PUBLISHED`）；`68`（整块统计卡绑 `visualEffect` + `attributeModifier` 但无 `onClick`）；旧截图 `.shots/37-home-mist.jpeg`、`.shots/04-me.jpeg`（0 / 7 / 0 与下方空作品集并列）。
- **现象**：「照片记录 7」统计全部照片（含原片、已导入），下方「作品集」只有成片/已发布（可能 0 张），同屏两个数字对不上；作品集标题没有「N 张」计数，筛选后也没有数量；三个数字块可按压发光但点不动。
- **用户影响**：用户会问「7 张照片怎么一张作品都没有」，作品集像坏掉；假反馈让人以为能点进去看明细，产生挫败。
- **具体修法**：KPI 改成与下方列表同口径：作品 N / 待修 N / 计划 N，每个数字点击跳对应筛选；作品集 `SectionHeading` 加 trailing `${visible.length} 张作品`；删除统计块按压特效；`DistributionChart` 仅在 `photos.length > 0` 时渲染（或放到空态下方），避免 0 值画空图。
- **成本**：S

### P1-11 根页头部叠 4–5 层，Cos 首张卡片落在屏幕约 1/3 处；区块标题与正文同级

- **严重度**：P1
- **证据**：`CosPage.ets:76-98`（`Blank(topInset = Theme.contentTop = 100)` → Search 48 → SectionHeading「我的计划」→ Select）；`HomePage.ets:91-99`（26vp 问候 + 14vp 副标题，与 `Dashboard.ets:643-647` 的标题栏「首页」形成两层标题）；`Surfaces.ets:41-55`（SectionHeading 15vp Medium + muted）；`constants.ets:107,134`（`MAIN_PAGE_TITLES`、`LAYOUT_CONTENT_TOP = 100`）；旧截图 `.shots/72-cos-root.jpeg`：标题栏之后先空约 70vp，再搜索、再「我的计划 / 1 份计划」、再进行中，第一张计划卡顶边约在屏幕 36% 高度；`.shots/95-final.jpeg` 首页标题与问候双标题。
- **现象**：标题栏已经有页面名和分段，内容里又出现「我的计划 / 我的衣柜 / 活动安排 / 作品集」等与 Tab 同名的重复标题；固定 100vp 顶部留白 + 48 搜索 + 30 标题 + 40 筛选，Cos 页第一张卡在 1/3 屏高才出现；SectionHeading 15vp Medium 用 muted 色，与正文 15vp 一样大，区块标题扫读不出来。
- **用户影响**：每页开头先读一遍「我在哪」，首屏有效内容少、列表页滚动成本高；整个界面只有「卡片 / 正文」两层，缺少 section 分隔，长页更明显。
- **具体修法**：有标题栏分段的页面把 `Blank(topInset)` 降到 `Theme.contentTop - 48`（约 52vp）或直接用 HDS 标题栏安全间距；删除重复 SectionHeading，把计数并入搜索行右侧（「48 份」），搜索与筛选同一行（Search `layoutWeight(1)` + Select 160vp）；SectionHeading 改 16vp `FontWeight.Medium` + `Theme.ink`，trailing 12vp muted；标题栏分段宽度 `Theme.titleSegmentWidth = '50%'` 在 2 字标签正好，3 字标签（作品/时间轴）建议 56% 或让分段按内容自适应。
- **成本**：S

### P1-12 「最近照片」只显 3 张、计数与顺序都不对，没有查看全部；活动日历模式下没有计数

- **严重度**：P1
- **证据**：`HomePage.ets:219-235`（`SectionHeading.trailing = photos.length 张`，但 `photos.slice(0,3)` 只取前三；`slice` 前未排序；照片卡只有图片，无项目/状态标签）；`model/Entities.ets:131`（`createdAt` 可用）；`EventsPage.ets:68`（日历模式 trailing 为 `''`）；「查看全部」全仓只在 `ProjectDetailPage.ets:485`；截图 `docs/validation/home-wide-bottom-api26.png`（「最近照片 3 张」下三张「照片待恢复」，无任何入口）。
- **现象**：「最近照片 N 张」下面永远只有 3 张，且不是按时间排的最近照片，卡片没有项目名/日期；点单张只进照片详情，回不到列表；活动切到日历后场次数消失，没有任何「本月 N 场」结论。
- **用户影响**：用户不知道总照片在哪看、也打不开全部；「最近」名不副实；日历里没有本月活动的量级判断。
- **具体修法**：`photos.slice().sort((a,b)=>b.createdAt-a.createdAt).slice(0,3)`；SectionHeading trailing 增加可点文字「全部 N 张 ›」打开相册对应筛选（复用 `LibraryPage` 照片分支或作品集）；照片卡底部加一行 11vp 项目名 + 状态（现在 `PhotoGrid` 卡片已有此结构，抽取共用）；日历标题区显示「本月 N 场 · 共 M 场」。
- **成本**：S

---

## 4. P2（打磨）

### P2-1 冷启动没有骨架，维护任务会在首页中央弹 40vp spinner

- **严重度**：P2
- **证据**：`Dashboard.ets:556-566`（`!ready` 且非错误时内容区什么都不渲染）、`548-552`（busy 只有 40vp `LoadingProgress`）、`706`（overlay 挂在外层导航）、`84-89`（ready 后 300ms 触发 `maintain`）；`model/ApplicationState.ets:130-154`（initialize / maintain 共用 `perform` → busy）；规格 `docs/UX_RESTRUCTURE_PLAN.md:541`（首次业务加载用骨架或明确加载提示）。
- **现象**：启动首帧到数据就绪之间，除标题栏和 Tab 栏外内容区空白；随后（或每次启动 300ms 后）`maintain` 的 busy 把 spinner 盖在已显示内容中央，无文案（a11y 只有「操作进行中」）。
- **用户影响**：像闪屏/卡顿；spinner 出现时机与用户操作无关，弱化「正在加载」的感知。
- **具体修法**：首次加载在内容区放 3 行骨架（100×16 标题条 + 两张 120vp 卡）；`maintain` 不设 busy（collect/reconcile 静默）或延迟到页面隐藏；非首载的写操作 spinner 改行内（按钮文字「保存中…」）而不是全局 overlay。
- **成本**：S

### P2-2 日期出现三种格式，倒计时没有上限格式

- **严重度**：P2
- **证据**：`HomePage.ets:78`（`${date} · ${city}` 原始 ISO）；`model/Schedule.ets:32-34`（`eventDateLabel` 同样输出 ISO）；`EventsPage.ets:45-50`（左栏 13vp「10月」+ 32vp「07」中文拆列）；`MePage.ets:43` + `common/format.ets:10`（`formatTime` 输出 `2026.10.07`）；`HomePage.ets:62-74`（倒计时直接拼天数、无上限）；截图 `docs/validation/home-phone-restored-api26.png`（「2099-10-07 · 测试城市」+「26663 天后见」）。
- **现象**：同一活动：首页「2099-10-07 · 测试城市」、活动卡左栏「10月 / 07」、时间轴「2026.10.07」；超过一年仍是「26663 天后见」。
- **用户影响**：中文界面混入机器日期，读数成本高；远日期倒计时变成五位数噪声，让卡片显得不可信。
- **具体修法**：新增 `formatDateLabel(date)` 统一输出「10月24日 周六」（跨年加年份），首页 / 活动列表 / 详情 / 日历统一使用；倒计时 > 365 天时显示日期或「明年 10 月」，不显示五位数。
- **成本**：S

### P2-3 返回/滚动位置没有显式恢复；分段两侧共用一个 Scroller；搜索词跨分段共享

- **严重度**：P2
- **证据**：`Dashboard.ets:59-60`（每 Tab 一个 Scroller）、`110-124`（open / closeDetail 只 push/pop，无偏移存取）、`676`（全仓唯一 `scrollTo` 是重复点当前 Tab 回顶）；全仓无 `getScrollOffset` / `currentOffset`；`CosPage.ets:28,43-45,74,125`（同一 Scroller + 同一 `query` 同时服务计划/角色）；`LibraryPage.ets:79-120`（同一 Scroller 服务照片 List / 装备 Scroll）；`MePage.ets:75-114`（作品 PhotoGrid / 时间轴 Scroll 共用）；规格 H4 / 3.5 要求显式返回恢复点（`docs/UX_RESTRUCTURE_PLAN.md:16,158-168`）。
- **现象**：现在返回能保持位置，是因为详情是覆盖式、根内容不销毁（被动保留），没有任何地方声明恢复点；切角色/计划、装备/照片、作品/时间轴时没有 `scrollTo(0)` 或独立偏移；Cos 的搜索词切段后继续过滤另一种字段（计划名+角色名 vs 角色名+作品名），切段后可能显示「搜不到」。
- **用户影响**：导航/缓存策略一变位置就丢；分段切换停在上一段的滚动位置；切段后搜索框还在但口径变了，用户以为是 bug。
- **具体修法**：`Dashboard` 存 `number[5]` 偏移，`open()` 前记录 `currentOffset()`、`closeDetail()` 后 `scrollTo`（或按 3.5 写进 route 恢复点）；分段切换在 `onSelectedIndexChanged` 里 `scrollTo({ yOffset: 0 })`，或每段独立 Scroller；Cos 拆 `planQuery / characterQuery`，或切段清空 query。
- **成本**：M

### P2-4 照片筛选 5 个词覆盖 8 个状态，卡片标签与筛选项对不上；批量模式一次 4 个控件

- **严重度**：P2
- **证据**：`PhotoGrid.ets:43`（`['全部','待选','已选','待修','成片']`）、`54-55`（Select 拉满）、`89-108`（「全部/Batch选片」「已选 N 张/全选当前筛选」「标为…/应用」三行控件）、`134-139`（卡片 caption 用 `PHOTO_LABELS`）；`constants.ets:79-80`（8 状态 8 标签）；`model/Rules.ets:59-65`（「成片」= 已精修 + 最终 + 已发布）；`158-163`（两个空态无动作）；规格 8.4（`docs/UX_RESTRUCTURE_PLAN.md:510-528`）。
- **现象**：卡片上写「已精修」的照片，在筛选里归到「成片」；「原片 / 已导入 / 已归档 / 已发布」没有独立筛选项；批量选片时同时出现三行控件，布尔状态用 Select 表达。
- **用户影响**：词表对不上导致「我明明标了成片怎么不在成片里」；批量操作比同类应用重。
- **具体修法**：按 8.4 统一映射并在 UI 用同一套标签（至少 caption 与筛选项一一对应）；批量工具栏只留一行：状态 Select 160vp + 应用 + 取消，全选放列表头；空态加「去导入 / 清除筛选」按钮。
- **成本**：M

### P2-5 宽屏下其余四个根页仍是单列拉伸到 1440

- **严重度**：P2
- **证据**：`CosPage.ets:124`、`EventsPage.ets:104`、`LibraryPage.ets:118`、`PhotoGrid.ets:188-190`（都只 `constraintSize({ maxWidth: 1440 })`，无分栏/多列）；`DashboardSplitLayout` 只被 `HomePage` 使用；`docs/UI_STYLE.md:33`（业务列表上限 1440）。
- **现象**：平板/横屏上，计划卡 / 活动卡 / 装备行被拉满 1216–1440vp，封面 76 或日期列 55 靠左，其余宽度空白；照片页最多 4 列但每列会被拉到约 330vp。
- **用户影响**：大屏只是「放大手机」，信息密度反而下降，和首页分栏体验不一致。
- **具体修法**：>=840vp 计划/活动列表用 2 列网格，或列表 + 右侧预览；照片页 >=1200vp 用 5–6 列；业务列表统一 `maxWidth 1000`（阅读类保持 840）。
- **成本**：M

### P2-6 衣柜价格用 ¥0.00 表示未记录；单字头像与「照片待恢复」重复出现

- **严重度**：P2
- **证据**：`LibraryPage.ets:63`（`'¥' + (a.priceCents/100).toFixed(2)` 无条件）、`model/Entities.ets:82`（默认 0）；`ProjectCard.ets:26-39` / `CosPage.ets:53-64`（无封面时 76×96 / 72×90 tint 块只放一个首字）；`HomePage.ets:215`（「照片待恢复」占位）；截图 `docs/validation/home-wide-bottom-api26.png`（三张「照片待恢复」并排）。
- **现象**：每件未记价格的装备都显示「¥0.00」，与「未记录存放位置」并列；所有无封面计划/角色都是灰底单字（「Y / 布」），同屏出现多个相同占位块；缩略图缺失时三张卡并排写「照片待恢复」。
- **用户影响**：0 值与「没数据」混同，看起来像数据错误；首屏像演示数据未加载完。
- **具体修法**：`priceCents <= 0` 时不显示价格或显示「价格未记录」（muted）；单字头像保留但统一 1:1 圆角 + 首字母对比度更高的字重；照片缺图改为一张「无法显示」卡 + 原因/数量（规格 9.1 图片缺失行），不要三张重复。
- **成本**：S

---

## 5. 与 `UX_RESTRUCTURE_PLAN.md` v2 的冲突对照

| 规格要求（行号） | 当前实现 | 对应 finding |
|---|---|---|
| 3.2：一级入口 = 首页 / 计划 / 日程 / 衣柜 / 相册（`:110-120`） | 首页 / Cos / 活动 / 衣柜 / 我的，照片拆在衣柜与我的（`Dashboard.ets:656-664,501-513`） | P1-3 |
| 3.2：设置齿轮在每个根页右上角、同一目的地（`:118`） | 只有「我的」标题栏是齿轮（`Dashboard.ets:405-418`） | P1-3 |
| 4.1：首页一屏三块、不做常驻财务块、新用户不显示零值统计（`:217-233`） | 6 区块顺排；全宽「花费统计 ¥0.00」在计划卡之前；空库仍显示（`HomePage.ets:103-122`） | P1-1 |
| 4.1：首页允许直接勾选低风险准备任务（`:230`） | 待办行画成复选框，点击却跳转（`TaskLinkCard.ets:17`） | P0-1 |
| 4.2：存在完整待办页（`:235-240`） | 不存在；首页截取 2+3+2 条且无出口（`HomePage.ets:176-206`） | P0-3 |
| 4.3：计划卡只保留完成数、进度条仅 >8 项、日期优先（`:242-248`） | pill + 完成数 + 百分比 + 进度条四重；卡内无日期（`ProjectCard.ets:42,50-70`） | P1-2 |
| 4.3：日期待定不与已完成混为互斥状态（`:244`） | 同一个 Select 里「进行中/已完成/日期待定」互斥（`CosPage.ets:92-98`） | P1-7 |
| 4.7：相册顶层两模式（按场次 / 待处理）（`:281-290`） | 照片藏在「衣柜→照片」与「我的→作品」，无按场次视图（`LibraryPage.ets:78-89`、`MePage.ets:75-86`） | P1-3、P2-4 |
| 8.4：照片状态统一映射（`:510-528`） | 筛选 5 词表 vs 8 个 caption 标签，语义交叉（`PhotoGrid.ets:43`、`constants.ets:79-80`） | P2-4 |
| 9.1：首次加载骨架/明确提示；无数据就地动作；保存中按钮显示具体动作（`:537-551`） | 启动空白 + 40vp spinner；三处空态无动作；全局 busy 锁入口（`Dashboard.ets:548-566`、`LibraryPage.ets:111-114`、`MePage.ets:108`） | P0-2、P1-5、P2-1 |
| H4：跨页跳转声明返回恢复点（`:16`） | 靠根内容不销毁被动保留，无显式偏移（`Dashboard.ets:110-124`） | P2-3 |

---

## 6. 值得保留的优点（不是客套，是后续重构的底座）

1. **HDS 材质与按压体系集中且克制**：`InteractiveCard` 的 0.985 缩放 + 130ms 弹簧 + PointLight + HDR 增强、`HdsMiniBarButton` 的原生材质胶囊（`Surfaces.ets:20-37`、`HdsMiniBarButton.ets:69-128`）在浅/深色截图（`.shots/93-light-restored.jpeg`、`91-dark-restart.jpeg`）里观感一致，没有自造阴影和系统材质打架——这是「原生感」的来源。
2. **令牌只有一个入口**：17 个语义色令牌 + 尺寸都从 `Theme`/`constants` 取（`Theme.ets:30-105`、`constants.ets:134-150`），五套配色只替换资源，并用 `CustomTheme` 同步原生控件强调色（`Theme.ets:53-84`），重构时改一处能全站生效。
3. **主路径的错误/空态大多已有出口**：首页、Cos、活动、日历空态都带「＋ 新建…」按钮，首载失败有「重试」（`HomePage.ets:115-122`、`CosPage.ets:100-105`、`EventsPage.ets:94-99`、`EventCalendar.ets:106-111`、`Dashboard.ets:556-566`）——缺口集中在衣柜/作品集/时间轴（P0-2），不是全盘缺失。
4. **无障碍不是事后补的**：可点卡片有 `accessibilityRole(BUTTON)` + label + description，装饰元素 `accessibilityLevel('no')`，分段有「当前显示…可切换」，日历日期有 `accessibilitySelected` 和「N 场活动」播报（`Surfaces.ets:34-36`、`HdsTitleBarSegment.ets:79-80`、`EventCalendar.ets:78-80`）。
5. **导航状态的方向是对的**：五个 Tab 各自 `NavPathStack` + `Scroller`，分段/筛选状态提升到 `Dashboard`，重复点当前 Tab 会回顶（`Dashboard.ets:58-66,532-537,672-686`）——P2-3 只需要把「被动保留」升级成「显式契约」，不用推翻。
6. **响应式底座已经具备**：PhotoGrid 按宽度 2/3/4 列、首页 840×600 分栏、内容 1440 上限、间距/圆角/页边距全部令牌化（`PhotoGrid.ets:142-147`、`HomePage.ets:245`、`Theme.ets:86-105`），问题是内容编排与断点利用率没跟上，不是没有能力。

---

## 7. 建议整改批次（依赖明确，先做低风险高收益）

**批次 0｜口径冻结（0.5 天，无代码）**
确认 `UX_RESTRUCTURE_PLAN` 3.2 的 IA 是否批准执行、首页是否按 4.1 三块改；把本审计的 P0/P1 映射到文件与写入范围（`HomePage.ets`、`ProjectCard.ets`、`Dashboard.ets`、`Surfaces.ets` 是高冲突文件，必须与详情页/视觉系统审计按 write scope 串行）。**依赖：无。**

**批次 A｜P0 速修（2–3 天，独立可发）**
A1 `TaskLinkCard` 加真实勾选（用现成 `togglePreparation` / `toggleChecklist`，P0-1）；A2 四个空态补按钮（P0-2）；A3 首页「共 N 项 / 查看全部」+ 最小完整待办页（P0-3）。**依赖：A3 需要先把「下一步」过滤抽成共用聚合；A1/A2 与 A3 可并行。**

**批次 B｜P1 视觉与交互纠偏（4–6 天）**
B1 `ProjectCard` 简化 + 日期行（P1-2，先做，因为它同时影响首页与 Cos 列表）；B2 首页三块化 + 财务行下沉 + 最近照片排序/入口（P1-1、P1-12）；B3 标题栏动作收敛为「+」创建面板 + 齿轮入口（P1-4，同时是 P1-3 的过渡）；B4 chevron 与假按压反馈统一（P1-6）；B5 筛选控件拆分与统一宽度（P1-7）；B6 错误条 / 保存中 / 刷新失败区分（P1-5，依赖 `ApplicationState` 返回类型改造，建议与详情页审计合并做）；B7 「我的」KPI 口径（P1-10）；B8 根页头部减层（P1-11）。**依赖：B1 与详情页共用 `ProjectCard`，B6 与详情页共用 `ApplicationState`/`Dashboard`，均需与 `detail-settings-auditor` 的批次对齐后再动。**

**批次 C｜IA 重构（1–2 周）**
C1 Tab 改为 计划 / 日程 / 衣柜 / 相册并迁移照片入口，C2 每个根页齿轮设置，C3 首页三块定稿，C4 计划列表状态/日期分离（P1-3、P1-7 的最终形态）。**依赖：先完成 A3（完整待办与聚合）和 B1（计划卡）；不要在 C 之前做宽屏分栏大改（P1-8/P2-5），否则要重排两次。**

**批次 D｜响应式与打磨（2–3 天，C 之后）**
D1 宽屏分栏对齐/左栏可滚/右栏利用（P1-8）；D2 其余页宽屏多列（P2-5）；D3 Tab 图标与选中态（P1-9，若 C 改了 Tab 则并入 C）；D4 日期格式统一（P2-2）；D5 骨架与维护静默（P2-1）；D6 分段滚动复位与显式返回恢复（P2-3）；D7 照片词表/批量工具栏（P2-4）、零值与占位（P2-6）。**依赖：D1/D2 依赖 C；D3 在 C 之后做避免两次换图标；D4–D7 可并行。**

**不建议顺序**：不要在批次 B 之前做批次 C——`ProjectCard`、`EmptyState`、标题栏会被重写两遍；也不要只做配色/动画层调整（截图 91/93 已证明材质与主题没问题），用户说的「UI 糟糕」主要来自信息架构与交互契约，而不是视觉皮肤。

---

## 8. 复核方式

- 代码类 finding：按文中 `file:line` 在当前工作区直接读文件即可复核；行号基线为 commit `38e97f6`（10-08），截图基线为 10-07，差异见 §0。
- 布局/视觉类：优先看 `.shots/95-final.jpeg`（首页浅色）、`91-dark-restart.jpeg`（深色）、`72-cos-root.jpeg`（Cos）、`46-events.jpeg`（活动旧版）、`37-home-mist.jpeg`/`04-me.jpeg`（我的旧版，注意标题与图表已变）；宽屏看 `docs/validation/home-wide-start-api26.png`、`home-wide-bottom-api26.png`、`task-axis-home-wheel-api26.png`（忽略顶部测试面板）。
- 本审计未修改任何源码或既有文档，仅新增本文件。
