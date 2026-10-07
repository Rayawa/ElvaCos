# 首版架构与实施设计

版本基线：**1.0.0-beta.1（10000001）**；文档核对：2026-10-08。现状与历史证据；最终构建、签名与交付结论见 [打包记录](RELEASE.md)。

本文是工程现状与历史取舍的参考，不是后续任务的固定规程。以用户当前要求和实际代码为准；已有结构、实现方式、参数与检查范围可以随任务调整。

初版设计：2026-10-05；现状核对：2026-10-08。产品定位：本地、单用户的 Coser Personal OS，离线即可完整使用。

## 已检查的工程

Stage / ArkTS / ArkUI，entry 单 HAP；compatible 6.1.0(23)，target 26.0.0。本机 DevEco Studio 位于 ~/Applications；内置 SDK 26.0.0.105，Release。仅 Hypium、Hamock 测试依赖，无业务第三方依赖。当前使用 Git 管理工程。名称通过资源配置，业务不绑定 bundleName。用户指定直接复用 dashboard-HarmonyOS 的风格，详见 UI_STYLE.md。

## 信息架构与导航

保留五个一级入口：首页、Cos、活动、衣柜、我的。首页按照目标日期或关联漫展日期选择最近的未结束计划，有未来日期优先，逾期计划次之，未定日期最后；打包和选片入口携带对应任务视图。Cos 默认计划，切换角色资料/计划并筛选状态；衣柜切换装备/照片；我的聚合作品和时间轴，标题菜单进入独立设置页，不创建尚未实现的 People/Location/Pose 空页面。

主路由 HdsNavigation + NavPathStack 承载完整主页和覆盖式 HdsNavDestination。主页内保留五个 HdsTabs，每个 Tab 各自有 HdsNavigation / NavPathStack；切换和详情返回保留 Tab、分段、查询与滚动状态。角色、项目、资产、漫展、照片详情和设置压入主路由，详情显示时主页底栏完全隐藏。详情之间的关联跳转继续入主栈，返回逐层恢复。

二级切换仍使用 titleBar.stackBuilder 内居中的 HdsTitleBarSegment / TabSegmentButtonV2。一级动作通过 HDS 标题菜单提供；按 2026-10-06 用户要求，详情使用 HdsTabs 浮动操作栏替代原生 toolbar，动作点击通过 onContentWillChange 拦截内容切换，继续显示当前详情。新增角色、版本、项目、装备、漫展、清单项和编辑均使用 bindSheet，关联装备与照片导入项目选择也使用 Sheet；删除继续使用确认 Dialog。

设置覆盖主页，第一组直接复用 Dashboard SettingsPanel，其余组统一 HdsListItemCard 的图标、文本、控件列与帮助入口。材质等级成为视效唯一选择：流畅关闭视效，轻柔/精美开启对应等级；外观提供浅色/跟随系统/深色，主题配色独立提供五组；单手操作三档为左手/智感握持/右手，只有中间档开启感知权限与检测。旧独立开关通过 Preferences v2 显式转换，业务数据库不变。

以上为当前实现。下一轮体验重构（一级入口按目的重组、收录原语、今天模式、在途三态、角色履历与作品卡，以及 `entries` / 预算标记 / 在途 / 拍摄清单四项增量迁移）已整理为可执行规格，见 [体验重构规格 v2](UX_RESTRUCTURE_PLAN.md)；**尚未实施**，本文的现状描述在实施前保持有效。

## 实体关系

Character 1—N CharacterVariant；Character/Variant 1—N CosProject；Event 1—N CosProject。
CosProject N—M Asset，通过 project_assets 关联，复用同一资产。
CosProject 1—N ChecklistItem；CosProject 1—N PhotoAsset；PhotoAsset 1—N PhotoVersion。
DiaryEntry 记录项目生命周期。照片保留项目、角色上下文，P1 增加 Shoot/PhotoSet 关系。
当前以 expenses 和 team_members 保存实际花费与本机团队分工；采购/分期、独立拍摄/照片集、在线协作、妆造地点库与平台发布记录仍属扩展，不建空实现。

## 数据库

RDB 保存结构化元数据，Preferences 保存主题、触觉、单手偏好、视效等级与可选本机账号身份；业务实体保存在 RDB。基础 v1 表：characters、variants、events、projects、assets、project_assets、checklist_items、photos、photo_versions、diary_entries。当前数据库为 v3，增量加入准备分类/任务、团队、花费和参考图；外键、级联/SET NULL 策略、索引和 CHECK 约束保障关系。金额以分保存，日期为 YYYY-MM-DD，时间戳为毫秒。迁移在事务中执行；拒绝打开未来版本，避免降级破坏。事务使用同一 RdbStore 写连接的 beginTransaction / commit / rollBack；真机确认 createTransaction 独立连接不继承 foreign_keys，不能混用。AppState 串行写入，Database 拒绝嵌套或并发事务。Repository 负责 SQL，页面只调用应用状态及业务方法。

照片导入默认仅导入用户选中的图片，一份沙箱原文件 + 一份低分辨率缩略图；保留 source_uri 作来源标识，不依赖临时 URI 权限。图片列表只展示缩略图，详情才读取原图；不修改系统相册原文件。PhotoVersion 保存编辑参数和派生路径，与 PhotoAsset 独立。首版编辑器不扩展到重型修图。

备份：Repository 元数据以带格式/版本的 JSON 显式导出；恢复验证表/列/类型/约束，在 RDB 事务内替换；本机可信照片匹配复用。媒体随系统 BackupExtension 的 files 目录备份；手工元数据备份不冒充完整照片备份，恢复后显示缺失照片状态。删除本地数据需确认，且不删除系统相册。

## 目录与责任

entry/src/main/ets/
- ability/entry、backup：Stage 入口、后台与销毁清理、系统备份
- pages/Dashboard：五个 Tab 的 HdsNavigation/NavPathStack、覆盖详情、启动与维护调度
- pages/main/：五个一级业务页面
- pages/detail/：角色、计划、装备、活动、照片、参考图详情
- pages/more/：SettingsPage、DevPage、ExpenseSummaryPage、AppLogPage、LocalHtmlPage
- component/：复用的 HDS 导航/卡片/设置、表单字段、照片网格、活动日历与 charts 下的 Canvas 图表
- common/：appState 公共存储边界、constants 公共常量、types、主题/日期/反馈、偏好和系统能力
- model/：ApplicationState、实体、领域规则、ProjectRoute 与 EditDraft
- data/database/：schema、递增迁移、连接和事务
- data/repository/：结构化持久化、关系查询与 MetadataBackupRepository 的版本化元数据/恢复事务
- data/media/：选中媒体导入、缩略图、原文件清理

首页与设置共享 `component/DashboardSplitLayout`：在实际内容宽度达到 Theme.wideBreakpoint（840vp）且高度至少 600vp 时复用 Dashboard 的固定概览 / 独立滚动分栏，4:6 权重和 1440vp 最大宽度。页面仅提供业务 builder 与各自 Scroller，不维护另一套导航、颜色或反馈。首页在较窄窗口恢复单列，主路由仍为 Stack；内容分栏不代表覆盖式详情已经实现大屏双栏。

`common/scroll` 原样复用 Dashboard 的轴事件转发，五个主页与设置复用各自 Scroller；页面不访问输入设备服务或申请全局监听权限。首页任务用 TaskLinkCard、最近照片用 InteractiveCard 统一反馈；组件只发出原有路由动作，不持有实体仓库或业务写入方法。

@ObservedV2 / @Trace 应用状态承担异步状态与 UI 刷新；实体使用明确 ArkTS 类型。不使用 any、动态属性或解构逃避 ArkTS 检查。

## 首版实施过程（历史）

1. 先确认 SDK 和 API，写本设计及能力矩阵（已完成）。
2. 数据模型、RDB 迁移、领域规则：通过编译及 SQLite 关系测试。
3. 当时逐步完成角色/版本/项目/资产复用/漫展/清单闭环，并构建 HAP。
4. PhotoPicker、沙箱媒体、缩略图、工作流状态、作品集。
5. 设置、导出恢复、清空确认、深色/大屏/无障碍、系统分享及原生反馈。
6. 单元/设备测试、构建记录、真机验收清单和首版交付。

以上为首版的实施顺序，不作为以后任务的执行模板。后续方向与已知问题见 ROADMAP。

## 2026-10-06 初轮 UX 落地

- 新建计划 Sheet 内选择已有角色或创建新角色；角色 + 计划 + 时间轴通过 CosProjectRepository 的同一事务提交。基本信息先显示，版本、关联漫展、状态和预算逐步展开。保存成功才打开准备页，取消和失败不留下半份记录。
- ProjectRoute 为每个计划详情保存独立的准备/打包/照片视图。任务分段置于原生 titleBar；底部 HdsActionTabs 随视图提供对应动作，返回关联详情后保留任务视图。
- 准备页管理本次装备，可用率仅统计关联装备状态，不代表整体准备任务完成。已有打包确认仍使用 checklist_items；打包页显示未完成优先、位置和装包按钮，照片页支持状态筛选、当前筛选全选与批量状态更新。
- 计划内新增装备不访问 SQL；EditDraft 将项目上下文传入 AppState，AssetRepository 在同一事务保存装备、关联和打包项。漫展内可以创建自动关联的计划，也可通过 Sheet 关联尚未绑定漫展的既有计划。
- PhotoAssetRepository 在事务中核对批量选择是否仍存在，再统一更新，任一记录失效全部回滚。
- 本轮未改变关系结构，继续使用 schema v1 与既有元数据备份。视频中的分类准备任务、参考图、团队、待定/多天日程属于后续领域扩展，不能由装备可用率或打包确认代替。

## 2026-10-06 全局一致性修正

- 安全区：外层 HdsNavigation、每个 Tab 的内层 HdsNavigation 与 HdsNavDestination 统一 `ignoreLayoutSafeArea(SYSTEM, TOP|BOTTOM)`，标题栏 `avoidLayoutSafeArea`；内容顶部留白按页面级别分档（一级 `contentTop`=100vp，二级 `detailTop`=100vp，标题栏含分段时 `detailTopWithSegment`=112vp），底部留白 96/110vp，均以滚动内容内的 `Blank()` 实现，页面不依赖 padding。
- 主题：`common/Theme.ets` 为 `@ObservedV2` 单例（`Theme`），颜色字段为 `@Trace Resource`。`ThemePalettes` 提供蓝、绿、粉、橙、红五组成对资源；蓝色仍引用 Dashboard 原同名资源。配色 themeColor 与外观 appearance 分别持久化，外观浅色 / 深色 / 跟随系统使用 `setColorMode(COLOR_MODE_LIGHT | COLOR_MODE_DARK | COLOR_MODE_NOT_SET)`，系统解析 base / dark。`SettingsService.load/save` 负责读取、保存与应用，根 `WithTheme` 同步原生控件强调色；业务页面只消费 Theme，不直接引用 `app.color.*`。
- 安全区分级：内层 HdsNavigation 的标题栏 `avoidLayoutSafeArea: true`，HdsNavDestination 为 `false`（HDS 已自行避让，再开一次会把标题栏下移一个状态栏高度）。
- 偏好：仍在单一 `app_storage`。新增 `appearance`（sky/mist/system）与 `hand` 两个 key（`getAppearance/setAppearance`、`getHand/setHand`），`hand` 同时同步旧的 `holdCheckON` / `buttonPositionRIGHT`，旧数据由 `SettingsMigration` 显式转换。华为账号只持久化 OpenID / UnionID / 展示名 / 登录时间，不保存 authorizationCode 与 idToken。
- 弹层：`common/sheet.ets` 的 `appSheetOptions()` 与 `component/SheetHeader` 统一内容弹层；表单（`FormEditor`）、计划关联（`ProjectDetail`）、漫展关联（`EventDetail`）、帮助（`SettingsPage`）、导入选择（`Dashboard`）全部为 bindSheet + 右上角关闭，返回键关闭后由 `onDisappear` 复位状态。
- 华为账号：`common/AccountService.ets` 适配 Account Kit 的 `authentication`（syscap `SystemCapability.AuthenticationServices.HuaweiID.Auth`），登录失败按错误码给出可读提示；`AppState.signInHuawei / signOutHuawei` 维护登录态并在成功后写入 Preferences。云空间同步未实现，设置页只显示状态说明。

## 2026-10-07 · 准备与活动领域扩展

数据库保留原 v1 SQL，v2 新增 preparation_categories / preparation_tasks，v3 新增 team_members / expenses / reference_images，并为 events 增量添加日期模式、结束日期、时间模式、类型与本机提醒状态。全部待执行迁移在同一事务提交；已有打包完成状态不会转为准备完成。

准备任务的分类与项目使用复合外键，不能跨计划移动。连续创建中的角色、计划、模板任务与时间轴同事务保存。补入模板仅补缺失分类/任务，不重置自定义内容和完成状态。衣柜价格继续是装备资料，expenses 独立记录实际付款，不从共享资产价格推导支出。

参考图片恰好属于一份计划或一位角色；MediaRepository 管理沙箱原文件、缩略图、Picker 和孤立文件收集，统一保留照片与参考图。移除图片/项目时同步清除对应封面。媒体测试使用独立 verification 目录，不能把测试数据集传给生产媒体目录的 collect。

便携备份 v3 包含全部新表，兼容原 v1（10 表）和 v2（12 表）交换文件；先验证字段/跨日期规则，再在事务中替换。文件路径仅由本机已持有且本次备份保留的相同归属/来源记录匹配，不接受外来路径。系统提醒 ID 与提醒开关在恢复时复位，需要用户在本机重新开启。

EventSaveCoordinator 先尝试发布新提醒，再保存活动与提醒 ID，最后取消旧提醒。发布/授权失败降级为未开启提醒并保存活动；数据库失败只取消新提醒、保留旧提醒。取消旧提醒失败明确提示，启动时通过本应用有效提醒与数据库 ID 核对清理孤立提醒。只有用户主动选择提醒后请求通知授权；日期待定不能开启提醒。点击系统提醒携带 eventId，主路由在数据加载后进入该活动。

同一组件仅使用一个 bindSheet，按固定 sheet kind 选择内容，关闭时不切换到另一种内容；新增/编辑、项目关联与导入都保持统一 SheetHeader。设备测试通过 scripts/device_test_lock.py 串行执行，防止同一 bundle 的套件互相强停。

活动 titleBar 的二级切换为列表 / 日历；列表内单独选择即将到来 / 已结束 / 日期待定，日历只按所选日期显示活动。五个一级入口的活动页标题、Tab、无障碍名称与新建动作保持一致。

## 2026-10-07 · 系统日历单向添加

DeviceCalendarDraft 是纯领域映射，DeviceCalendarService 仅负责 Calendar Kit 系统确认页。使用编辑页面创建系统管理的日程，不查询/改动其他日历数据，不保存或恢复系统日历 ID，因此无关系迁移。活动新建保存成功后将生成的 ID 写回 EditDraft，以便刷新后取得正确活动并打开日历；取消新建表单不进入系统页。

系统日历与应用代理提醒独立；日历默认提前 30 分钟，可在系统页修改，应用代理提醒仍需明确选择。应用保存、日历确认和后续系统管理的边界在界面注明。

AccountService 先核对模块 client_id 配置，再发送带随机 state 的请求并验证响应一致性。AppState 的 accountBusy 与通用写入 busy 分开，Preferences 写入/清除成功才改变界面身份。没有真实项目与凭据时不构造云存储请求或假同步成功状态。

## 2026-10-07 · Dashboard 工程结构重构

目录与状态边界以 Dashboard 为参考，独立保留 ElvaCos 的 model/data 层。common/appState 是 Ability 与根页面共享状态的唯一入口，通过 AppStorageV2.connect 保存 @ObservedV2 AppState；Dashboard 使用 V1 公有存储，本工程不把 V2 领域对象直接塞入 V1。页面显式注入 @Require @Param state，局部筛选、弹层、Scroller 与 NavPathStack 不持久化。Preferences 的磁盘 key 和迁移保持不变；PreferenceSettings 与 SettingsPanel 使用 @StorageLink，明确 Builder 桥接到 V2 控件，保存经原有持久化方法。

EntryAbility 先读取一次偏好并应用 ColorMode，再加载 pages/Dashboard。根页面 onPageShow 延后一轮事件循环加载 RDB；成功后延时执行媒体孤立文件收集和代理提醒核对。失败通过 loading/error 和重试入口报告；硬件/提醒失败不取消已保存的业务数据。onPageHide/aboutToDisappear 取消排队 Timer 并停止握姿，异步完成后检查可见性/请求代次。dispose 等待初始化、业务操作和偏好保存，再等待 RdbStore.close 的 Promise 完成后释放上下文。DetailDestination 与 Sheet 的显示生命周期继续复用已有动效工具；设置目的地共享根页面 MainEntranceSession，仅首次打开播放，缓存返回或重建直接显示完整内容。原生设置行及其内部控件不再绑定额外按压处理。

DevPage（开发者选项）由设置页版本号连点五次进入，同样沿用 DetailDestination，不新增一级入口；只提供示例数据载入与只读诊断信息（应用版本与构建号、数据库结构版本、系统能力、common/DeviceInfo 汇总的完整 deviceInfo 字段、本机记录数量）。只读行把值放在可换行、可复制的整行宽度里，长值不会撑破卡片。入口点击不振动，构建号不再显示在设置页版本信息里。

AppLogPage 从 constants 的 APP_LOG 读取版本说明；LocalHtmlPage 从 rawfile/privacy.html 读取 UTF-8 正文，过滤源文件隐藏模板和脚本，用原生 Text/Scroll 阅读，不维护第二份正文，不执行脚本或加载网络内容。读取支持 loading/error/retry，离开后取消排队任务并忽略过期结果。阅读与统计内容宽度上限 840vp，普通列表/详情上限 1440vp；短横屏首页/设置改为单列整体滚动。

ExpenseSummary 使用原生 Linear Progress 构成横向分类条形图，分为最小金额单位，占比基于当前计划范围的总花费，零总额返回 0；点击分类筛选明细，再次点击或取消筛选恢复全部，切换计划清除旧分类。Theme 同名资源提供深浅色，图形与金额/占比文字共同呈现，读屏播报类别/金额/占比/选中状态。保留备份、RDB 迁移和媒体所有权逻辑；本轮关系结构不变。

更新日志筛选保存在 AppLogPage 的 @Local 状态，@Computed 派生列表；该页面自行配置公共 DetailDestination 的三个原生标题菜单，不嵌套导航目的地。日志发布类型与构建号属于 ReleaseNote，正式/测试发布标识与空列表按真实数据呈现。

## 2026-10-08 · Beta 最终结构

主题新增 themeColor 偏好及 ThemePalettes，根 WithTheme 同步原生强调色；蓝色保持原资源，其他配色分别定义 brand / accent。model/Statistics 提供整数分的月度支出聚合和互斥照片状态分布，component/charts 移植 Dashboard Canvas 绘制，花费分类仍用原生 Progress。PhotoGrid 稳定 IDataSource 并在筛选/选择/列数变化时通知刷新。

DemoDataRepository 管理离线追加示例及 demo_data_state 首次检查标记；它是内部加载标记，不升级业务 schema 或备份格式。BuildProfile.DEBUG 控制空库自动载入，Release 保持空白；手动载入保留已有记录，存在示例 ID 时整批跳过，不重新补回已编辑或删除的示例。媒体导入失败清理本次新增文件，数据写入事务回滚。

本次仅补齐版本日志、打包模式与公开描述/vendor；业务数据库仍为 v3、便携备份仍为 v3。打包脚本支持工程级 assembleApp，Release 编译不等于发行签名。具体产物和测试证据以 RELEASE / VALIDATION 为准。
