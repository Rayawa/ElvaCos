# HarmonyOS 能力核验

版本基线：**1.0.0-beta.1（10000001）**；文档核对：2026-10-08。现状与历史证据；最终构建、签名与交付结论见 [打包记录](RELEASE.md)。

本文是工程现状与历史取舍的参考，不是后续任务的固定规程。以用户当前要求和实际代码为准；已有结构、实现方式、参数与检查范围可以随任务调整。

初始 API 核验 2026-10-05；本次以实际 Release 包核对版本、权限和能力入口。以华为官方文档 + 本机 Release SDK 的 @since / @syscap / @permission 声明为依据，target 26 并不等于运行设备 API 26。

| 能力 | 起始版本/限制 | API 23 基线策略 |
|---|---|---|
| HdsNavigation / HdsNavDestination / HdsTabs | HdsNavigation 18、HdsNavDestination/HdsTabs 20；UIDesign.HDSComponent.Core；Stage | API 23 直接使用；主路由覆盖式详情，详情 HdsTabs 动作，主页五 Tab 独立导航 |
| TabSegmentButtonV2 $selectedIndex / onItemClicked | 18；ArkUI.Full；Stage；无新增权限；已核对本机 SDK @ohos.arkui.advanced.SegmentButtonV2.d.ets | 分别更新选中状态与处理点击反馈，直接复用 Dashboard 原调用方式 |
| onAxisEvent / AxisEvent / getVerticalAxisValue / getHorizontalAxisValue | 17；ArkUI.ArkUI.Full；Stage；无额外权限；common.d.ts 核验；修饰键查询继承 BaseEvent（12） | 直接复制 Dashboard common/scroll.ets，五个主页和设置将滚轮 / 触控板纵向轴事件交给页面 Scroller；忽略 Ctrl、纯横向与无效值 |
| ToolbarItem.symbolIcon / SymbolGlyphModifier | 12；ArkUI.Full；Stage；无额外权限 | Icons 集中提供原生 toolbar 加号/照片 Symbol，避免图片资源图标在详情工具栏缺失；其余语义图标保留原资源 |
| HDS hdsMaterial / systemMaterialEffect | 23；HDSComponent.Core；系统材质策略与设备性能限制 | 复用 Dashboard 的 ADAPTIVE 与持久化等级；不是 ArkUI API 26 的 uiMaterial 调用 |
| RDB relationalStore | 9；ArkData；沙箱无需额外权限 | 直接使用，版本迁移与外键事务 |
| Preferences | 9；ArkData | 设置使用，不保存实体或照片 |
| PhotoAccessHelper.PhotoViewPicker | 10；FileManagement.PhotoAccessHelper.Core | 用户选择无需全图库读取权限；异步复制选中照片，保留来源 URI |
| CoreFileKit fileUri.getUriFromPath | 9；FileManagement.AppFileService；无需额外权限 | MediaRepository 将沙箱文件路径转为 Image 使用的 file URI；ManagedImage 统一加载和失败状态 |
| CoreFileKit DocumentViewPicker | 9（设备 Phone/Tablet 12+、2in1 13+）；无需文件广泛访问权限 | 显式用户选择导出/恢复位置 |
| UI Design Kit Press Shadow / Point Light | 20；UIDesign.HDSComponent.Core；Stage | 公共 PressFeedback 按实际按压状态绑定 pointLight / compositingFilter；取消及释放后复位 |
| ArkUI Navigation systemMaterial | 26；NavigationTitleOptions 新属性 | 当前未调用；统一采用 API 23 HDS 自适应材质 |
| 触觉 vibrator.startVibration / getVibratorInfoSync | 9 / 19；Sensors.MiscDevice；VIBRATE 权限 | 直接复用 Dashboard：关闭/灵动/硬朗、硬件及预置缓存、返回去重 |
| uiEffect.Filter.hdrBrightnessRatio | 24；Graphics.Drawing；HDR_BRIGHTNESS；需 HDR 硬件/管线 | 复制 Dashboard 光场隔离：仅高亮按压尝试；API 23 退回明亮，失败保留普通光场 |
| 智感握姿 motion holdingHandChanged | 20；MultimodalAwareness.Motion；DETECT_GESTURE 权限；设备可能抛 801 | Enhancement：用户显式开启；防抖；仅移动高频动作；注销监听；手动左/右手仍可用 |
| systemShare SharedData/ShareController | 12；Collaboration.SystemShare；Stage | 系统分享项目摘要；业务对象 schema 独立，为未来导入预留 |
| harmonyShare knockShare | 12，重载及数据能力按 SDK 声明；Collaboration.HarmonyShare；近场设备限制 | P2：只在明确用户启动分享时注册，生命周期清理，系统分享 fallback |
| ShareExtensionAbility | 需独立接收入口、MIME、安全校验与导入预览 | P2，不把内部对象直接暴露为公共 Ability |
| 应用接续 | 分布式能力、设备及权限约束 | P2，不在首版要求同步或账户 |
| 系统 BackupExtensionAbility | 工程已有；应用沙箱由系统备份 | 保留，核对 include 配置；手工 RDB 备份标明媒体限制 |

核心目标为 Phone；module 已声明 tablet/2in1。UI/数据 API 能在这些类型上使用，但当前握姿、触觉、近场分享根据 SysCap 和硬件返回判断支持情况，不单凭 deviceType。

## 官方来源

- [关系型数据库持久化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-rdb-store)
- [按压阴影](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ui-design-visual-effect-background-color)
- [轴事件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-events-axis)
- [Navigation API 与 API 26 材质示例](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-basic-components-navigation)
- [Picker API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-picker)
- [Share Kit 变更声明](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/js-apidiff-sharekit-b065)
- [鸿蒙设计与多端规范](https://developer.huawei.com/consumer/cn/design)

准确调用签名进一步对照 DevEco-Studio.app/Contents/sdk/default/{openharmony,hms}/ets/api。页面遇到硬件不可用不能影响核心数据操作。

- [HDS 导航官方示例](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/ui-design-navigation-customized-area)

HDS 导航不是把 Navigation 简单改名：titleBar.content/style、HdsNavigationTitleMode 与 HdsTabsFloatingStyle 均按真实 SDK 声明使用；详情 HdsActionTabs 使用 ToolbarItem 的动作、图片/原生 Symbol 描述；HdsTabs.onContentWillChange 拦截内容切换，onTabBarClick 执行动作。两者本机 SDK since 20、syscap UIDesign.HDSComponent.Core、Stage、无新增权限，兼容 API 23。页面覆盖使用主 NavPathStack 与标准 HdsNavDestination，依据上述 Navigation 官方来源。

安全区：当前不再维护无消费的 WindowInsets 监听。根 HdsNavigation / HdsTabs 与覆盖目的地协调背景扩展和标题避让，内层 titleBar 开启避让，覆盖 HdsNavDestination 由 HDS 自行处理，避免重复下移。详情覆盖主 Tabs，只显示本页的 HdsTabs 操作栏，滚动内容底部留白避让。参见 UI_STYLE.md 的官方依据。

- [Image 加载沙箱图片 URI](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-903)

## 活动提醒与日期选择（2026-10-07）

隔离布局测试新增 ApplicationContext.setFontSizeScale（本机 SDK application/ApplicationContext.d.ts：since 13，SystemCapability.Ability.AbilityRuntime.Core，Stage，仅主线程，无额外权限）。只存在于 ohosTest 源码及构建时临时主模块，不进入正式应用；用 1 / 2 切换验证真实 ArkUI 字体缩放，退出时复位并恢复正式包。参考 [ApplicationContext 官方 API](https://developer.huawei.com/consumer/en/doc/harmonyos-references-V13/js-apis-inner-application-applicationcontext-V13)；官方页面此次抓取未返回正文，签名与限制以本机 SDK 声明核验，并由实际 Text 高度验证生效。系统字体跟随与全页面大字体验收仍单独跟踪。

| 能力 | 本机 SDK 核对 | 应用处理 |
|---|---|---|
| UIContext.showDatePickerDialog / showTimePickerDialog | since 10；ArkUI.Full；Stage；无权限；DatePicker onDateAccept since 10，TimePicker onAccept since 8 | DateField 统一封装；日期/时间表单不要求键盘输入格式 |
| reminderAgentManager.publishReminder / cancelReminder | since 9；Notification.ReminderAgent；发布需 PUBLISH_AGENT_REMINDER | 用户选择提醒才调用；一次日历提醒、无重复响铃；失败不阻止保存 |
| getAllValidReminders / ReminderInfo | since 12；Notification.ReminderAgent | 启动核对本应用有效提醒，取消元数据中已移除的 ID |
| notificationManager.requestEnableNotification(context) | since 10；Notification.Notification；Stage | 只在新建或变更已选提醒时申请授权；未变更提醒复用已有 ID |
| notificationManager.openNotificationSettings(context) | since 13；Notification.NotificationSettings；Stage | 用户点击活动详情「通知设置」才打开，处理首次拒绝后无法再次弹授权的问题 |
| ReminderRequest.wantAgent.parameters | since 12；Notification.ReminderAgent | 通知跳转本机 eventId，找不到已删除活动时保留首页 |

依据：[华为后台任务 FAQ](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-background-tasks-11)、[代理提醒 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-reminderagentmanager)、[代理提醒指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agent-powered-reminder)。日期选择器官方页面本次抓取未返回有效正文，调用签名及 since/syscap 以本机 SDK 的 UIContext/date_picker/time_picker 声明核对。真实授权、后台触发与通知跳转仍需设备交互验收，不由编译及协调器注入测试宣称通过。

## 2026-10-07 · 设备日历与账号诊断

Calendar Kit：getCalendarManager since 10，editEvent since 12，syscap SystemCapability.Applications.CalendarData。editEvent 由系统确认页让用户选择日历账户/提醒，不需要 READ_CALENDAR / WRITE_CALENDAR / WHOLE_CALENDAR；本次不新增日历权限。SDK 明确此接口返回正 ID 表示成功，负值表示取消，0 非法；不允许传入原事件 ID 或 identifier。采用独立系统日程添加，后续由系统日历管理，应用不宣称双向自动同步。全天结束时间取末日之后的本地零点，跨月/年仍包含末日。仅有开始时间时默认一小时，系统确认页可修改。

官方依据：[Calendar Kit 概述](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/calendarmanager-overview-V14)，本机 SDK `@ohos.calendarManager.d.ts`。SDK 核对 since/syscap/无权限；直接 API 文档抓取失败，未以缺失网页宣称系统投递验收通过。

账号接入检查和配置步骤见 [HUAWEI_ACCOUNT_SETUP.md](HUAWEI_ACCOUNT_SETUP.md)。

## 2026-10-07 · 结构重构、原生阅读与统计

官方文档负责用法，本机 Release SDK 26.0.0.105 对照 since/syscap/permission，最低 API 23、目标 API 26：

| 接口 | SDK 标注 | 本轮使用与权限 |
|---|---|---|
| RdbStore.close | since 12；DistributedDataManager.RelationalStore.Core | Promise 关闭连接和结果集，销毁/重开/隔离库清理均等待完成；无新增权限 |
| AppStorageV2.connect | since 12；ArkUI.Full；Stage | common/appState 连接单一 @ObservedV2 实例，检查 undefined；无新增权限 |
| ResourceManager.getRawFileContent（Promise） | since 9；Global.ResourceManager | 读取已打包 privacy.html；无新增权限 |
| util.TextDecoder.decodeToString | since 12；Utils.Lang | UTF-8 解码；无新增权限 |
| Progress（Linear/value/total） | since 7；ArkUI.Full | 分类金额占比横条，宽度 100%、Theme 前景/背景；无新增权限 |
| accessibilityRole / accessibilitySelected | since 18 / 13；ArkUI.Full；Stage | 交互分类、设置档位和记录的角色/选中状态；无新增权限 |

已阅读[华为多设备响应式布局最佳实践整章](https://developer.huawei.com/consumer/cn/doc/doccenter-multi-device/bpta-multi-device-responsive-layout)，包含概述、断点、栅格/布局、窗口变化及相关示例，未仅查看用户指定锚点。落地采用实际内容宽高、伸缩宽度、最大内容宽度、短横屏回到整体滚动、保留字体缩放；窄/手机/宽屏/短横屏画布检查只是组件布局验证，不替代真实平板、折叠及多窗安全区验收。

已阅读[无障碍通用属性整页](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-universal-attributes-accessibility)，补齐中文文本、描述、交互角色与选中状态。保留 Slider 原生无障碍动作，不用父级分组隐藏其操作；图表进度条作为装饰不重复播报，分类容器播报金额与占比。系统读屏人工验收仍列待办。

公共状态采用 Dashboard 的集中访问范式并适配已有 V2 领域对象，参考[华为状态管理 V2 与 MVVM](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/arkts-mvvm-v2-V14)与[AppStorageV2](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-appstoragev2)。设置仍使用 Dashboard 的 V1 Preferences/AppStorage/@StorageLink 通道，桥接组件显式声明 Builder；不混用 V1 装饰器观察 V2 对象。

图表方案对照 Dashboard 的自绘图表、ArkUI 原生 Progress 与[华为 Canvas 说明](https://developer.huawei.com/consumer/cn/doc/doccenter-atomic-service/faqs-canvas-api-problem)。2026-10-07 结构重构阶段只有金额分类比较，选择原生 Linear Progress + 金额/占比文字 + 点击筛选，减少画布尺寸/重绘/命中测试维护；未引入需要 WebView 的图表库或业务依赖。[Progress 官方指南](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-common-components-progress-indicator)已通过浏览器阅读完整正文，核对 value/total/type、宽高自适应和动态更新；SDK progress.d.ts 核对版本与无权限要求。金额按整数分汇总，零总额返回 0，分类按金额排序，计划切换重置分类。该阶段未增加 Canvas 图表；2026-10-08 已按实际需求接入月度趋势与照片状态分布，现状见后节。

本轮新增 base/dark 同值 transparent（#00000000），替代组件中的透明色字面量；更新日志正式版标识另复用 Dashboard 的 v3_accent_orange 浅深色资源。分段背景及其异常回退也通过 Theme 资源，不维护硬编码 RGBA 配色。

## 2026-10-08 · 最终包核对

Release HAP 清单为 API 23→26，仅包含 EntryAbility 与非导出 EntryBackupAbility；权限为 PUBLISH_AGENT_REMINDER、VIBRATE、HDR_BRIGHTNESS、DETECT_GESTURE、INTERNET。没有全相册读取、日历读写或广泛文件权限。debug=false，BuildProfile.DEBUG=false；离线示例与 privacy.html 随包提供，无测试 Ability / TestRunner。

五组主题及 Canvas 月度趋势/照片分布已在当前代码中使用；本节补充现状，不将此前「以后评估 Canvas」的阶段取舍视为仍未实现。新增交付脚本不引入系统 API。目标版本、编译成功和 SysCap 声明不替代 API 23、真实大屏、提醒送达及硬件验收。
