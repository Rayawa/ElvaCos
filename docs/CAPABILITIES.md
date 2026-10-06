# HarmonyOS 能力核验

核验时间 2026-10-05。以华为官方文档 + 本机 Release SDK 的 @since / @syscap / @permission 声明为依据，target 26 并不等于运行设备 API 26。

| 能力 | 起始版本/限制 | API 23 基线策略 |
|---|---|---|
| HdsNavigation / HdsNavDestination / HdsTabs | HdsNavigation 18、HdsNavDestination/HdsTabs 20；UIDesign.HDSComponent.Core；Stage | API 23 直接使用；主路由覆盖式详情，详情 HdsTabs 动作，主页五 Tab 独立导航 |
| TabSegmentButtonV2 $selectedIndex / onItemClicked | 18；ArkUI.Full；Stage；无新增权限；已核对本机 SDK @ohos.arkui.advanced.SegmentButtonV2.d.ets | 分别更新选中状态与处理点击反馈，直接复用 Dashboard 原调用方式 |
| ToolbarItem.symbolIcon / SymbolGlyphModifier | 12；ArkUI.Full；Stage；无额外权限 | Icons 集中提供原生 toolbar 加号/照片 Symbol，避免图片资源图标在详情工具栏缺失；其余语义图标保留原资源 |
| HDS hdsMaterial / systemMaterialEffect | 23；HDSComponent.Core；系统材质策略与设备性能限制 | 复用 Dashboard 的 ADAPTIVE 与持久化等级；不是 ArkUI API 26 的 uiMaterial 调用 |
| RDB relationalStore | 9；ArkData；沙箱无需额外权限 | 直接使用，版本迁移与外键事务 |
| Preferences | 9；ArkData | 设置使用，不保存实体或照片 |
| PhotoAccessHelper.PhotoViewPicker | 10；FileManagement.PhotoAccessHelper.Core | 用户选择无需全图库读取权限；异步复制选中照片，保留来源 URI |
| CoreFileKit fileUri.getUriFromPath | 9；FileManagement.AppFileService；无需额外权限 | MediaRepository 将沙箱文件路径转为 Image 使用的 file URI；ManagedImage 统一加载和失败状态 |
| CoreFileKit DocumentViewPicker | 9（设备 Phone/Tablet 12+、2in1 13+）；无需文件广泛访问权限 | 显式用户选择导出/恢复位置 |
| UI Design Kit Press Shadow / Point Light | 20；UIDesign.HDSComponent.Core；Stage | 通过 canIUse 检查，在统一卡片封装；主卡片少量静态光，不做持续动画 |
| ArkUI Navigation systemMaterial | 26；NavigationTitleOptions 新属性 | 当前未调用；统一采用 API 23 HDS 自适应材质 |
| 触觉 vibrator.startVibration / getVibratorInfoSync | 9 / 19；Sensors.MiscDevice；VIBRATE 权限 | 直接复用 Dashboard：关闭/灵动/硬朗、硬件及预置缓存、返回去重 |
| uiEffect.Filter.hdrBrightnessRatio | 24；Graphics.Drawing；HDR_BRIGHTNESS；需 HDR 硬件/管线 | 复制 Dashboard 光场隔离：仅高亮按压尝试；API 23 退回明亮，失败保留普通光场 |
| 智感握姿 motion holdingHandChanged | 20；MultimodalAwareness.Motion；DETECT_GESTURE 权限；设备可能抛 801 | Enhancement：用户显式开启；防抖；仅移动高频动作；注销监听；手动左/右手仍可用 |
| systemShare SharedData/ShareController | 12；Collaboration.SystemShare；Stage | 系统分享项目摘要；业务对象 schema 独立，为未来导入预留 |
| harmonyShare knockShare | 12，重载及数据能力按 SDK 声明；Collaboration.HarmonyShare；近场设备限制 | P2：只在明确用户启动分享时注册，生命周期清理，系统分享 fallback |
| ShareExtensionAbility | 需独立接收入口、MIME、安全校验与导入预览 | P2，不把内部对象直接暴露为公共 Ability |
| 应用接续 | 分布式能力、设备及权限约束 | P2，不在首版要求同步或账户 |
| 系统 BackupExtensionAbility | 工程已有；应用沙箱由系统备份 | 保留，核对 include 配置；手工 RDB 备份标明媒体限制 |

核心目标为 Phone；module 已声明 tablet/2in1。UI/数据 API 能在这些类型上使用，但握姿、触觉、近场分享必须依据 SysCap 和硬件实际返回，不仅判断 deviceType。

## 官方来源

- [关系型数据库持久化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-rdb-store)
- [按压阴影](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ui-design-visual-effect-background-color)
- [Navigation API 与 API 26 材质示例](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-basic-components-navigation)
- [Picker API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-picker)
- [Share Kit 变更声明](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/js-apidiff-sharekit-b065)
- [鸿蒙设计与多端规范](https://developer.huawei.com/consumer/cn/design)

准确调用签名进一步对照 DevEco-Studio.app/Contents/sdk/default/{openharmony,hms}/ets/api。页面遇到硬件不可用不能影响核心数据操作。

- [HDS 导航官方示例](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/ui-design-navigation-customized-area)

HDS 导航不是把 Navigation 简单改名：titleBar.content/style、HdsNavigationTitleMode 与 HdsTabsFloatingStyle 均按真实 SDK 声明使用；详情 HdsActionTabs 使用 ToolbarItem 的动作、图片/原生 Symbol 描述；HdsTabs.onContentWillChange 拦截内容切换，onTabBarClick 执行动作。两者本机 SDK since 20、syscap UIDesign.HDSComponent.Core、Stage、无新增权限，兼容 API 23。页面覆盖使用主 NavPathStack 与标准 HdsNavDestination，依据上述 Navigation 官方来源。

安全区：Window.setWindowLayoutFullScreen / getWindowAvoidArea / avoidAreaChange（since 9，SystemCapability.WindowManager.WindowManager.Core，无权限）读取状态栏、挖孔和手势区；窗口保留原生避让，根 Tabs 扩展背景，HDS 标题 avoidLayoutSafeArea（since 20）负责标题避让。详情覆盖主 Tabs，只显示本页的 HdsTabs 操作栏，滚动内容底部留白避让。参见 UI_STYLE.md 的官方依据。

- [Image 加载沙箱图片 URI](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-903)
