# 绮秀 / ElvaCos

HarmonyOS 原生、离线优先的 Coser 个人管理应用。从角色灵感、Cos 计划、准备与打包，到活动日程、照片归档和实际花费，核心业务可在本机完成。

当前版本 **1.0.0-beta.1**，构建号 **10000001**，包名 `top.rayawa.elvacos`。目标 API 26，最低兼容 API 23；以手机为主要验证设备，清单同时声明 Tablet / 2in1。

2026-10-08 已完成 Release 清理构建与包内容核验。当前签名为 **开发调试 Profile**；产物适用于获授权设备的 Beta 测试，应用市场发行仍需发行证书/Profile。完整结果、产物指纹和已知边界见 [Beta 打包记录](docs/RELEASE.md)。

## 已实现功能

- **角色与计划**：角色/版本、连续新建计划、准备模板、自定义分类/任务、截止日期与备注；准备完成、装备可用和装包确认分别记录。装备可跨计划复用，也可在计划内创建并生成打包项。
- **活动与出行**：待定/单日/多日、时间段、列表/月历、关联计划；用户主动开启系统提醒后申请通知授权。可添加到设备日历确认页，账户和提醒由系统管理。
- **照片与参考资料**：系统 PhotoPicker 导入选中图片，保存沙箱原图及缩略图；筛选、多选、批量状态更新、角色封面、参考图及作品集。作品集仅显示最终作品和已发布照片，「已发布」是本机状态记录。
- **团队与花费**：本机姓名/分工/备注、逐笔实际付款、预算对比、计划/分类筛选、分类金额条形图、近半年月度趋势，以及全部照片的处理状态环形分布。衣柜价格不会自动记成实际支出。
- **导航与外观**：首页 / Cos / 活动 / 衣柜 / 我的五个 HdsTabs；各 Tab 独立导航，详情覆盖主页，表单和关联使用 Sheet。蓝、薄荷绿、樱花粉、杏橙、珊瑚红五组配色；浅色 / 跟随系统 / 深色独立持久化。首页与设置根据容器宽高切换单列/分栏，照片网格适配宽度。
- **设置与系统能力**：材质、触觉、单手/可选智感握姿、设置首次入场、原生列表触摸；更新日志支持 Beta / RC / 正式版筛选，本地隐私正文使用原生阅读页；Share Kit 分享项目摘要及版本化业务对象。
- **数据保护**：加密 RDB v3、v1→v2→v3 增量迁移、事务、便携元数据备份 v3 兼容 v1/v2，系统 BackupExtension 已注册。
- **离线示例**：16 个角色、24 个计划、84 件装备、12 个活动及配套任务、花费和图片。调试构建首次空库自动加载；Release 构建不自动填充，可从设置手动追加。详见 [示例数据](docs/DEMO_DATA.md)。

账号为可选身份入口。已接入 Account Kit 并配置公开 Client ID，但此前真实登录返回 `1001502003`，尚未验收成功；应用云同步未实现。本机团队记录不包含在线协作。

## 构建与打包

本机工具链：DevEco Studio 26.0.0，内置 Release SDK 26.0.0.105；ArkTS / ArkUI / Stage。无业务第三方依赖，Hypium / Hamock 仅用于测试。

新检出先复制 `build-profile.example.json5` 为 `build-profile.json5`。示例不含签名引用，可用于未签名构建；需要设备安装或发行时，通过 DevEco 配置自己的签名。`build-profile.json5`、证书、私钥及密码保持在版本控制之外。

```sh
# 开发 HAP（默认 debug）
./scripts/build.sh
# 测试 feature
./scripts/build.sh assembleHap ohosTest
# Release 全量 HAP / APP
./scripts/build.sh clean default release
./scripts/build.sh assembleApp default release
# 仅生成 Release HAP
./scripts/build.sh assembleHap default release
```

脚本参数为 `[task] [target] [debug|release]`；assembleApp 使用工程模式，其余任务使用模块模式。默认 DevEco 在 `~/Applications/DevEco-Studio.app`，`DEVECO_HOME` 可指向 app 或 Contents。

HAP 输出到 `entry/build/default/outputs/default/`，APP 输出到 `build/outputs/default/`。此次交付副本与 SHA-256 清单在 `build/releases/1.0.0-beta.1/`（构建目录不入库）。**Release 编译模式与发行签名是两回事**，勿将自动调试签名包当作市场发行包。

## 验证

```sh
# 基础确认（开发期默认，不需要设备）
./scripts/build.sh
python3 scripts/test_schema.py
python3 scripts/test_theme_colors.py

# 设备套件（仅用户要求或发布候选；已连接且解锁，可用 HDC_TARGET_ID 选择设备）
./scripts/device-test.sh
./scripts/ui-test.sh
./scripts/demo-test.sh
# 修改相关布局/主题时选用
./scripts/layout-test.sh
./scripts/settings-layout-test.sh
./scripts/theme-test.sh
./scripts/ui-polish-test.sh

# 发布候选：核对交付产物
python3 scripts/check_release.py --hap build/releases/1.0.0-beta.1/ElvaCos-1.0.0-beta.1-release-signed.hap --app build/releases/1.0.0-beta.1/ElvaCos-1.0.0-beta.1-release-signed.app
```

**默认只做基础确认**：一次 `build.sh` 加上按改动类型选择的 Python 检查（不需要设备）。设备套件每个脚本都会重新构建主包与测试包、覆盖安装并在真机跑用例，`theme-test.sh` 还会克隆工程做多次构建与还原安装；连续跑多个套件等于把同一份源码构建多遍，耗时是改动本身的数倍。所以只在明确要求或发布候选收口时跑，且一次只选直接相关的一个。

设备脚本串行执行（`device_test_lock.py` 排队等待），Hypium 以 Pass / Failure / Error / Ignore 判断；脚本里硬编码的 `Tests run: N` 是当前用例数，数字不匹配时先确认是期望值过时还是真的失败，不要反复重跑。领域与示例测试使用独立加密数据库及媒体目录，布局/主题宿主使用内存数据或独立 Preferences。测试不清空用户 `personal.db`。多数脚本生成调试主包，若需要恢复本次 Release HAP，安装已保存的交付副本；最终打包检查使用 Release 主包复测，结果见 [验证记录](docs/VALIDATION.md)。

手机中的宽屏画布只验证组件布局，不代替真实 Tablet / 2in1、多窗、折叠及系统安全区验证。API 23 真机、系统字号/读屏人工体验、系统跨设备完整备份、提醒实际后台送达及部分硬件能力仍缺少完整证据。

## 结构与数据

```text
entry/src/main/ets/
├── ability/          # Stage / 系统备份生命周期
├── common/           # appState、偏好、Theme、图标与系统能力
├── component/        # 导航、设置、表单、网格、Canvas 图表
├── pages/
│   ├── Dashboard.ets # 五页导航与启动调度
│   ├── main/         # 首页、Cos、活动、衣柜、我的
│   ├── detail/       # 角色、计划、装备、活动、照片、参考图
│   └── more/         # 设置、花费、更新日志、隐私阅读
├── model/            # ApplicationState、实体、领域规则与统计
└── data/             # database、repository、media
```

UI → ApplicationState/领域规则 → Repository → RDB。`common/appState.ets` 通过 AppStorageV2 提供共享 V2 状态；设置经 Preferences / DiskStorage / AppStorage 持久化并由 StorageLink 绑定。页面局部维护筛选、弹层、滚动与导航上下文。分阶段启动与取消守卫避免过期异步回写，销毁等待操作及数据库关闭。

元数据 JSON **不含图片**，恢复是验证后的事务替换，失败保留原数据。本机匹配媒体可复用，跨设备完整媒体迁移需系统备份并另行验证。删除应用副本不删除系统相册原图。

## 文档导航

| 文档 | 内容 |
| --- | --- |
| [打包记录](docs/RELEASE.md) | 本次构建、产物、签名、交付边界 |
| [架构](docs/ARCHITECTURE.md) | 状态、数据库、媒体、生命周期 |
| [能力矩阵](docs/CAPABILITIES.md) | API / SysCap / 权限与降级 |
| [界面参考](docs/UI_STYLE.md) | Dashboard 来源、交互、响应式与反馈 |
| [主题](docs/THEMES.md) | 五组资源、持久化与可读性 |
| [示例数据](docs/DEMO_DATA.md) | 数据数量、来源、加载规则与隔离测试 |
| [华为账号](docs/HUAWEI_ACCOUNT_SETUP.md) | 公开 ID、证书、登录问题与云空间边界 |
| [验证记录](docs/VALIDATION.md) | 最新结果和历史证据 |
| [路线图](docs/ROADMAP.md) | 当前能力、已知问题、可选方向 |
| [视频参考](docs/UX_REFERENCE.md) | 历史观察与已落地范围 |
| [体验重构规格 v2](docs/UX_RESTRUCTURE_PLAN.md) | 未执行的设计规格：硬约束、导航与路由、数据口径、迁移与阶段 |

文档说明现状和取舍，历史方案与测试清单不自动约束后续任务。隐私正文唯一来源仍为 `entry/src/main/resources/rawfile/privacy.html`；其中云端服务、注销和撤回描述与当前离线能力有差异，本次记录该问题，尚未修订政策正文。正式对外发布前需核对实际能力与图片使用授权。
