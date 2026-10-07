# 工程参考

本文件帮助快速了解仓库，不是固定开发流程。**以用户当前任务为准**；README 和 docs 中的历史方案、参数、检查清单与未验收项不自动约束后续任务。可以根据实际问题调整结构、交互和实现方式，不需要为偏离旧方案另行请求确认。

## 当前工程

- 原生 HarmonyOS / ArkTS / ArkUI / Stage，目标 API 26，最低兼容 API 23。
- `ability / common / component / pages` 参考 Dashboard；ElvaCos 的领域与持久化保留在 `model / data`。
- 当前导航为五个 HdsTabs、各自 HdsNavigation / NavPathStack 和覆盖式 HdsNavDestination。
- 应用状态入口是 `common/appState.ets`；设置由 Preferences 持久化并通过 StorageLink 绑定。
- 版本基线为 1.0.0-beta.1（10000001）；打包与签名边界见 docs/RELEASE.md，历史验证见 docs/VALIDATION.md。
- 当前 Theme / ThemePalettes 提供五组浅深配色，Statistics 与 component/charts 管理花费趋势/照片分布；离线示例由 DemoDataRepository 管理，Release 不自动填充。
- 当前配色、图标、反馈工具分别在 Theme、Icons 和 common；通常先复用已有能力，再判断是否需要扩展。
- Dashboard 参考位置：`/Users/raychen/Develop/Dashboard/dashboard-HarmonyOS`。按当前修改范围查阅相关文件即可，不要求每次通读两套工程。

## 设计与后续方案

下一轮体验重构的完整规格在 `docs/UX_RESTRUCTURE_PLAN.md`（v2）。**尚未执行**：代码现状仍是旧的五入口（首页 / Cos / 活动 / 衣柜 / 我的），不要按目标结构描述现状。改页面、导航、数据口径或新增实体前，先读该文档第 0 章的硬约束；与其中的规则冲突时先改文档再改代码。

- 一级入口冻结为 5 个 + 设置；新概念不得新增 Tab。
- 收藏类需求只用「收录」一个原语（`entries`）；角色的 ★ 仍叫「收藏」，两词不混用（名词表见第 10 章）。
- 每个实体只有一个可编辑的「家」；别处只做筛选视图与摘要行；跨页跳转必须携带上下文并定义返回恢复点。
- 同一业务数字由模型层算一次（`PlanReadiness`），页面不各写一遍过滤。
- 页面承载多于一类内容家族时用标题栏分段，不纵向堆叠（首页与今天模式标题区除外，分段清单见第 3.8 节）。
- 会出现的入口必须会消失；失败不谎报成功，写入失败与刷新失败分开表达。

## 实施判断

围绕当前目标完成必要改动，保留有价值的业务逻辑；发现过时约定可以一并更新。新增系统能力时按涉及的 API 核对华为官方文档和本机 SDK，避免套用其他平台写法。

验证分两档，**默认只做第一档**。

**开发期基础确认（默认，每次改动）**：`./scripts/build.sh` 编译通过即可；改动涉及数据库结构或颜色资源时，加跑 `python3 scripts/test_schema.py`、`python3 scripts/test_theme_colors.py`（两者都不需要设备）。

**设备套件（只在用户明确要求，或发布候选收口时跑）**：`device-test / ui-test / demo-test / layout-test / settings-layout-test / theme-test / ui-polish-test`。每个脚本都会重新构建主包与测试包、覆盖安装并在真机跑用例；`theme-test.sh` 还会克隆工程做多次构建与还原安装。连跑多个套件等于把同一份源码构建多遍，耗时是改动本身的数倍——要跑就只选直接相关的一个，并说明跑了哪个、结果如何。

Hypium 看 Pass / Failure / Error，不看命令退出码。设备脚本里硬编码的 `Tests run: N` 是当前用例数：数字不匹配时先判断是期望值过时还是真的失败（用例增删后需同步更新脚本），**不要为此反复重跑**。设备脚本串行执行，`device_test_lock.py` 会排队等待，看起来像卡住是正常的。设备不可用时记录边界，继续完成不依赖设备的工作。

涉及已有数据时保持兼容，结构变化通常采用增量迁移；验证使用隔离数据，不清空用户 personal.db。权限、删除和数据替换按真实功能与用户授权处理。本机签名、证书与私密配置保持在仓库之外。

文档用于说明现状、关键取舍和已知问题，只更新与本次任务有关的内容。路线图是备选方向，验证记录是当时的证据，都不是后续任务的强制清单。
