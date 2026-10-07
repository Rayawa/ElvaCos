# 首版验证记录

## 2026-10-08 · 1.0.0-beta.1 最终打包检查

Release 清理构建 HAP / APP 成功（42/42 任务实际执行），包清单、rawfile 与源码一致，debug=false；交付副本、大小和 SHA-256 见 [打包记录](RELEASE.md)。本次无 schema / 备份格式升级，未清空 personal.db。

| 本次检查 | 结果 |
| --- | --- |
| SQLite 关系/迁移/约束 | 12/12 通过 |
| 主题资源 | 3/3 通过 |
| 当前源码原生 Hypium | Pass 55 / Failure 0 / Error 0 / Ignore 0 |
| Release HAP / APP 包结构和资源 | 通过 |
| SDK 验签、Profile CMS / 有效期 | 通过；实际 Profile 为 debug |
| Release 安装 | 成功，保留用户数据 |
| 修正前 Release UI | Pass 1 / Failure 0 / Error 10 / Ignore 0，未通过 |
| 滚动定位修正后的 UI | 测试 HAP 构建成功；设备断开，复测未完成 |

首轮 UI 首个错误为设置首屏未找到用户名；当前设置已先显示品牌、账号与数据备份，旧用例仍假定用户名在首屏。已改为 settings-scroll 的 scrollSearch，并以 scrollToBottom 检查版本；保留原可见性、布局和业务断言。后续错误受停留设置页影响，修正编译成功不等于整套页面通过。失败原文保留，未删除或改写成成功。

证据：[原生 55 项](validation/beta1-native-api26-report.txt)、[修正前页面报告](validation/beta1-release-ui-before-scroll-fix-api26-report.txt)、[包核对](validation/beta1-package-check-report.txt)、[签名摘要](validation/beta1-signature-report.txt)、[构建收尾](validation/beta1-final-build-report.txt)。原生回归使用 debug 主包与隔离数据；页面检查覆盖安装本次 Release 主包。此前示例/主题/布局专项没有全部重复运行，不能把旧报告合并为本次全部通过。

**签名证据更正：** 2026-10-07 account-signature-api26-report.txt 与旧说明标为「Actual leaf certificate」的 DF:21:…:3A:37 实际是 Huawei CBG Root CA G2 根证书。2026-10-08 从最终 Profile development-certificate 核验应用证书为 3F:0E:…:EC:7B；当前 HUAWEI_ACCOUNT_SETUP 已更正，旧报告保留此纠正说明。签名包有效不证明 AGC 登录或市场发行就绪。

本次界面复测未完全通过，加上开发 Profile、政策差异、图片授权与既有设备/账号边界，不能宣称发布已全绿；下一步具体复测命令和发行条件见 RELEASE。

版本基线：**1.0.0-beta.1（10000001）**；文档核对：2026-10-08。现状与历史证据；最终构建、签名与交付结论见 [打包记录](RELEASE.md)。

## 2026-10-08 主题提亮与图标粉色

- 蓝色资源与原生控件默认风格保留；粉色参考 app icon 的樱花粉，绿色改为薄荷绿，橙色与红色分别调整为杏橙、珊瑚红。图形填充采用 brand，强调文字采用 accent，按钮前景针对填充保持至少 4.5:1 对比度。
- 主包、测试包构建通过；配对资源 / 蓝色锚点 / 对比度与明度层次检查 3/3。API 26 隔离真机切换 3/3、强制结束进程后恢复 1/1，Failure / Error 均为 0，覆盖十种组合、跟随系统独立选择及 320vp 两倍字号。
- [最新真机参考图](validation/theme-palettes-api26.png)与[40 个渲染色值核对](validation/theme-rendered-colors-api26.txt)已更新；[切换报告](validation/theme-switch-api26-report.txt)和[恢复报告](validation/theme-restore-api26-report.txt)为本轮复测证据。截图允许 RGB 单通道 ±1。
- 测试使用唯一 Preferences，不打开 personal.db；结束后正式主包与测试包均恢复成功。

## 2026-10-07 五组成对主题

- 保留蓝色原资源，新增绿 / 粉 / 橙 / 红的 base / dark 资源；主题配色与深浅色独立保存。
- 主包与 ohosTest 构建成功；`test_theme_colors.py` 3 项通过，覆盖配对资源、蓝色锚点、明度层次和文字对比度。
- API 26 隔离真机主题测试：`Tests run: 3, Failure: 0, Error: 0, Pass: 3, Ignore: 0`。验证缺少 themeColor 的旧偏好保留蓝色与浅色、十种即时切换组合、跟随系统选择独立、320vp 两倍字号五个色块不越界。
- 强制停止进程后启动独立恢复入口：`Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0`，恢复红色与深色选择。
- 当时核对 30 个真机背景 / 卡片 / 强调色锚点，与资源一致（RGB 单通道 ±1）；同名参考图与报告已由 2026-10-08 调色后的复测证据更新。
- 测试仅使用唯一 Preferences 及生产偏好控件宿主，不打开 personal.db；结束后主包与测试包均恢复成功。系统设置本身未改动，未验证 API 23 设备或整页导航的所有叠层。


这里按时间保存当时的验证证据与失败原因，旧结果不代表当前代码全部通过，也不要求后续任务重复这些检查。测试范围由当前改动和风险决定，以用户当次要求为准。

当前核对：2026-10-08。下文按各节日期保留当时范围与 P0/P1/P2 语境，不覆盖最新打包结论。

## 2026-10-07 设置滑块保存与外观顺序

- 对照 Dashboard 的 `SettingsPanel`：本工程额外的保存后 `reloadSettings` / 外观与操作模式 `updateSettings` 曾经过 `AppState.perform`，触发全局 loading 并禁用控件；设置加载还会重复水合 AppStorage、调用 `setColorMode`。现在偏好操作使用独立串行队列，加载状态只在固定高度的设置状态行展示，失败继续走全局 Toast。
- 外观顺序为天蓝 0 / 跟随系统 1 / 雾蓝 2；仍保存 sky / system / mist 字符串，不改偏好迁移。不同设置项按字段合并，避免整份旧快照覆盖其他已保存选择。
- 外观与操作模式滑块在拖动 / 待保存期间忽略旧输入，标签即时反映本地选择；失败复位，成功等待父组件更新，不在下一帧前回写旧档位。刷新设置不再重新水合 AppStorage；相同外观不重复设置 ColorMode。
- 最终 `scripts/build.sh`：BUILD SUCCESSFUL。隔离 `settings-layout-test.sh`：`Tests run: 5, Failure: 0, Error: 0, Pass: 5, Ignore: 0`；新增天蓝、跟随系统、雾蓝从左到右的边界断言，窄屏 / 手机 / 宽屏及两倍应用字号既有检查通过。完成后正式包与测试包恢复成功，未清理 personal.db。
- 额外模拟检查直接转译正式 AppState / SettingsService ArkTS，替换平台服务：连续提交串行执行及最终值、跨字段合并且 busy 不变、保存失败后队列继续 / 错误提示、刷新不水合 / 仅改动字段写入 / 相同外观不重设，共 4/4。该检查不访问真机数据，也不代表真实触摸拖动验收。报告：`docs/validation/settings-slider-api26-report.txt`。
- `SliderChangeMode.Begin / Moving` 已核对[华为 Slider 文档](https://developer.huawei.com/consumer/en/doc/harmonyos-references-V14/ts-basic-components-slider-V14)及本机 SDK `ets/component/slider.d.ts`：since 7、SystemCapability.ArkUI.ArkUI.Full，无新增权限，满足最低 API 23。API 23、真实多窗和连续触摸体验仍待验收。

## 2026-10-07 设置两倍字号与复测脚本修复

外观 / 操作模式滑块标签由最多一行改为最多两行，保留 Dashboard 的 12fp、40 / 64vp 标签宽度、190vp 控件宽度。默认字号卡片密度继续与原版材质行一致；两倍字号时完整显示「天蓝 / 雾蓝 / 跟随系统」及操作模式档位，没有锁定字号。

- 正式包和 ohosTest 构建通过；API 26 组件布局 **5/5，Failure 0、Error 0、Ignore 0**：[最终组件报告](validation/font-components-api26-report.txt)。保留既有四项布局、滚轮和路由测试，第五项分别执行 378 / 320vp 的两倍应用字号：探针高度增加超过 1.7 倍，完整四字标签形成两行，整张卡片处于视口内、文字在卡片内，行高与原版材质行相差不超过 2px；复位后探针四边与初始值一致。
- 同一正式 UI 版本的固定区域回归 **4/4，Failure 0、Error 0、Ignore 0**：[固定区域报告](validation/font-fixed-areas-api26-report.txt)。验证标题、分段、底栏、照片末项、重复 Toast 与计划详情返回；后续只调整测试的滚动测量方式，没有再改正式 UI。全九项正式 UI 流程本轮未重复，最近通过记录仍为上一轮。
- 测试只在临时主模块中使用 ApplicationContext.setFontSizeScale(1 / 2)，不改变系统字号、不加载业务服务、不打开 personal.db 或操作偏好。结束后正式包与测试包恢复安装成功；正式 HAP 清单仍只有 EntryAbility。

早期字号用例仅检查文字边界，报告 5/5 却漏掉标签裁切；截图发现只有「天 / 雾 / 跟随」，因此增加两行高度断言并修复。该报告与[修复前截图](validation/settings-font-before-wrap-api26.png)保留为 `font-before-label-wrap-api26-report.txt`，不能作为完整标签通过证据。手机中间版本 5/5 保存为 `font-phone-intermediate-api26-report.txt`。随后加入窄屏时为 4/5、Failure 1：scrollSearch 只让标题可见，TestKit 测到视口裁切后的标签高度；改为整张卡片滚入视口再测，保留原断言，最终 5/5。失败报告保留为 `font-before-viewport-fix-api26-report.txt`。

最终截图已检查：[378vp 两倍字号](validation/settings-phone-large-font-api26.png)、[320vp 两倍字号](validation/settings-narrow-large-font-api26.png)。测试脚本恢复为共享设备锁、临时主模块构建、明确检查安装成功、退出恢复两个包与精确 Hypium 字段校验；早期仅装测试 feature 的脚本不能启动当前测试 host，已纠正。截图 / 布局文件在生成前仅删除同名测试产物，避免 TestKit 覆盖短文件时残留尾部字节。

证据保存后已移除四个临时工程，以及本轮明确生成的六个设备字号截图 / 布局缓存。尝试重新打开恢复的正式应用时设备已锁屏，aa start 返回 10106102，未自动启动；没有更改开发者模式或绕过锁屏。安装恢复成功与测试通过不受这一启动限制影响。

这些结果针对应用内字号 API 和组件画布；系统字体跟随配置、HdsNavigation / HdsTabs / 分段的大字体、全页面字体缩放及真实多窗 / 大屏安全区仍待验收。AppScope 当前未显式声明 followSystem，不能以本轮结果宣称已经支持系统字号变化。

## 2026-10-07 待办 / 最近照片统一反馈与轴事件

首页准备、打包、选片入口改用 TaskLinkCard，最近照片改用 InteractiveCard，统一按压阴影、点光源、HDR 隔离、0.985 缩放、弹簧与点击触觉。页面只发出原路由动作，没有新增业务写入或另一套反馈。圆圈与尾部箭头在 Icons 注册；圈形系统符号已核对 SDK 资源索引并通过正式编译与截图确认。

`common/scroll.ets` 与 Dashboard 原文件逐字节一致（cmp 通过），五个主页和设置的根容器均已接入。API 17 起的轴事件与 BaseEvent 的 API 12 修饰键查询已核对本机 SDK，均属 ArkUI.Full，满足 API 23 基线，无新增权限；官方来源见 CAPABILITIES。

- 正式包与 ohosTest 包构建成功；初次新增测试因坐标对象没有显式 Point 类型而未开始，补齐类型后通过，未安装该失败构建。
- API 26 组件布局 **4/4，Failure 0、Error 0、Ignore 0**：[最终组件报告](validation/task-axis-components-api26-report.txt)。既有设置密度、宽屏滚动隔离、首页宽窄切换和 96vp 尾部留白均通过；新增用例注入鼠标滚轮，指针位于左侧概览时右侧准备任务向上移动、左侧四边不变，Ctrl+滚轮后任务四边不变。依次点击准备 / 打包 / 选片卡片获得同一计划 ID 的对应路由，再点最近照片获得准确照片 ID。
- 正式应用触摸固定区域 **4/4，Failure 0、Error 0、Ignore 0**：[固定区域报告](validation/task-axis-fixed-api26-report.txt)。五个主页 / 设置轴事件和三类待办卡片已包含在此版；最近照片随后接入统一封装，由最终组件用例验证，其后未改变导航源码。最近正式应用完整 UI 回归为上一轮 9/9，本轮未重复全部九项。
- 测试数据只在内存，未启动业务服务或打开 personal.db；正式应用回归只读现有记录。最终测试结束，正式包与测试包恢复安装均成功；正式 HAP 清单检查仅有 EntryAbility。

截图已检查：[待办卡片](validation/task-axis-home-wide-start-api26.png)、[末尾照片](validation/task-axis-home-wide-bottom-api26.png)、[滚轮转发](validation/task-axis-home-wheel-api26.png)。照片为空路径的测试占位，不使用用户原片。最近照片接入前的中间组件报告保留为 `validation/task-axis-before-photo-api26-report.txt`。

以上鼠标测试为当前手机中注入事件、宽屏画布缩放，不等于真实触控板 / 2in1 / 平板系统安全区体验验收。API 23 真机、系统大字体、物理触觉与 HDR / 光场体验继续待验收，不能据此宣称全设备 1:1 已完成。

## 2026-10-07 首页分栏与滚动留白

首页复用 Dashboard HomePage 的 840vp 断点与固定概览 / 独立滚动分栏；首页和设置共用 DashboardSplitLayout，4:6 权重、16vp 间距、1440vp 上限。问候恢复原版 26vp Bold + 14vp 资源文案。Cos、活动、衣柜装备、时间轴、角色 / 装备 / 照片详情的底部 padding 改为滚动内容内的 Blank；照片惰性列表首尾也使用 Blank，首部距离保持原值。未修改 RDB、Preferences 或业务数据流程。

正式包及 ohosTest 包构建成功。API 26 同台手机上的组件布局 **3/3，Failure 0、Error 0、Ignore 0**，报告：[首页与设置布局](validation/home-settings-layout-api26-report.txt)。两项既有设置测试继续通过；新增首页测试检查 378→920→378vp 画布切换、当前计划完整位于固定概览中、右侧滚动后概览 / 花费入口 / 计划四边不变，以及照片末项距视口底部至少 96vp。所有测试记录只在内存，不启动业务服务、不打开 personal.db。

首次截图发现远期活动倒计时数字折行，已使用 16–32fp 自适应字号与 maxLines(1) 修复，并增加单行高度断言。修复前组件报告仍为 3/3，但当时未覆盖该数字断言，保留为 `validation/home-settings-before-countdown-api26-report.txt`；最终 3/3 报告包含新增断言，截图确认数字单行。测试结束正式包与测试包恢复均成功。

留白修改后的正式应用只读固定区域回归 **4/4，Failure 0、Error 0、Ignore 0**，报告：[固定区域](validation/home-tail-layout-api26-report.txt)，覆盖八个二级视图、照片末项、重复 Toast 与任务详情返回。该报告在倒计时修复前执行，验证的是同一版导航与留白；最终倒计时另由组件测试验证。

最终正式包 UI 回归 **9/9，Failure 0、Error 0、Ignore 0**，报告：[正式应用 UI](validation/home-tail-ui-api26-report.txt)。覆盖五 Tab、设置覆盖路由与帮助 Sheet、角色和计划新建取消、任务视图与详情返回、活动列表 / 日历、照片导入选择取消，以及首页花费入口与记账弹层取消。此轮重新构建并安装最终正式包，保留业务记录；没有改变业务数据或偏好。

组件截图：[宽屏起始](validation/home-wide-start-api26.png)、[右侧到底](validation/home-wide-bottom-api26.png)、[恢复手机](validation/home-phone-restored-api26.png)。均已检查，画布使用内存测试记录且在手机中缩放，不能作为真实平板 / 多窗安全区、系统大字体或全设备 1:1 风格验收。覆盖式详情大屏双栏仍未实现。

## 2026-10-07 审批恢复后的真机复测

用户确认额度问题已解决后，在同一台 BRA-AL00 / API 26 手机重新执行 `scripts/settings-layout-test.sh` 和 `scripts/layout-test.sh`；审批正常通过，正式包及 ohosTest 包均构建、签名、安装成功。

| 检查 | 本次结果 | 报告 |
|---|---|---|
| 设置组件布局 | Tests run 2、Pass 2、Failure 0、Error 0、Ignore 0 | [设置报告](validation/approval-retry-settings-api26-report.txt) |
| 正式应用固定区域回归 | Tests run 4、Pass 4、Failure 0、Error 0、Ignore 0 | [布局报告](validation/approval-retry-layout-api26-report.txt) |

设置复测覆盖 320 / 378 / 920vp 组件画布：卡片密度与复用的 Dashboard 材质行一致、末项完整可见，宽屏右侧滚动时左侧应用信息与图标位置不变。测试结束后正式包与测试包恢复安装均成功，正式清单没有 SettingsLayoutAbility。固定区域复测覆盖八个二级视图的标题 / 分段 / 底栏、照片末项避让与重复点击回顶、重复校验 Toast，以及计划三任务视图和照片详情返回位置。

已核对本次 02:19–02:22 生成的设置、照片末项、重复 Toast 和照片详情返回截图；照片与计划相关测试实际执行，未因没有记录跳过。测试未新增、删除、清空业务记录或修改偏好。组件画布仍为手机上的缩放布局，API 23 真机、真实平板 / 多窗安全区、大字体及完整 Dashboard 风格验收继续待验证。

## 2026-10-07 设置细节与宽屏组件验证

设置分组标题改为 Dashboard 的 14vp Bold；偏好分割线使用 border，动作组使用 v3_chart_grid。深浅色各 14 项同名资源逐项一致。840vp 以上采用左侧固定应用信息、右侧独立滚动功能列表，权重 4:6、最大宽度 1440vp。

独立布局测试使用临时工程副本，在主模块注册不导出的 SettingsLayoutAbility，渲染真实 SettingsPage。只创建内存 AppState，不启动业务服务，不打开 personal.db，不操作偏好或破坏性入口；结束时恢复正式包与测试包。正式工程清单不包含测试 Ability。320 / 378 / 920vp 画布在当前手机内缩放展示，不能替代真实平板、多窗或系统安全区验收。

早期测试 feature 的渲染资源异常，初次报告保存为 `validation/settings-layout-initial-api26-report.txt`（Pass 0、Error 2）。改用临时主模块后，人工截图确认真实配色、应用与列表图标正常；测试工具不暴露 HDS 自定义组件的 id，后续按文字及包含它的原生 HdsListItem 定位完整卡片。最终复测 **2 / 2 通过，Failure 0、Error 0、Pass 2、Ignore 0**，报告为 `validation/settings-layout-api26-report.txt`。第一项逐一执行 378 / 320vp：偏好卡片与复制的 Dashboard 材质行高度一致，符合 68 / 116vp 的相应密度（原生 HDS 边界包含内部留白）；最后一张隐私协议卡片完整位于滚动视口内。第二项执行 920vp：左右布局分离，右侧滚动后左侧信息容器与应用图标四边完全不变，最后一张卡片完整可见。已人工检查三种尺寸的截图，正式包及测试包均恢复成功。

随后在正式应用上执行只读固定区域回归，**4 / 4 通过，Failure 0、Error 0、Pass 4**，报告为 `validation/settings-followup-layout-api26-report.txt`：当前八个二级视图的标题 / 分段 / 浮动底栏滚动前后位置不变；照片末项避让与重复点击回顶、相同错误再次 Toast、准备 / 打包 / 照片动作栏及详情返回位置通过。测试未新增、删除或清空业务记录。

组件画布证据：[320vp](validation/settings-narrow-api26.png)、[920vp](validation/settings-wide-api26.png)。这些截图包含测试页的宽度按钮与缩放画布，不代表真实平板导航或系统安全区已验收。

## 已通过

| 检查 | 结果 | 证据与范围 |
|---|---|---|
| 正式 HAP 编译与签名 | 通过 | `scripts/build.sh`，Release SDK 26.0.0.105；compatible API 23，target 26 |
| ohosTest HAP 编译与签名 | 通过 | `scripts/build.sh assembleHap ohosTest`；ArkTS 类型检查 |
| SQL 关系测试 | 9 / 9 | `python3 scripts/test_schema.py`；执行实际 Schema.ets 提取的 SQL，SQLite 内存库 |
| 真机 Hypium | 47 / 47 | API 26 设备；Failure 0、Error 0、Pass 47；最近领域报告 ux-revolution-native-api26-report.txt，含增量迁移、准备 / 活动 / 花费 / 参考图与备份验证；本轮只改布局，未重复运行领域测试 |
| 真机安装与启动 | 通过 | 最新签名正式包安装，EntryAbility 启动成功 |
| 初次 HDS UI 真机测试 | 3 / 3 | 覆盖式详情与加宽底栏调整前；API 26 手机；五 Tab、二级分段、标题菜单、照片加载、固定区域、独立设置、末项避让、Toast、取消表单；Tests run: 3, Failure: 0, Error: 0, Pass: 3, Ignore: 0 |
| 最近正式应用完整 UI 回归 | 9 / 9 | 上一轮 API 26 手机；Failure 0、Error 0、Pass 9；home-tail-ui-api26-report.txt，覆盖首页、覆盖路由、设置及表单取消；本轮新增行为另见组件与固定区域报告 |
| 当前只读布局回归 | 4 / 4 | API 26 手机；Failure 0、Error 0、Pass 4；font-fixed-areas-api26-report.txt，覆盖八个二级视图（含活动列表 / 日历）、照片末项、重复 Toast 与计划详情返回位置 |
| 首页与设置组件布局 | 5 / 5 | API 26 手机缩放画布；Failure 0、Error 0、Pass 5；font-components-api26-report.txt，含 320 / 378 / 920vp、左右滚动隔离、首页宽窄切换、滚轮 / Ctrl、任务 / 照片路由与两倍应用字号 |
| 类型与权限检查 | 通过 | 业务代码未使用 any/unknown；无全图库、网络、联系人、定位权限；关系型 SQL 全部位于 data 层 |

原生测试使用 `verification-UUID.db` 加密数据库，模块 Context，不启动测试前台页面。测试结束删除数据库和自己生成的图片，不修改 personal.db 或系统图库。`aa test` 即使失败也可能返回退出码 0，因此脚本检查 Hypium 的 Failure / Error / Pass。

## 初轮 17 项真机测试（当前 23 项增量见下文）

领域规则 6 项：整数分金额、无效金额拒绝、真实日期/闰年、资产就绪状态、空/完成清单进度、名称清理与空名称拒绝。

真实 RDB / 文件 / ImageKit / Preferences 11 项：

1. v1 迁移与角色/版本/项目/资产 CRUD。
2. 资产关联及自动清单幂等。
3. 外键保护正在使用的角色。
4. 加密数据库关闭再打开仍保留数据。
5. 元数据导出恢复及未来备份版本拒绝。
6. 无效备份外键导致整次替换回滚。
7. ImageKit 生成测试 JPEG，经 MediaRepository 复制独立原文件和缩略图，缩略图不超过 480，元数据恢复复用本机可信照片路径。
8. 删除项目级联清理关联和清单，保留可复用资产。
9. 隔离 Preferences 旧设置迁移，关闭振动映射为 0，保留目标值，关闭重开后仍持久化。
10. 隔离缓存目录递归清理，保留 filesDir 原文件，拒绝包含上级跳转的路径。
11. Preferences v2 转换保留关闭视效意图、用户名与已转换值；自动/手动握持选择统一，并验证关闭重开后的持久化。

## 验证中发现并修复

- `createTransaction()` 的独立连接未继承外键 PRAGMA：改用同一 RdbStore 写连接事务，恢复回滚和级联删除已在真机通过。
- 媒体目录已存在时 `mkdir` 返回 File exists：创建前异步 access，重复测试已通过。
- HDS 根导航多余返回按钮与内容区重复主动作：根导航 hideBackButton；一级动作使用 HDS 标题菜单，详情继续使用原生 toolbar。
- 测试用 application Context 无法直接打开 RDB：使用真实模块 Context，避免要求启动前台测试 Ability。

## 2026-10-06 Dashboard 初次对齐（后续 UX 调整前）

本轮在同一 API 26 手机分别启动 Dashboard 和 ElvaCos，对照真实截图及 `uitest dumpLayout`。根 HdsTabs 保持固定，各 Tab 独立 HdsNavigation；标题显式 avoidLayoutSafeArea=true，修复标题进入状态栏的问题。二级原生分段位于 titleBar.stackBuilder。详情 toolbar 与底栏分开；通知与错误使用 showToast。设置从“我的”标题按钮进入独立目的页。

参考几何（1216×2688px；设备当前字号/窗口）：

| 区域 | Dashboard | ElvaCos |
|---|---|---|
| HdsTitleBar | [0,107]–[1216,289] | 相同 |
| titleBar 分段内部 Tabs | [304,134]–[912,264] | 相同 |
| 首页问候文字 | [58,371]–[828,470] | 相同 |
| 浮动 Tab 项纵向范围 | 2428–2584 | 相同 |
| 项目详情 toolbar | 参考根页无此业务 toolbar | [0,2220]–[1216,2376]，距浮动 Tab 项 52px |

完整边界记录见 `validation/hds-geometry-api26.json`。五个业务 Tab 与参考四个 Tab 的单项宽度不同，底栏整体均为 250vp / 28vp。

顶部留白采用参考 Blank(100vp) 与容器间距：首页/设置/详情 14vp，搜索列表 12vp。新 DashboardSearch 复用 AppsPage 的 48vp 高度、背景、边框和弹簧按压；内联筛选保留键盘输入。漫展分段显示“即将 / 过去 / 想去”，完整无障碍文案保留，避免固定 50% 区域内出现省略。

设置第一组直接复用 SettingsPanel：用户名 → 振动 → 材质 → 缓存；常规行 68vp，缓存行 52vp，未被全屏容器拉伸。按参考使用 app_storage / DiskStorage，偏好在 UI 前加载；旧设置显式迁移并保留既有目标值。vibration、motion、safeUi 与参考文件逐字相同；深浅色各 13 项同名资源全部相同。

照片此前文件存在而画面空白，原因是 Image 使用裸文件路径。本轮统一通过 MediaRepository.imageUri 和 ManagedImage 加载，报告加载/失败状态；真机照片列表断言“照片已加载”，人工截图确认首页和资料库照片可见。未删除或重导入现有照片。详情 toolbar 的“新项目 / 添加版本 / 设为封面”改用 Icons 中集中提供的原生 Symbol，修复图片图标缺失；替换已有角色封面增加确认，比较实际保存的缩略图路径。

最新正式和测试 HAP 编译成功，已安装。UI 测试覆盖五 Tab、漫展三个过滤分段、Cos/资料库/我的二级分段、标题菜单、滚动后固定区域不动、独立设置与系统返回、设置末项可滚到浮动栏上方、Toast 不改变表单位置、取消表单不写数据。截图人工检查首页、角色、项目列表、漫展、衣柜、照片、作品/时间轴、设置顶部/底部、表单；另查看真实项目、角色及照片详情。新增只读详情分支：存在角色/照片时进入详情，断言 toolbar 内至少 2 / 1 个可见 Symbol、toolbar 高于固定底栏、照片原图已加载，然后返回；本设备已有数据，两个分支已执行通过，截图确认原生加号与封面 Symbol 可见。

UI 测试采用窗口内选择器，每项及文字操作开始聚焦应用；内容滚动手势从中部发起，避免误触浮动底栏。测试脚本安装后停止旧应用进程，确保验证本次包；当时通过 Failure / Error / Pass 判断结果，aa test 退出码不能单独证明通过。最新报告保存于 `validation/ui-api26-report.txt`（3 / 3）和 `validation/native-api26-report.txt`（17 / 17），两者 Failure / Error 均为 0。

材质与深色通过真实设置界面临时切换并人工检查，标题和底栏位置保持不变。检查后恢复原有“跟随系统 / 原生视效关闭 / 自动单手 / 握姿关闭”，已通过 UI 属性回读确认。材料绘制遵循现有开关及等级；颜色相同不意味着在不同设置下材质画面相同。

备份持久化进一步拆分：MetadataBackupRepository 负责格式验证、媒体路径白名单及 RDB 恢复事务；BackupService 只负责系统文档选择器和文件读写。未修改备份格式、schema 或迁移版本。拆分后正式/测试包编译通过，隔离真机测试 17 / 17（Failure / Error 均为 0）；SQL 关系测试 9 / 9。源码扫描确认 data 之外没有 relationalStore、querySql 或 executeSql。原生测试脚本同时要求实际测试数量与 Pass 大于 0，拒绝空测试报告。

公共 InteractiveCard 的按压缩放由 0.975 调整为参考 HdsMiniBarButton / AppsPage 的 0.985，保留相同 130ms、springMotion(0.35, 0.9) 与复用光场工具；最终正式包编译通过。详情覆盖路由及加宽底栏由后续 UX 调整继续验收，以下初次 250vp 底栏几何为历史参考。

当时核验的项目：

| 用户要求 | 本轮证据 | 范围 |
|---|---|---|
| 五页独立 HdsNavigation，固定 HdsTabs | 五页切换、固定边界、源码独立栈 | API 26 当前手机 |
| titleBar 内固定 Segment Buttons | 参考内部 Tabs 边界相同；滚动后边界不变 | 角色/项目、漫展、衣柜/照片、作品/时间轴 |
| 顶部/底部沉浸与可见内容安全区 | 标题避让与截图；设置末项高于底栏 | 当前手机，其他窗口形态待验收 |
| showToast 用户提示 | 无效保存 Toast 截图，字段与标题边界不变 | 表单错误流程 |
| 独立设置页，顺序与样式 | 原版 SettingsPanel，卡片截图对照；返回保留我的页面 | 常规手机尺寸 |
| Dashboard 设置存储方式 | 隔离迁移、重开持久化与保留目标值测试通过 | 单一 app_storage |
| 详情 toolbar 与固定底栏 | 真实项目工具栏上下边界及截图 | 项目、角色、照片详情；其他详情共用同一导航构造 |
| 反馈、动效和颜色复用 | 源文件逐字/资源逐项对照；材质与深色截图 | 硬件触感及大屏体验仍见下列边界 |

以上证据证明当前手机上的导航、安全区和参考组件对齐，不宣称所有设备、字号、业务状态均达到逐像素 1:1。

## 2026-10-06 覆盖式导航与设置修正（当前）

本次用户要求覆盖此前「详情 toolbar 与主页底栏同时显示」的布局约定。新增主路由 HdsNavigation / NavPathStack，角色、项目、资产、漫展、照片及设置进入覆盖式 HdsNavDestination。主页五 Tab 的状态、分段、搜索和滚动留在主页内部；详情显示时查找不到主页 main-tabs，只有本页 HdsActionTabs，且没有 ToolBar。动作点击不切换详情内容；已从角色详情点击添加版本，确认出现 bindSheet 表单，取消后仍停在角色详情，再返回角色列表。

主页底栏从 250vp 改为 min(360vp, 窗口宽−32vp)。详情底栏按动作数计算宽度，与主页共用 28vp 底距和材质配置，详情滚动底部留白 110vp。API 26 当前手机截图已确认角色详情返回/操作图标、照片和加宽主页栏；设置覆盖后没有主页底栏，末项可以滚到窗口底部安全区之上。

设置的偏好、数据和帮助卡片统一 HdsListItemCard / PrefixIcon，与 Dashboard 的图标列和前后边距一致。外观只显示跟随系统；单手操作使用 190vp 的三档 Slider，左/中/右标签分别为左手、智感握持、右手，普通行高 68vp，窄屏上下布局 116vp。使用说明与数据说明为真实 bindSheet，测试已分别打开阅读并关闭。

材质等级成为视效唯一选择：流畅同步关闭原生材质、光场和 HDR 增强；轻柔/精美开启对应等级。Preferences v2 显式将原 effects=false 转为流畅，保留用户名和手动左右手，自动但未启用感知的旧状态按原左右手偏好转换；既有自动感知保留。外观转换为跟随系统，不触及 RDB。

验证：

- 正式与 ohosTest HAP 编译和签名通过，最新调试包已安装。
- SQL 关系测试 9/9。
- 设备测试 17/17：Failure 0、Error 0、Pass 17；新增用三个独立 verification-* Preferences 验证视效关闭意图、手动/自动转换、幂等与重开持久化，测试完成清理。
- 最新 UI 测试 4/4：Failure 0、Error 0、Pass 4；纵向滚动在标签列发起，避开 Slider，避免测试误触设置。角色详情的添加版本和首页添加角色取消均未写业务数据。
- 早期测试遇到不存在控件返回 null 的测试断言错误，已修正；一次运行报告 App died，日志同期包含重新安装/测试进程切换。重新直接执行已安装测试和最终完整 UI 脚本均通过，不将那次退出解释为已证实的产品崩溃。

真实智感握持权限拒绝、设备不支持与左右手检测仍待体验验收；API 23、大字体、多窗/大屏尚未执行本轮布局验证。上述 4/4 证明当前 API 26 手机路径，不扩大为全设备验证。

## 固定区域与重复 Toast 补充检查

2026-10-06，新增独立只读 FidelityLayout 测试，正式与测试包构建成功并安装，Tests run: 3, Failure: 0, Error: 0, Pass: 3, Ignore: 0。历史报告见 `validation/layout-initial-api26-report.txt`；当前完整 4 项报告为 `validation/layout-api26-report.txt`，复现入口为 `scripts/layout-test.sh`，不要与其他设备界面任务同时运行。

- 逐一进入角色、项目、即将、过去、想去、衣柜、照片、作品、时间轴九个二级视图，比较滚动前后的标题、分段和首页 Tab 项四边坐标；全部不变。各视图分段边界也一致，底栏高于窗口底边。
- 资料库使用设备现有照片作为只读样本，滚到末尾后断言最后照片卡片底边不超过浮动 Tab 项顶边；截图人工确认末项完整可见。重复点击资料库后，首张照片恢复到原坐标。空图库只能验证空状态，不能作为末项避让的证据；本设备的照片分支已执行。
- 打开空白添加角色 Sheet，首次保存后等待原 Toast 消失，再次保存；自动断言字段坐标不变并取消表单。两张截图人工确认均出现系统 Toast“名称需要 1–80 个字”，没有插入错误行，未写业务数据。

提示改为 AppState.reportError / reportNotice 为每次报告递增 feedbackVersion，Index 继续复用 Dashboard 的 showToastSafely；相同字符串也会触发新的提示。分段控件分别转发选中变化与点击回调，匹配 Dashboard 的调用方式；重复点击当前项也走原版点击反馈。移除迷你栏多余的外层裁剪，内部圆角与内容裁剪沿用参考源。

源文件核对：vibration、motion、safeUi 逐字相同；浅/深色各 13 项同名颜色零差异。TabSegmentButtonV2 的 $selectedIndex / onItemClicked 已核对本机 SDK（since 18、ArkUI.Full、Stage、无需新增权限）。本次 3/3 是当前 API 26 手机上的固定区域与反馈证据，未替代大字体、其他设备或真实硬件触感验收。

## 2026-10-06 初轮 UX 优化与设置合并

连续新建计划保留在同一个 bindSheet：选择已有角色或填写新角色，角色与计划在同一事务提交，成功才导航到准备页；版本、漫展、状态和预算通过更多设置展开。计划内新增装备将装备、关联与打包项一起提交；漫展内支持自动带入关联/日期的新计划及既有未关联计划的选择 Sheet。没有改变 schema v1 或解释、清空既有数据。

计划详情使用准备 / 打包 / 照片三个原生标题分段，ProjectRoute 为每个详情保留当前任务视图。准备显示装备可用率、缺项提示和未就绪优先的装备；打包直接显示未装包项、位置和装包按钮；照片支持待选/已选/待修/成片筛选、当前筛选全选与批量状态更新。首页按近期计划提供打包/选片入口，Cos 默认计划并增加状态筛选。分类准备任务与视频中的参考图片、团队、日程扩展仍未实现，见 ROADMAP。

按用户后续要求去掉「操作偏好」标题，将外观与左手/智感握持/右手插入原版 SettingsPanel 同一卡片、位于清除缓存之前。沿用相同图标、68vp 行高与控件列，设置分组减少为设置、数据与备份、帮助。

当前验证：

- 正式包与测试包构建成功，已安装当前 API 26 手机。
- SQL 关系约束 9/9。
- 隔离数据库/Preferences 真机 Hypium 23/23，Failure 0、Error 0、Pass 23。新增测试覆盖首次创建无需预建角色、漫展上下文、最近计划选择、照片状态分组，以及新角色+计划、新装备+关联+打包项的失败回滚和批量照片失效记录全部回滚；验证库完成清理。
- 最终 UI 6/6，Failure 0、Error 0、Pass 6：覆盖五页/二级分段、Sheet 取消与空值校验、同一新建计划内创建角色、准备/打包/照片切换、装备/物品上下文表单、批量选择与取消、照片详情返回保留任务视图，以及合并设置、三档几何和两种帮助 Sheet。测试未写业务记录，照片批量提交通过隔离数据测试验证。
- 合并设置卡片截图已人工确认图标/控件对齐；计划标题分段不叠加第二份文字标题，打包项显示位置且已装包项在后。一次 UI 返回断言失败后未能继续后续用例；返回键前显式聚焦应用窗口，完整复测 6/6 通过，未修改产品返回逻辑。
- 固定布局完整复测 4/4，Failure 0、Error 0、Pass 4：九个二级视图的标题/分段/底栏固定，末张照片能滚到浮动栏上方，重复空值校验不移动表单；准备/打包/照片均保持 50% 标题分段和同一操作栏上下边界。设备现有计划与照片分支已执行：打开可见照片进入独立详情，返回后保留照片任务视图、分段坐标与照片卡片四边位置。返回截图已人工核对，报告见 layout-api26-report.txt；复现 scripts/layout-test.sh。
- 新增测试曾按不存在的重复标题遍历 null，随后又点击列表缓存中被固定栏遮住的照片；已修正空控件处理，并按可见中心坐标选择照片。`-s itName` 在当前运行器没有缩小执行范围，45 秒超时引发后续 UiTest 并发错误；改用 Hypium 支持的 `-s class Suite#case` 后单项复测通过。这些失败保留为测试调试记录，不算产品通过证据。
- 最后消除照片分行和首页待办排序中的重复过滤/排序，正式包重新构建成功并安装。未修改结构、迁移或用户数据。

报告：`validation/ux-native-api26-report.txt`、`validation/ux-ui-api26-report.txt`、`validation/ux-plan-layout-api26-report.txt`；布局用例调试记录为 `validation/ux-layout-before-fix-api26-report.txt`。API 23、大字体、多窗/大屏、真实图库与硬件感知仍按下列边界跟踪。

公共确认弹窗已消除固定十六进制颜色，复用 Dashboard 的 diff_content / v3_accent_red 浅深色资源；取消与确认行为不变。正式和测试包构建成功，完整布局脚本已安装最新签名包。源文件再次核对：vibration、motion、safeUi 逐字相同，浅深色各 13 项同名颜色无差异。

## 验收边界

- API 23 核心兼容性依据本机 SDK since/syscap 声明与官方文档；尚未在 API 23 真机执行。
- API 24 本机平板模拟器因磁盘空间不足未启动，未将大屏模拟器验收标为通过。
- 原生媒体测试使用测试生成图片；真实图库授权/选择、DocumentViewPicker 导出恢复交互、分享面板尚需用户流程验收。
- 系统 BackupExtension 已注册；跨设备恢复加密 RDB 与所有原图尚未验证。便携 JSON 仅含元数据，不包含照片。
- 握姿与触觉实现含能力检查、权限、开关和降级，尚未完成真实硬件体验验收。
- 照片网格按窗口宽度调整列数；大字体、读屏、多窗与折叠仍需设备验收。覆盖式详情当前使用 Stack，大屏/2in1 分栏未实现，不将历史 Split 布局算作当前版本验收。
- SDK 仍报告部分“Function may throw exceptions”静态警告；编译无错误，相关调用由业务操作、资源 finally 或能力降级捕获。

## 复现

```sh
./scripts/build.sh
python3 scripts/test_schema.py
HDC_TARGET_ID=<device-id> ./scripts/device-test.sh
HDC_TARGET_ID=<device-id> ./scripts/ui-test.sh
HDC_TARGET_ID=<device-id> ./scripts/layout-test.sh
```

签名正式包：`entry/build/default/outputs/default/entry-default-signed.hap`。设备测试日志可由命令保存；提交工程时不提交签名配置或本机证书。

## 2026-10-06 全局一致性修正（真机回归）

设备：BRA-AL00，OpenHarmony-7.0.0.105 / API 26，屏幕 1216×2688px（当前字号下 1vp≈3.21px），通过 `hdc` 远程连接。过程证据为 `uitest dumpLayout` 边界 + `snapshot_display` 截图，逐项人工比对。

### 修复前后对比（同一设备、同一数据）

| 检查 | 修复前 | 修复后 |
|---|---|---|
| 计划详情首行内容 | `[45,371]`，落在标题栏 `[0,161]–[1216,450]` 内，标题被分段按钮压住 | 首行落在标题栏下方，`Blank(126vp)` 生效后不再重叠 |
| 角色/装备/漫展/照片详情首行 | `[45,371]`，与标题栏下沿相差约 24px | `Blank(108vp)`，完全让开标题栏 |
| 标题栏滚动效果 | 关闭，滚动时正文与标题文字互相压叠 | 开启渐变模糊，正文滚到标题栏下方时标题可读 |
| Cos/漫展/衣柜/我的 顶部分段宽度 | 固定窗口 50%（实测 605px） | 按标题长度规划，实测 488px（`segmentWidth`），标题、分段、菜单互不接触 |
| 设置页顺序 | 设置 → 数据与备份 → 帮助 | 图标中英文 → 分割线 → 华为账号 → 数据与备份 → 设置 → 帮助 → 版本信息 |
| 应用外观 | 只有「跟随系统」提示 | 天蓝 / 雾蓝 / 跟随系统三档，切换后全应用配色即时生效 |

### 应用外观真机证据

在同一设置页点击「天蓝」后，页面背景、强调色（滑块、分组标题、选中标签）在无重启、无重进页面的情况下立即变为天蓝；点击「雾蓝」后同样立即变灰蓝；返回「我的」页签后新配色保持；杀掉进程重新启动后，外观选择与配色仍为上次选择（Preferences 持久化）。最后已恢复为「跟随系统」，与 ROADMAP 的默认值一致。

### 弹层与返回

`新建 Cos 计划` 表单 Sheet 顶部为标题 + 说明 + 右上角关闭按钮（截图确认，无系统自带关闭按钮）；按系统返回键后 Sheet 关闭、页面仍停在 Cos 列表且表单状态复位（再次打开为空表单）。`使用说明` Sheet 同样带右上角关闭且可滚读。设置页的 `使用说明 / 隐私协议` 两个入口分别打开对应内容。

### 华为账号

真机点击「登录」会真实调用 Account Kit（日志出现 `huaweiId_framewrok_base` 初始化）。当前工程没有 AGC 侧开通与签名指纹配置，系统返回 1001500001，界面按错误码提示且不写入登录态、不崩溃、不产生假数据。云同步行固定显示「暂未开启」，不可点击。

### 自动化验证（本轮全部通过）

| 检查 | 结果 | 报告 |
|---|---|---|
| SQL 关系测试 | 9 / 9 | `python3 scripts/test_schema.py` |
| 真机 Hypium（隔离数据库与 Preferences） | 23 / 23，Failure 0、Error 0 | `scripts/device-test.sh` |
| 真机 UI（HdsShell） | 6 / 6，Failure 0、Error 0 | `docs/validation/consistency-ui-api26-report.txt` |
| 真机固定区域（FidelityLayout） | 4 / 4，Failure 0、Error 0 | `docs/validation/consistency-layout-api26-report.txt` |

测试用例随本轮 UI 变更同步更新：设置页顺序变化后先滚动再断言「材质等级」；分段按钮不再固定 50% 宽，用例改为断言「水平居中 + 不压住左侧标题 + 各页上下边界一致 + 滚动后不动」；帮助 Sheet 的关闭按钮由文字「完成」改为右上角图标，用例通过 `sheet-close` id 点击（`SheetHeader` 已为该按钮提供稳定 id）。

### 2026-10-06 复核修正（二级页避让 / 滑块连续性 / 振动补齐 / 颜色风格）

- **二级页面 HDS 避让**：用 `uitest dumpLayout` 与 Dashboard（同机 `top.rayawa.dashboard`）逐项对照后发现，二级页标题栏被整体下移了正好一个状态栏高度（标题文字 267–343px，一级页与 Dashboard 均为 160–236px）。原因是 HdsNavDestination 已由 HDS 自行避让，`avoidLayoutSafeArea: true` 又叠加了一次。改为：内层 HdsNavigation 传 `true`、HdsNavDestination 传 `false`。修正后二级页标题回到 160–236px，计划详情分段落在 [304,134]–[912,264]，与 Dashboard 根页完全一致；`detailTop` 从 108/126vp 回到 100/112vp。
- **分段宽度**：改为每项 88vp + 14vp、上限窗口一半，结果与 Dashboard 的固定 50% 一致（本机实测同为 608px），仅在标题较长时收缩。Dashboard 的 `enableScrollEffect` 为关闭，本应用同步关闭。
- **滑块连续性**：应用外观/操作模式改用 `$$` 双向绑定 + 松手提交；材质等级滑块用镜像 `@State` 做到同样效果（Dashboard 该滑块是单向绑定，拖动时拇指不跟随）。真机横向拖动应用外观滑块，值由 2 变为 0 并即时切换配色。
- **振动补齐**：详情操作栏（`HdsActionTabs`）、迷你栏（`HdsMiniBarButton`）、确认弹窗（`Confirm`）原来没有反馈，已补齐；返回新增 `backIcon.action` + `onBackPressed` 出栈路径。真机 `hilog` 确认 `PlayPrimitiveEffect ... package:top.rayawa.elvacos, effect:haptic.effect.hard` 在点击与返回时都有触发。`common/vibration.ets` 增加时长振动回落，避免设备不支持 `haptic.effect.*` 时静默。
- **应用外观语义修正**：用户明确三档就是浅色 / 深色 / 跟随系统，不是两套强调色。实现改为 `setColorMode(COLOR_MODE_LIGHT / COLOR_MODE_DARK / COLOR_MODE_NOT_SET)`，并按此语义更新帮助文案；`EntryAbility` 不再在启动后强制 `COLOR_MODE_NOT_SET`，避免覆盖用户选择。
- **颜色资源**：`resources/base|dark/element/color.json` 与 Dashboard 同名 token 值逐项零差异（此前为外观新增的 12 项底色/表面/边框 token 已全部删除，`sky_accent` / `mist_accent` 也已删除），现在没有任何第二套配色；只有 Dashboard 未定义的 `on_accent` 是本工程既有项。
- **真机外观证据**：设置「雾蓝」后全应用立即切到 Dashboard 的深色资源（底色 #1A2B3C、表面 #182231、强调色 #4A9CE2、浅色文字），杀进程重启后仍为深色；切回「跟随系统」后恢复与系统一致的浅色。
- 复核后重跑：SQL 9/9、真机 Hypium 23/23、UI 6/6、固定区域 4/4，Failure/Error 全 0。检查结束后已把真机偏好恢复为「跟随系统 / 灵动 / 轻柔 / 左手」。

### 2026-10-07 设置页图标统一为 app.media

- 设置页 `HdsListItemCard` 的图标此前混用了 `sys.media`（share / albums / remove / person_badge_waveform）与 `app.media`，观感与 Dashboard 不一致。现已全部改为 `app.media` 的浅/深两版 PNG：`user`（用户名、操作模式、华为账号）、`vibrate`、`immersive`、`light`、`trash`（清除缓存、清空本地数据）、`tutorial`（使用说明）、`privacy`（隐私协议）、`cloud`（云同步）、`export`（导出元数据 JSON）、`load`（从元数据备份恢复），行尾箭头改用以 Dashboard MoreRow 同款 `right`。
- 新增/复制的资源：`cloud.png` / `export.png` / `load.png` 由用户提供（浅深各一版）；`tutorial.png` / `privacy.png` / `right.png` 从 Dashboard 的 `AppScope/resources/base|dark/media` 复制。删除了本次自建的 `cloud.svg`，避免与新增的 `cloud.png` 资源重名。
- 真机浅色/深色各截图一次：深色下全部图标为白色描边，浅色下为黑色描边，深浅色成对生效；`跟随系统` 在系统夜间模式切换后也正确跟随。
- 复核后重跑：真机 UI 6/6、固定区域 4/4（Failure/Error 全 0）；偏好恢复为「跟随系统 / 灵动 / 轻柔 / 左手」。

### 本轮验证边界

- 以上为 API 26 单台手机、当前系统字号下的证据；API 23、大字体、多窗、折叠与平板分栏仍需设备验收。
- 深色模式下天蓝/雾蓝的 `dark` 色值已写入资源并通过编译，但未在深色模式下逐档截图比对。
- 振动、按压光场与转场动画只能人工感受，本轮只确认了调用路径与编译产物，未量化硬件触感。
- 华为账号登录成功路径（AGC 已配置）未验证；云同步未实现。

## 2026-10-07 · 视频参考 UX 革新

本轮实现分类准备模板与任务、独立完成进度、角色/计划参考图、团队本机分工、实际花费明细/分类统计，以及日期待定/单日/多日、时间段、列表/日历和可选系统提醒。新增与编辑仍统一 bindSheet，参考图与花费统计压入覆盖主页的 HdsNavDestination；所有详情仍使用 HdsTabs 操作栏。

- 正式包 `scripts/build.sh` 成功；SQL 关系检查 12/12。
- API 26 原生领域/持久化/媒体 Hypium：47/47，Failure 0 / Error 0。验证原 v1→v3 和 v2→v3 增量迁移、旧打包/照片保留、新角色/计划/任务原子创建、重复模板保留已完成任务、分类跨计划保护、实际花费独立、参考图文件清理与备份路径信任、v1/v2/v3 备份兼容和无效恢复回滚。数据库及媒体均为测试专用 verification 资源，结束清理，不写用户 personal.db。
- API 26 只读页面 Hypium：9/9，Failure 0 / Error 0。覆盖角色详情新路由、详情 HdsTabs、连续新建角色/计划取消、准备模板/关联衣柜/打包/照片返回、日期待定/多日表单、月历切换、照片导入计划选择取消、实际花费页面和记录弹层取消，以及合并后的操作模式与帮助 Sheet。
- 首轮页面 6 项中 4 Pass / 2 Error：同一组件连续绑定两个 bindSheet 导致前一个入口失效；改为单个绑定、固定内容类型后修复。随后日历测试发现测试定位仍使用旧动作名，修正 ID 与动作文案后 9 项全过；失败报告保留用于说明修复原因。
- 活动一级名称统一为「活动」，标题二级切换「列表 / 日历」，日期筛选只在列表显示，避免日历显示无效筛选条件；准备分类默认显示进度与下一项，展开后查看全部。

报告：`validation/ux-revolution-native-api26-report.txt`、`validation/ux-revolution-ui-api26-report.txt`。修复前记录：`validation/ux-revolution-ui-before-sheet-fix-api26-report.txt`、`validation/ux-revolution-ui-before-calendar-test-fix-api26-report.txt`。布局报告：`validation/ux-revolution-layout-api26-report.txt`。

提醒协调器已验证授权失败仍保存、数据库失败取消新提醒并保留旧提醒、请求未变不重复发布、编辑替换取消旧提醒；真实系统授权、后台定时投递与通知点击跳转尚未取得设备验收证据。页面存在与领域测试通过不代表真实提醒已送达。API 23、大字体、多窗、大屏、真实图库与跨设备备份仍按既有边界跟踪。

补充最终复核：只读布局 Hypium 4/4，Failure 0 / Error 0，八个二级视图的标题/分段/底栏保持固定，照片末项避让、重复点击回顶、重复校验 Toast、计划任务与照片详情返回均通过。活动标题及关联提示统一使用活动。截图发现活动、成员与花费填写示例沿用角色文案，已改为各自语境，重新执行正式包构建成功；该修改仅涉及字段标签/示例，不改变持久化或控件行为。

最新签名正式调试包已更新到当前连接手机（覆盖安装，保留业务数据）；本轮未验收的真实通知和其他设备形态继续由 ROADMAP 跟踪。


## 2026-10-07 · 分段控件外侧阴影修复

同步用户已在 Dashboard 真机确认的修复：单独裁剪 HdsMiniBarButton 的 HdsTabs 背景为胶囊形，背景不参与命中测试；HdsTitleBarSegment 显式使用 BlurStyle.NONE。保留本工程 Theme、全局视效开关、前景按压反馈与 V2 状态回调。`sh scripts/build.sh` 构建及签名成功，`git diff --check` 通过。本轮未安装 ElvaCos 修复包或执行真机截图验收，不能将 Dashboard 的验收结果视为本工程设备验证。

## 2026-10-07 · 日历联动与账号问题

新录屏逐秒查看约 13 秒：鞋子组、团队分工、自定义任务/分类、参考图、角色截止日期、活动日期/时间/备注/提醒。视频未展示账号/云空间实际报错。新增鞋子组和自定义分工；已有计划不自动生成新任务。

设备日历采用 Calendar Kit 的系统确认页，无完整日历读写权限；应用先保存活动，再打开日历，取消日历不回滚活动。全天多日结束时间为最后一天之后本地零点；仅有开始时间时默认一小时，带入地点、备注和提醒，用户在系统页选择账户/修改。日历副本由系统独立管理，不宣称应用双向同步。

- 正式与测试包构建通过；SQL 12/12；原生 Hypium 50/50，Failure 0 / Error 0。新增覆盖跨年全天末日、时间段/地点/备注/提醒映射、只标记开始时间和日期待定拒绝导出。
- 第一轮页面 Hypium 9/9，Failure 0 / Error 0：待定时隐藏日历开关、多日显示开关、云同步说明 Sheet 和既有全流程。
- 账号配置脚本在临时完整 manifest 副本中验证 4/4：拒绝错误包名、示例 ID、client secret，且不修改文件；真实格式公开 ID 保留既有权限/Ability 并新增 metadata/INTERNET。本轮没有给实际工程写入虚构 ID。
- 账号新增缺失配置提示、随机 state 与登录/退出响应校验；Preferences 写入成功后才更新界面状态，处理中提示只属于账号请求。

原生报告 `validation/calendar-native-api26-report.txt`。最终页面 Hypium 11/11，Failure 0 / Error 0；真实系统日历确认页与未配置账号前置阻断两项均通过。真正 AGC 登录成功、云端上传/账号隔离/跨设备同步、日历提醒后台投递均没有通过证据。当前云同步本就未实现，不能把修正状态说明与导出入口当成同步功能已经修复。接入步骤见 HUAWEI_ACCOUNT_SETUP.md；真实 Client ID/签名和用户报错仍待提供。

最终设备复核（API 26）：日历确认页显示验证日程名称、杭州·公园、2027-01-03 09:00–11:00、30 分钟前提醒和日历账户选择；测试只按返回/放弃，API 返回取消，重新回到首页。未点击系统保存，没有创建真实日历或应用业务记录。账号测试取得当前 EntryAbility Context，确认缺少 Client ID 时返回未成功与明确提示，不拉起系统授权。

报告：`validation/calendar-account-ui-api26-report.txt`；截图：`validation/device-calendar-confirm-api26.png`（仅包含未保存的测试日程）。最新正式包随页面测试安装，现有数据保留。系统确认成功取消不等于日历提醒已经在后台投递，后者继续待验收。

## 2026-10-07 · 用户 Client ID 接入与真实登录复核

用户确认公开 Client ID `6917618412076034516`，按完整字符串配置正式 entry metadata，并增加 INTERNET；没有推测 APP ID，没有保存 Client Secret。配置脚本支持省略 appId，保留既有 app_id 与其他 metadata。临时 manifest 检查 6/6：拒绝错误包名、占位符、数值 ID、secret 字段且不改文件；仅 Client ID 和完整公开 ID 两种有效配置均保留已有能力与权限。

最终正式与测试包构建成功，覆盖安装成功，保留用户业务记录。显式账号集成测试经正式设置页点「登录」，真实 Account Kit 返回 1001502003 / `Invalid input parameter value. Invalid clientId or profile.`；Hypium 字段为 **Pass 0 / Failure 0 / Error 1**，因此账号登录尚未验收通过。最终失败来自真实账号配置校验，不能把它计为测试通过。提示已映射到应用 Client ID / 签名 Profile 的核对步骤；失败未写入本机登录成功状态。

已检查签名 HAP 内 Client ID 完整一致；实际叶证书 SHA-256 与配置证书一致。SDK verify-app 验证整个签名包、代码签名、权限签名成功，Profile 在有效期内。Profile 包名为 top.rayawa.elvacos，app-identifier 为 6918744149341255159；仍待核对其与用户 AGC 应用的对应关系。中间证书与叶证书不是同一张证书，不能以两者指纹不同宣称 Profile 损坏或不匹配。

报告：`validation/account-client-id-api26-report.txt`、`validation/account-signature-api26-report.txt`。账号失败不触发云数据上传；应用云同步仍未接入。接入步骤和当前公开指纹见 HUAWEI_ACCOUNT_SETUP.md。

## 2026-10-07 · 光场与入场规则补齐

完成普通按钮、表单、设置行、静态信息卡片和紧凑标签的公共反馈接入；大框 BORDER，小控件 BORDER_CONTENT。主页一次性记录提升到 Index 启动会话，详情由独立 HdsNavDestination 的显示生命周期重播，Sheet 使用打开生命周期重播。参考图、花费统计、计划照片和宽屏设置介绍补齐入场。

正式与测试包编译/签名通过。首轮隔离布局 Hypium **Pass 5 / Failure 0 / Error 0**，涵盖窄/手机/宽屏、左右滚动隔离、任务路由与两倍字体；测试使用临时主模块、内存数据，未启动生产 AppState 服务，结束恢复正式包。随后补入缓存详情返回和重复 Sheet 的实际生命周期检查，以及按钮重复点击、滑块双向拖动和释放后尺寸复原检查，最终复测结果见下文。

本轮新增 API 的 since/syscap/permission 已核对华为官方资料与本机 SDK，见 UI_STYLE。没有关系结构/权限变更。光场亮度、HDR 和各类业务组件实际触摸观感尚未逐项人工验收；API 26 自动化通过不代表 API 23 或其他设备的视觉效果已验收。

第二轮隔离套件前 6 项（含按钮/滑块专项）通过，第 7 项打开详情时发生 App died；正式 UI 套件同样在详情进入时崩溃。错误日志定位为带参数匿名 BuilderParam 回调未生成 UI 构造逻辑（class constructor cannot called without new）。改用显式 @Builder 的绑定方法，正式包重新构建通过；不能把修复前部分用例通过当成完整套件通过。失败记录保存在 `validation/light-motion-before-builder-fix-layout-api26-report.txt` 和 `validation/light-motion-before-builder-fix-ui-api26-report.txt`，最终复测继续记录在下文。

修复后隔离布局与动效专项 Hypium **Pass 7 / Failure 0 / Error 0**。实际 HdsNavigation 先进入一级详情、再压入子详情、返回缓存父详情，入场启动次数从 1 变为 2；同一 Sheet 连续两次打开，打开次数从 1 变为 2，完成 step 均为 3；按钮两次点击分别到达回调，Slider 原生手势从 0→2→0，释放后按钮/滑块边界恢复。原 5 项窄屏/宽屏/大字体/滚动/任务路由也全部通过。报告 `validation/light-motion-layout-api26-report.txt`，测试结束已覆盖恢复最新正式与测试包，业务数据保留。

最终正式页面 Hypium **Pass 11 / Failure 0 / Error 0**，包含五个 Tab/分段、覆盖式详情与操作栏、连续新建/编辑取消、准备模板/衣柜关联/打包/照片返回、活动日期和月历、导入所属计划选择、花费统计和帮助 Sheet。正式包和测试包最终构建/签名及覆盖安装成功，保留用户数据；`git diff --check` 通过。报告 `validation/light-motion-ui-api26-report.txt`。本轮通过的是交互、布局和生命周期检查，光场/HDR 的人工视觉验收仍按 ROADMAP 跟踪。

收尾期间工程同步调整为 pages/Dashboard、pages/main|detail|more 与 component 目录；本轮 PressFeedback、DetailDestination、启动会话和 Sheet 进度逻辑已保留在新结构。同步调整过程中曾遇到常量迁移缺少 TaskTemplate 导入，随后当前工程已补齐，重新执行 scripts/build.sh 成功。以上 7/7 与 11/11 真机报告对应目录调整前的修复安装包；当前结构已再次验证编译，目录重组本身不以旧包的设备报告替代重新验收。

## 2026-10-07 · Dashboard 结构重构 / 1.0.0-beta.1（10000001）

本轮在编辑前对照读取两个工程的主源码、配置、文档及 ElvaCos 测试/脚本；Dashboard 保持只读。ElvaCos 的原有光场、动效、业务事务、v1→v2→v3 迁移、备份与媒体规则均保留。ets 目录归 ability/common/component/pages/main|detail|more，model/data 独立；同时迁移导入、主入口与备份入口、页面 profile、测试引用。仅大小写不同的 appState 文件名已显式记录重命名，避免在大小写敏感检出上丢失路径。

应用公共状态使用 AppStorageV2 单一实例，V1 设置通过原有 Preferences 与 @StorageLink 绑定，明确 Builder 桥接。移除默认状态实例、无消费的 WindowInsets 监听、废弃偏好/动画辅助入口、注释旧设置 UI 和未消费的分段输入。首帧后数据加载与维护分阶段执行，销毁先等待进行中的操作，Timer/握姿/异步回写有取消守卫；RdbStore.close 按官方 SDK 的 Promise 签名等待关闭。新增 AppLog 与原生 privacy.html 阅读页，宽高响应式、内容上限、花费原生条形图与筛选、中文无障碍；配色保留 Dashboard 同名资源，透明背景也纳入 base/dark。

正式包与测试包需同版本覆盖安装。device-test/ui-test/layout-test/settings-layout-test 均检查安装成功，再检查 Hypium 的 Tests run / Pass / Failure / Error / Ignore 字段；aa test 的返回码不能作为通过依据。关系测试使用临时加密库，媒体测试使用隔离目录，布局宿主只使用内存数据；未清空 personal.db。源码比对确认迁移 SQL 与提供的 privacy.html 均未改动，base/dark 颜色 key 一致；未修改 build-profile.json5、local.properties 或证书。

初轮页面复测在进入设置时发生 class constructor cannot called without new，定位为匿名 BuilderParam 回调直接构造 PreferenceSettings。改为明确的 @Builder 绑定后，设备日志完整记录页面套件 Pass 11 / Failure 0 / Error 0；最终脚本报告在收尾复测后记录。最终原生回归（含异步数据库关闭调整）Pass 55 / Failure 0 / Error 0 / Ignore 0，覆盖共享实例、本地文档可见正文/隐藏模板/实际 rawfile、销毁等待及既有领域/迁移/媒体；SQL 关系检查 12/12 通过。报告 validation/structure-native-api26-report.txt。

初轮隔离布局报告 Pass 7 / Failure 1 / Error 1，新增短横屏与图表用例通过；默认行高受 TestKit 可见区域截取影响，改为让完整行进入视口后测量。随后默认行高检查通过，大字体窄屏的材质行滚动定位继续专项复测；设备组件树确认 HDS 自定义卡片的行 ID 未进入 TestKit 树，改为按文字逐段滚动并处理空查询结果，保持原高度、字体缩放及完整文本检查。最终两倍字体专项 Pass 1 / Failure 0 / Error 0；不以专项通过代替完整套件。初轮失败报告保留为 validation/structure-initial-settings-layout-api26-report.txt。

最终完整隔离布局 Hypium **Pass 9 / Failure 0 / Error 0 / Ignore 0**，包含窄/手机/宽屏、两倍字体、短横屏、任务路由、左右滚动隔离、按钮/滑块、缓存详情与 Sheet 生命周期、分类金额比例与筛选。正式与测试包已自动覆盖恢复，用户数据保留。报告 validation/structure-settings-layout-api26-report.txt；字体专项报告 validation/structure-large-font-api26-report.txt。遵循本轮收尾要求，不扩大无关逐项测试；既有只读布局 4 项不重复运行，其旧报告不计为本轮新代码的设备验收。

### 验收边界

当前连接设备为 BRA-AL00 / API 26。同一手机上的 320、378、920vp 与短横屏画布只验证组件布局、滚动、字号和交互；真实 Tablet/2in1/折叠、多窗安全区、API 23 真机、系统字体跟随与读屏人工操作继续列为未验收。真实账号登录、云同步、代理提醒送达与 HDR/握姿硬件观感保留原未验收记录。

privacy.html 是提供的唯一正文源；其云端服务、服务器、账号注销与撤回同意描述与当前离线实现有差异。正文未改写，未增加对应假功能；本轮完成的是阅读页及内容来源验证，发布前仍需维护者核对政策与实际能力。


### 收尾调整与 Dashboard 交互补齐

更新日志补齐 Dashboard 的 Beta / RC / 正式版三个独立标题栏开关、开启/关闭图标、Toast 与触觉、无结果提示、正式版标识和卡片公共按压反馈；设置入口使用 app_log 图标。日志的构建号归属各条记录，避免以后历史版本显示当前构建号。根路由仍只生成一个 HdsNavDestination，筛选保持页面局部，不增加应用共享状态。已有页面冒烟用例补入 Beta 关闭/恢复与另外两个筛选入口检查，没有增加套件或逐项设备循环。

筛选补齐后的最终正式包 scripts/build.sh 编译/签名成功；构建仍有已有弃用 API 与异常处理提示，不宣称零警告。原生 55/55 与隔离布局 9/9 的报告对应筛选补齐之前的业务/布局版本，本轮没有再重复这两套设备回归。

正式页面整套冒烟收尾时，原设备 MJE0223906038678 已断开：构建成功，安装报 Device not found or connected，未执行该轮页面测试，不计为通过，也未向其他新连接设备安装。此前 Builder 修复后的完整页面日志为 Pass 11 / Failure 0 / Error 0；它不代替新增日志筛选的真机交互验证。按照当次任务的优先级，继续完成重构、性能、页面缺失和文档，未扩大设备排查。

AGENTS、README、架构、风格、能力、UX 与账号说明明确为现状/参考；ROADMAP 整理为当前能力、已知问题和可选方向。旧规范不自动成为后续任务的强制流程，验证记录也不要求后续重复整张清单。关系兼容、用户数据隔离和签名私密配置仍作为具体实现考虑保留。

最终 ohosTest 测试包也编译/签名成功；正式与测试构建及断开设备的记录见 validation/structure-final-build-report.txt。没有把新增筛选的测试编译计为设备交互通过。


### 设置首次入场与原生列表触摸

按当前用户要求，设置目的地与五个主页共享根页面的 MainEntranceSession。首次显示领取 SettingsPage 的启动会话记录并播放；离开时取消定时器且完成到最后一组，缓存返回和弹出后重新创建直接显示完整内容。新的应用启动建立新的会话。其他业务详情仍按每次显示重播，Sheet 打开行为保留。

SettingsActionRow / SettingsValueRow / SettingsPreferenceRow / SettingsPanel / SettingsChoiceSlider 移除额外 PressFeedback、clickEffect 及分组容器的按压绑定，避免覆盖 HdsListItemCard 或行内原生控件的触摸处理；设置操作、确认、持久化和触觉回调保留。帮助 Sheet 独立按钮继续使用公共反馈。

scripts/build.sh 编译/签名成功。直接转译实际会话和生命周期方法，使用动画桩完成 8/8 逻辑检查：首次显示、退出清理、缓存返回、组件重建、新启动、普通详情、独立设置宿主和导航托管宿主。另核对五个设置组件及列表容器无额外触摸覆盖。报告 validation/settings-once-native-touch-report.txt；这是源码逻辑与编译证据，不替代设备动画或原生触摸观感，本轮没有再启动完整设备套件。

日志筛选使用实际 getter 和菜单方法完成八种开关组合检查，图标、中文状态文案、反馈调用及切换恢复正确；报告 validation/log-filter-source-check-report.txt。当前实现核对未发现旧目录导入、动态类型、业务硬编码颜色，浅深色资源 key 一致，提供的 privacy.html 与重构前逐字节相同，版本与构建号保持 1.0.0-beta.1 / 10000001。


## 2026-10-08 · 布局、照片筛选、光效与图表

修正首页下一场活动倒计时居中、长标题约束与当天状态文案；照片/作品卡片增加说明区留白并保持图片裁剪。作品只提供全部作品、成片、已发布筛选。PhotoGrid 维持稳定的 IDataSource，并在筛选、照片集合、批量选择和列数变化时通知 onDataReloaded，修复下拉框已更新但懒加载照片仍显示旧结果的问题。

按钮光效的实机问题定位为 AttributeUpdater 更新 HDS visualEffect 不生效：现有 PressFeedback 节点改为直接绑定 @ObservedV2 按压状态的 visualEffect / compositingFilter，updater 保留触摸与缩放。轻点保留最短 140ms、取消立即复位。日历日期表面承接点光源，移除额外 pressShadow，保持 Dashboard 光场实现。实际长按截图确认「今天」按钮与日期格点光源及附近格子的受光效果。

新增近半年花费折线和照片处理分布环形图，来源为 Dashboard InteractiveLineChart / DistributionPanel 的 Canvas 画法。适配 V2、Theme、资源色、入场动画和选点/图例，环境变化后主动重绘；首尾月份标签完整显示。月份聚合先累计整数分、跨年和空月补零；照片分组互斥，包含已归档。

最终正式包与 ohosTest 构建、签名及覆盖安装成功。API 26 实机专项 **Pass 7 / Failure 0 / Error 0 / Ignore 0**，覆盖跨年/金额精度、照片状态合计、作品筛选规则、倒计时居中、实际筛选后照片刷新、日历按钮操作、花费折线选月。领域计算使用内存对象，界面回归只切换临时选择；没有写入或清空 personal.db。保留既有构建警告，不宣称零警告。

运行脚本：scripts/ui-polish-test.sh。报告：[ui-polish-api26-report.txt](validation/ui-polish-api26-report.txt)；截图：[日历日期按压](validation/ui-polish-calendar-pressed-api26.jpeg)、[月度花费折线](validation/ui-polish-expenses-api26.png)。已人工查看照片说明区、作品筛选结果与两处图表；未扩展为完整设备或字号矩阵验证。
