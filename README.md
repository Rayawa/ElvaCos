# 绮绣 / ElvaCos

HarmonyOS 原生、离线优先的 Coser 个人管理应用。首版聚焦从角色灵感到项目准备、出展清单和照片归档的闭环，无账号、无服务器。

## 首版功能

- 主页 HdsTabs 五个入口，各 Tab 独立 HdsNavigation / NavPathStack；外层路由承载覆盖主页的 HdsNavDestination 详情与设置。Tab 内二级使用原生 Segment Buttons，详情使用独立 HdsTabs 操作栏，新增与编辑统一 bindSheet。
- 连续新建 Cos 计划：选择已有角色或一起创建新角色，保存后进入准备页；角色版本、装备衣柜与漫展的搜索、关联、编辑和删除确认。
- 准备 / 打包 / 照片三个任务视图；装备跨计划复用和就地创建，自动生成打包项；装备可用率与打包确认分开显示，未装包物品优先并显示存放位置。
- 系统 PhotoPicker 导入选中照片；一份沙箱原图与缩略图；待选 / 已选 / 待修 / 成片筛选，批量选片与状态更新；角色封面与作品集。
- 首页优先显示最近有日期的未完成计划，打包与选片直接进入对应视图；Cos 默认计划列表并按状态筛选。
- 项目时间轴、预算记录；加密 RDB、事务和数据版本。
- 直接复用 dashboard-HarmonyOS 的浅/深色配色、HDS 浮动底栏与 titleBar 分段、按压光场、HDR 版本隔离、软/硬触觉和弹簧动效；可选智感握姿带权限、设备降级和防抖。
- 应用外观提供天蓝（浅色）/ 雾蓝（深色）/ 跟随系统三档，复用 Dashboard 的同名颜色资源，切换即时生效并持久化；设置页自上而下为图标中英文、分割线、华为账号（登录与云同步状态）、数据与备份、设置组、帮助与版本信息。华为账号使用 Account Kit 登录，云空间同步仍在路线图中。
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
```

脚本默认 DevEco 在 `~/Applications/DevEco-Studio.app`，可用 `DEVECO_HOME` 指向 app 或 Contents。HAP 在 `entry/build/default/outputs/default/`。`device-test.sh` 需要签名配置与已连接的鸿蒙设备，可用 `HDC_TARGET_ID` 指定设备；测试使用模块 Context，无需启动前台页面；使用独立临时加密数据库，完成后删除，不写用户的 personal.db。

## 架构与维护

[统一风格与复用来源](docs/UI_STYLE.md)、[架构与数据关系](docs/ARCHITECTURE.md)、[能力版本矩阵](docs/CAPABILITIES.md)、[路线图](docs/ROADMAP.md)、[验证记录](docs/VALIDATION.md)。

UI → AppState/领域规则 → Repository → RDB。MediaRepository 独立管理文件与缩略图；系统能力由 services 适配。页面、持久化与设置状态边界明确，使用状态管理 V2。照片网格使用 LazyForEach，元数据查询分批读取。

## 数据说明

元数据导出 JSON 是便携交换文件，非应用存储格式；它不包含照片。恢复前有确认；验证格式与字段后在事务中替换，失败保留原数据。本机仍存在的匹配照片会继续使用，其他照片显示待恢复。完整媒体迁移请使用系统备份，并在目标设备验证恢复结果。

未运行过 API 23 真机、多窗/折叠设备、系统跨设备备份、真实握姿和近场分享的能力，不作为已通过验收宣称。
