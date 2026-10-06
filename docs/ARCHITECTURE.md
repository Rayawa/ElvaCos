# 首版架构与实施设计

日期：2026-10-05。产品定位：本地、单用户的 Coser Personal OS，离线即可完整使用。

## 已检查的工程

Stage / ArkTS / ArkUI，entry 单 HAP；compatible 6.1.0(23)，target 26.0.0。本机 DevEco Studio 位于 ~/Applications；内置 SDK 26.0.0.105，Release。仅 Hypium、Hamock 测试依赖，无业务第三方依赖。当前不是 Git 仓库。名称通过资源配置，业务不绑定 bundleName。用户指定直接复用 dashboard-HarmonyOS 的风格，详见 UI_STYLE.md。

## 信息架构与导航

保留五个一级入口：首页、Cos、漫展、衣柜、我的。首页按照目标日期或关联漫展日期选择最近的未结束计划，有未来日期优先，逾期计划次之，未定日期最后；打包和选片入口携带对应任务视图。Cos 默认计划，切换角色资料/计划并筛选状态；衣柜切换装备/照片；我的聚合作品和时间轴，标题菜单进入独立设置页，不创建尚未实现的 People/Location/Pose 空页面。

主路由 HdsNavigation + NavPathStack 承载完整主页和覆盖式 HdsNavDestination。主页内保留五个 HdsTabs，每个 Tab 各自有 HdsNavigation / NavPathStack；切换和详情返回保留 Tab、分段、查询与滚动状态。角色、项目、资产、漫展、照片详情和设置压入主路由，详情显示时主页底栏完全隐藏。详情之间的关联跳转继续入主栈，返回逐层恢复。

二级切换仍使用 titleBar.stackBuilder 内居中的 HdsTitleBarSegment / TabSegmentButtonV2。一级动作通过 HDS 标题菜单提供；按 2026-10-06 用户要求，详情使用 HdsTabs 浮动操作栏替代原生 toolbar，动作点击通过 onContentWillChange 拦截内容切换，继续显示当前详情。新增角色、版本、项目、装备、漫展、清单项和编辑均使用 bindSheet，关联装备与照片导入项目选择也使用 Sheet；删除继续使用确认 Dialog。

设置覆盖主页，第一组直接复用 Dashboard SettingsPanel，其余组统一 HdsListItemCard 的图标、文本、控件列与帮助入口。材质等级成为视效唯一选择：流畅关闭视效，轻柔/精美开启对应等级；外观只跟随系统；单手操作三档为左手/智感握持/右手，只有中间档开启感知权限与检测。旧独立开关通过 Preferences v2 显式转换，业务数据库不变。

## 实体关系

Character 1—N CharacterVariant；Character/Variant 1—N CosProject；Event 1—N CosProject。
CosProject N—M Asset，通过 project_assets 关联，复用同一资产。
CosProject 1—N ChecklistItem；CosProject 1—N PhotoAsset；PhotoAsset 1—N PhotoVersion。
DiaryEntry 记录项目生命周期。照片保留项目、角色上下文，P1 增加 Shoot/PhotoSet 关系。
Purchase、BudgetItem、Shoot、Collaborator、MakeupLook、Location、PublishRecord 属于 P1 扩展；不在 P0 建空实现。

## 数据库

RDB 保存结构化元数据，Preferences 仅保存主题、触觉、单手偏好和视效开关。数据库 v1：characters、variants、events、projects、assets、project_assets、checklist_items、photos、photo_versions、diary_entries。外键、级联/SET NULL 策略、索引和 CHECK 约束保障关系。金额以分保存，日期为 YYYY-MM-DD，时间戳为毫秒。迁移在事务中执行；拒绝打开未来版本，避免降级破坏。事务使用同一 RdbStore 写连接的 beginTransaction / commit / rollBack；真机确认 createTransaction 独立连接不继承 foreign_keys，不能混用。AppState 串行写入，Database 拒绝嵌套或并发事务。Repository 负责 SQL，页面只调用应用状态及业务方法。

照片导入默认仅导入用户选中的图片，一份沙箱原文件 + 一份低分辨率缩略图；保留 source_uri 作来源标识，不依赖临时 URI 权限。图片列表只展示缩略图，详情才读取原图；不修改系统相册原文件。PhotoVersion 保存编辑参数和派生路径，与 PhotoAsset 独立。首版编辑器不扩展到重型修图。

备份：Repository 元数据以带格式/版本的 JSON 显式导出；恢复验证表/列/类型/约束，在 RDB 事务内替换；本机可信照片匹配复用。媒体随系统 BackupExtension 的 files 目录备份；手工元数据备份不冒充完整照片备份，恢复后显示缺失照片状态。删除本地数据需确认，且不删除系统相册。

## 目录与责任

entry/src/main/ets/
- pages/Index：生命周期及导航组装
- components/：复用的卡片、空状态、表单字段、照片网格
- features/home、cos、project、asset、event、photo、settings：功能 UI
- model/：实体、领域规则和表单类型
- data/database/：schema、迁移、连接和事务
- data/repository/：结构化持久化、关系查询与 MetadataBackupRepository 的版本化元数据/恢复事务
- data/media/：导入、缩略图、原文件清理
- services/：能力检查、分享、触觉、握姿、文档选择器备份入口、设置；不直接访问 RDB
- common/：设计 token、日期、错误处理

@ObservedV2 / @Trace 应用状态承担异步状态与 UI 刷新；实体使用明确 ArkTS 类型。不使用 any、动态属性或解构逃避 ArkTS 检查。

## 分阶段验证

1. 先确认 SDK 和 API，写本设计及能力矩阵（已完成）。
2. 数据模型、RDB 迁移、领域规则：通过编译及 SQLite 关系测试。
3. 角色/版本/项目/资产复用/漫展/清单闭环：每个阶段构建 HAP。
4. PhotoPicker、沙箱媒体、缩略图、工作流状态、作品集。
5. 设置、导出恢复、清空确认、深色/大屏/无障碍、系统分享及原生反馈。
6. 单元/设备测试、构建记录、真机验收清单和首版交付。

P0 是本轮交付目标。P1/P2 在 ROADMAP 中单独管理；未经设备验证的硬件能力不标记为验收通过。

## 2026-10-06 初轮 UX 落地

- 新建计划 Sheet 内选择已有角色或创建新角色；角色 + 计划 + 时间轴通过 CosProjectRepository 的同一事务提交。基本信息先显示，版本、关联漫展、状态和预算逐步展开。保存成功才打开准备页，取消和失败不留下半份记录。
- ProjectRoute 为每个计划详情保存独立的准备/打包/照片视图。任务分段置于原生 titleBar；底部 HdsActionTabs 随视图提供对应动作，返回关联详情后保留任务视图。
- 准备页管理本次装备，可用率仅统计关联装备状态，不代表整体准备任务完成。已有打包确认仍使用 checklist_items；打包页显示未完成优先、位置和装包按钮，照片页支持状态筛选、当前筛选全选与批量状态更新。
- 计划内新增装备不访问 SQL；EditDraft 将项目上下文传入 AppState，AssetRepository 在同一事务保存装备、关联和打包项。漫展内可以创建自动关联的计划，也可通过 Sheet 关联尚未绑定漫展的既有计划。
- PhotoAssetRepository 在事务中核对批量选择是否仍存在，再统一更新，任一记录失效全部回滚。
- 本轮未改变关系结构，继续使用 schema v1 与既有元数据备份。视频中的分类准备任务、参考图、团队、待定/多天日程属于后续领域扩展，不能由装备可用率或打包确认代替。
