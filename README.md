# 绮秀 / ElvaCos

HarmonyOS 原生、离线优先的 Coser 个人管理应用。首版聚焦从角色灵感到项目准备、出展清单和照片归档的闭环，核心业务不依赖账号或服务器；华为账号为可选本机身份入口，云同步尚未实现。

当前版本 **1.0.0-beta.1**，构建号 **10000001**；目标 API 26，最低兼容 API 23。

## 首版功能

- 主页 HdsTabs 五个入口，各 Tab 独立 HdsNavigation / NavPathStack；外层路由承载覆盖主页的 HdsNavDestination 详情与设置。Tab 内二级使用原生 Segment Buttons，详情使用独立 HdsTabs 操作栏，新增与编辑统一 bindSheet。
- 连续新建 Cos 计划：选择已有角色或一起创建新角色，保存后进入准备页；角色版本、装备衣柜与漫展的搜索、关联、编辑和删除确认。
- 准备模板可选任务，支持自定义分类、任务截止日期/备注；准备完成与装备可用、装包确认独立。准备 / 打包 / 照片三个任务视图；装备跨计划复用和就地创建，自动生成打包项；装备可用率与打包确认分开显示，未装包物品优先并显示存放位置。
- 系统 PhotoPicker 导入选中照片；一份沙箱原图与缩略图；待选 / 已选 / 待修 / 成片筛选，批量选片与状态更新；角色封面与作品集。
- 首页优先显示最近有日期的未完成计划，打包与选片直接进入对应视图；Cos 默认计划列表并按状态筛选。
- 准备参考图、角色参考图与封面；本机团队姓名/分工/备注；逐笔实际花费、分类/计划统计与预计预算对比。
- 活动支持待定/单日/多日及时间段，月历和当天活动；主动选择提醒后申请系统通知授权，失败仍保存活动；可带入设备日历确认页选择账户与提醒，不请求日历读写权限。
- 项目时间轴；加密 RDB、v1→v2→v3 增量迁移、事务；便携备份 v3 兼容 v1/v2。
- 直接复用 dashboard-HarmonyOS 的浅/深色配色、HDS 浮动底栏与 titleBar 分段、按压光场、HDR 版本隔离、软/硬触觉和弹簧动效；可选智感握姿带权限、设备降级和防抖。
- 应用外观提供天蓝（浅色）/ 跟随系统 / 雾蓝（深色）三档，复用 Dashboard 的同名颜色资源，切换即时生效并持久化；设置页自上而下为图标中英文、分割线、华为账号（登录与云同步状态）、数据与备份、设置组、帮助与版本信息。华为账号使用 Account Kit 登录，云空间同步仍在路线图中。
- 新增更新日志与隐私政策阅读页，统一使用覆盖式 HdsNavDestination；隐私正文唯一来源为 `entry/src/main/resources/rawfile/privacy.html`，由原生文本组件显示。
- 首页与设置按实际容器宽高切换单列/分栏；短横屏恢复完整滚动，详情限制内容宽度，花费分类条形图显示金额与占比并支持筛选；所有颜色沿用同名浅深色资源。
- 启动先水合偏好、首帧后加载业务数据，再执行媒体与提醒维护；定时器、握姿监听及过期异步回写有取消守卫，数据库销毁等待进行中的操作。新增控件、筛选状态、图表与阅读内容提供中文无障碍标签。
- Share Kit 系统分享项目摘要与版本化业务对象附加数据。
- 华为账号登录（Account Kit）：本机可离线使用的 OpenID / UnionID，不保存访问令牌；未开通 AGC 时按错误码提示，云同步不提供假入口。
- 便携元数据导出/验证恢复、本地清空；系统 BackupExtension 注册用于完整沙箱备份。

名称和图标配置在 AppScope 与资源中；业务代码不绑定品牌。碰一碰、ShareExtension、重型图片编辑、跨设备同步及更多 P1 功能在路线图中单独管理。

## 构建

DevEco Studio 26.0.0，内置 Release SDK 26.0.0.105；compatible API 23，target 26；Phone 优先，声明 Tablet / 2in1。ArkTS / ArkUI / Stage，无业务三方依赖。

新检出先将 `build-profile.example.json5` 复制为 `build-profile.json5`。后者被忽略，因为 DevEco 自动签名配置包含本机路径与私钥配置。通过 DevEco 配置自己的调试签名，勿将签名密码和证书纳入版本控制。

```sh
./scripts/build.sh
python3 scripts/test_schema.py
./scripts/device-test.sh
./scripts/ui-test.sh
./scripts/layout-test.sh
./scripts/settings-layout-test.sh
```

脚本默认 DevEco 在 `~/Applications/DevEco-Studio.app`，可用 `DEVECO_HOME` 指向 app 或 Contents。HAP 在 `entry/build/default/outputs/default/`。`device-test.sh` 需要签名配置与已连接的鸿蒙设备，可用 `HDC_TARGET_ID` 指定设备；测试使用模块 Context，无需启动前台页面；使用独立临时加密数据库，完成后删除，不写用户的 personal.db。

`settings-layout-test.sh` 验证首页与设置的组件布局，使用临时主模块和内存数据；包含两倍应用字号、短横屏和花费图表比例/筛选检查，结束自动恢复正式包及测试包，不改变系统字号。手机中缩放的宽屏画布仅用于验证布局，不代替真实平板、多窗与系统安全区验收。

## 架构与维护

[统一风格与复用来源](docs/UI_STYLE.md)、[架构与数据关系](docs/ARCHITECTURE.md)、[能力版本矩阵](docs/CAPABILITIES.md)、[路线图](docs/ROADMAP.md)、[验证记录](docs/VALIDATION.md)。

工程目录采用 Dashboard 的 `ability / common / component / pages` 形式，ElvaCos 的成熟领域与持久化继续独立保留：

```text
entry/src/main/ets/
├── ability/          # entry、backup 生命周期入口
├── common/           # appState、constants、types、偏好和系统能力、主题/反馈工具
├── component/        # 复用 UI、表单、照片网格、HDS 导航封装
├── pages/
│   ├── Dashboard.ets # 五页导航与启动任务
│   ├── main/         # 首页、Cos、活动、衣柜、我的
│   ├── detail/       # 角色、计划、装备、活动、照片、参考图详情
│   └── more/         # 设置、花费统计、AppLog、LocalHtml
├── model/            # ApplicationState、实体、领域规则、路由与表单
└── data/             # database、repository、media
```

UI → ApplicationState/领域规则 → Repository → RDB。MediaRepository 管理 Picker 与沙箱媒体，公共常量位于 `common/constants.ets`。数据库仍为 v3，既有 v1→v2→v3 SQL、备份格式和业务约束保持兼容，本轮没有关系结构变更。

采用 Dashboard 的公共存储访问边界：Ability 与根页面统一通过 `common/appState.ets` 获取共享状态；保留 ElvaCos 的 `@ObservedV2 / @Trace`，以官方 `AppStorageV2.connect` 管理同一实例。设置使用原有 Preferences → DiskStorage → AppStorage 通道，由 `@StorageLink` 绑定；V1 偏好组件通过明确的 Builder 与 V2 页面衔接。临时筛选、弹层与导航上下文保持页面局部。移除重复状态实例、无消费的窗口监听、废弃偏好/动画辅助入口及注释中的旧设置 UI。照片网格继续使用 LazyForEach，元数据查询分批读取。

## 数据说明

元数据导出 JSON 是便携交换文件，非应用存储格式；它不包含照片。恢复前有确认；验证格式与字段后在事务中替换，失败保留原数据。本机仍存在的匹配照片会继续使用，其他照片显示待恢复。完整媒体迁移请使用系统备份，并在目标设备验证恢复结果。

未运行过 API 23 真机、多窗/折叠设备、系统跨设备备份、真实握姿和近场分享的能力，不作为已通过验收宣称。

华为账号已配置用户提供的 Client ID，真机登录仍需解决 AGC / 签名 Profile 校验错误（1001502003）；接入与实测见 [账号与云空间配置](docs/HUAWEI_ACCOUNT_SETUP.md)。云同步尚未实现，元数据导出与设备日历的系统云同步分别说明，不能代替计划/照片同步。

隐私政策页面忠实读取提供的本地文件；其中云端服务、账号注销和撤回同意描述与当前离线能力仍有差异，正文未另行改写。发布前需由维护者核对，见 ROADMAP / VALIDATION。
