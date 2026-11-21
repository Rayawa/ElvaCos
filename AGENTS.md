# 工程约定

以用户当前任务为准。历史方案与验证记录不自动约束后续任务。

## 平台与交互

- 原生 HarmonyOS / ArkTS / ArkUI / Stage；目标 API26，最低兼容 API20。
- 参照 Rayawa/dashboard 的平台判断方式。新 API 先在 `ui/platformCompatibility.ets` 判断，不能在旧系统启动路径解析新枚举或调用新方法。API26 的 apiAvailable 不能用于 API20 的基础判断。
- 主页面使用 HdsTabs，页内内容使用原生 SegmentButtons；二级页面内切换使用 HdsTabs。
- 工具操作使用 HDS 标题栏菜单按钮，底部 HdsTabs 只承担视图切换。
- 二级目的地每次显示都播放进场动画，包括缓存后返回；返回控制由入口 onBackPress 与 DetailDestination.onBackPressed 共同承担。
- 短时任务使用 bindSheet；主宿主与当前目的地合计最多两个挂载。Sheet 内的收录编辑复用原宿主，隐藏目的地释放内容。按钮关闭、系统返回、手势关闭使用相同的未保存检查和反馈。
- 页面与分区使用单一标题，不堆叠大标题、小标题。只有带框卡片允许一组主标题与副标题。
- 优先原生组件；保留震动、按压、动画、光场与无障碍标签。

## 文件职责

- `index.ets` 是 ETS 根目录的唯一文件，承担五个 Tab、路由注册和页面生命周期。
- `ability` 放 Stage 与备份入口。`pages` 放完整页面，`views` 放业务视图，`components` 放可复用控件。
- `viewmodels` 放应用状态、表单会话和可观察的页面状态。`models` 放实体及纯业务规则。
- `services` 放系统集成和持久化，数据库及仓储归 `services/storage`。
- `ui` 放主题、图标、交互反馈、动画、布局及平台 UI 能力。`utils` 放无状态通用工具。
- 目录默认平铺。使用四空格缩进，重用模型层派生数据和索引，避免在 build 中执行 I/O 或重复遍历全量关联集合。

## 数据与验证

保留现有数据和增量迁移；不清空 personal.db。每个实体只有一个可编辑的家，跨页保留来源、筛选与返回位置。业务数字沿用 PlanReadiness 统一口径。写入失败与已写入但刷新失败分开表达。

基础检查：

```sh
node scripts/check-project-structure.cjs
node scripts/test-runtime.cjs
node scripts/test_ux_models.cjs
python3 scripts/test_schema.py
python3 scripts/test_theme_colors.py
./scripts/build.sh
```

模型与运行时分支检查可以在 Node24 上运行，也可使用本机 DevEco 的 TypeScript。它们不能替代鸿蒙编译或真机验证。文件迁移后执行干净 Debug 构建；同步导入、Ability、页面声明、脚本和有效文档链接。

设备套件默认不连跑；仅按当前任务选择相关套件，使用隔离测试数据。Hypium 看 Pass / Failure / Error，不仅看进程退出码。缺少 SDK 或设备时明确说明未验证部分，不将静态检查作为真机通过。

只更新本次相关文档；进度和验证结果在对话中说明，不新增逐轮报告。
