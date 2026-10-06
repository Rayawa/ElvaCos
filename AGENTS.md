# 工程工作约定

本工程是原生 HarmonyOS / ArkTS / ArkUI / Stage 应用，最低 API 23。先读 README 与 docs/ARCHITECTURE.md，新增系统 API 时核对华为官方文档及本机 SDK 的 since、syscap、permission。

- 外层 HdsTabs 承载五页，各 Tab 独立 HdsNavigation / NavPathStack，详情 HdsNavDestination；主动作优先使用原生 toolbar，避免在内容区重复入口。
- 风格直接复用 /Users/raychen/Develop/Dashboard/dashboard-HarmonyOS：修改前读 docs/UI_STYLE.md；颜色走 Theme/同名深浅色资源，图标走 Icons，光场/振动/动画走复用工具，禁止在页面复制另一套反馈。
- UI 不访问 SQL；RDB 仅在 data 层；设置仅 Preferences；媒体走 MediaRepository。
- 不使用 any、unknown、动态类型、跨平台 UI 或 WebView。
- 每次修改关系型结构必须写递增迁移；禁止直接替换已有 schema 或隐式清库。
- 异步操作必须报告 loading/error，删除与替换数据必须确认；硬件增强不能阻塞核心数据功能。
- 不请求完整图库/联系人/定位权限来实现未来功能。Picker 仅处理用户明确选中的内容。
- 品牌在资源中配置。不要提交 build-profile.json5、local.properties 或本机证书；更新脱敏的 example 文件。
- 验证至少执行 scripts/build.sh；修改领域/关系/媒体/备份需运行有意义的现有测试。Hypium 必须检查 Pass/Failure/Error 字段，不能仅看 aa test 返回码。
- 设备测试使用隔离数据库并清理，禁止清空用户 personal.db 来验证业务。
- 新能力与未验收项更新 docs/ROADMAP.md / VALIDATION.md；未实现功能不创建假页面。
