# 绮秀 ElvaCos · 视觉设计系统审计

> 只读审计。代码基准 `git 38e97f6`（2026-10-08 02:57，工作区无源码改动）；未运行构建/测试/设备命令。
> 审计对象：`common/{Theme,ThemePalettes,constants,Icons,visualEffects,motion,pressFeedback,vibration,safeUi}.ets`、`resources/{base,dark}/element/*`、`component/{Surfaces,ManagedImage,ReferenceGallery,PhotoGrid,...}.ets`、全部 `pages/**`。
> 截图：`docs/validation/theme-palettes-api26.png`（10-08，五主题控件参考页，由应用组件真实渲染，非产品页面）；`docs/validation/settings-{narrow,phone-large-font,narrow-large-font}-api26.png` 来自 **ohosTest 布局测试台**（`entry/src/ohosTest/ets/testability/pages/SettingsLayout.ets:58/71/108`，大字版为 `setFontSizeScale(2)`、画布外空白是测试台背景而非应用缺陷，且为改名前构建）；`.shots/{80,81,90,91,93,102}.*`（10-07，改名前构建，仅用于布局/字号/图标观感，颜色结论一律来自资源文件计算）。
> 量化方法：`grep -rhoE` 全仓统计 + Python 按 WCAG 2.x 相对亮度公式计算（脚本见附录 B）。

---

## 1. 一句话结论

**色彩基础设施是「已完成 80% 的半成品设计系统」，排版与几何是「零 token 的散装样式」**：五组浅深配色全部资源化、正文对比度达标（12.9–16.3:1），但字号（185 处硬编码 / 18 档）、间距（139 处硬编码 gap / 13 种值）、圆角（30 处硬编码 / 11 种值）、卡片层级（7 种处理）完全没有 token；浅色主题的卡片与输入框边界只有 1.05–1.29:1，深色主题的卡片比页面背景更暗，导致整个界面「糊成一片、层级读不出来」——**最大短板不是配色，而是排版尺度与层级（elevation）系统缺失**。

---

## 2. 量化现状

### 2.1 字号：事实上的 type scale 是「18 档平铺」

全仓 `.fontSize(` **185 处**，其中纯数字 181 处、动态表达式 4 处（`ProjectCard.ets:44` 三元、`InteractiveLineChart.ets:479` 三元、`LocalHtmlPage.ets:59` 三元、`ProjectDetailPage.ets:519` 三元，额外产生 23vp）。字面量 **18 个不同值**，加上动态值实际渲染 **19 档**；`Theme.ets` 中 **0 个字号 token**（`Theme.ets:86-105` 只有布局尺寸）。

| 字号 | 次数 | 占比 | 实际承担的语义（证据） |
|---|---|---|---|
| 32 | 3 | 1.6% | 大数字：首页倒计时 `HomePage.ets:65`、活动日期 `EventsPage.ets:48`、占位首字 `ProjectCard.ets:30` |
| 30 | 1 | 0.5% | 占位首字 `CosPage.ets:57`（与 32 同角色） |
| 26 | 6 | 3.2% | **四种角色**：问候标题 Bold `HomePage.ets:94`、应用名 Bold `SettingsPage.ets:163`、统计数字 Regular `MePage.ets:53/58/63`、箭头 `'›'` Regular `CosPage.ets:69` |
| 25 | 1 | 0.5% | 准备进度数字 `ProjectCard.ets:59` |
| 24 | 3 | 1.6% | 统计金额 Regular `ExpenseSummaryPage.ets:139`、准备进度 Medium `ProjectDetailPage.ets:224`、箭头 `'›'` `HomePage.ets:82` |
| 21 | 1 | 0.5% | 角色名 Bold `CosPage.ets:66` |
| 20 | 4 | 2.2% | 详情实体标题 Medium `AssetDetailPage.ets:32`/`CharacterDetailPage.ets:42`、活动名 Bold `EventsPage.ets:52`、图标尺寸 `TaskLinkCard.ets:17` |
| 19 | 4 | 2.2% | 详情实体标题 Medium `EventDetailPage.ets:72`/`ProjectDetailPage.ets:127`/`LibraryPage.ets:57`、Sheet 标题 `SheetHeader.ets:19` |
| 18 | 5 | 2.7% | 图表标题 Bold（`DistributionChart.ets:110`、`InteractiveLineChart.ets:520`）、版本号 `AppLogPage.ets:81`、角色版本名 `CharacterDetailPage.ets:78` |
| 17 | 4 | 2.2% | 日历标题/活动名 Regular `EventCalendar.ets:34/92`、日记正文 `MePage.ets:44`、活动名 Medium `HomePage.ets:76` |
| 16 | 19 | 10.3% | 设置行标签 `SettingsPanel.ets:55/375/498/652`、空态标题 `Surfaces.ets:66`、装备名 `ProjectDetailPage.ets:364` |
| 15 | 9 | 4.9% | 分组标题 Medium muted `Surfaces.ets:47`、任务名 `ProjectDetailPage.ets:324`、更新日志正文 `AppLogPage.ets:97`、日历日期 `EventCalendar.ets:65` |
| 14 | 25 | 13.5% | 正文/值：`FactRow` 取值 `Surfaces.ets:116`、设置值 `SettingsValueRow.ets:28`、按钮 `Surfaces.ets:71` |
| 13 | 42 | 22.7% | 次级正文/表单标签：`DateField.ets:34`、`FormEditor.ets:79/133/143`、`FactRow` 标签 `Surfaces.ets:113` |
| 12 | 50 | 27.0% | 元信息/药丸/说明：`SectionHeading` trailing `Surfaces.ets:48`、`StatusPill` `Surfaces.ets:94`、`SettingsValueRow` 提示 `:22` |
| 11 | 2 | 1.1% | 照片所属计划 `PhotoGrid.ets:137`、分类完成数 `ProjectDetailPage.ets:272` |
| 10 | 1 | 0.5% | “准备进度”说明 `ProjectCard.ets:62` |
| 8 | 1 | 0.5% | 日历事件圆点 `'●'` `EventCalendar.ets:68` |

**分档占比**（按 181 处字面量计）：展示级 24–32（14 处，7.7%）、标题级 18–21（14 处，7.7%）、小标题/强调 15–17（32 处，17.7%）、正文 13–14（67 处，37.0%）、说明 ≤12（54 处，29.8%）；另有 4 处三目字号按分支归入对应档。

**同类角色多值冲突（核心证据）**：

| 语义角色 | 现用值 | 证据 |
|---|---|---|
| 详情实体标题 | **19 / 20 / 21 / 23**（4 个值） | `EventDetailPage.ets:72`、`AssetDetailPage.ets:32`、`CosPage.ets:66`、`ProjectCard.ets:44` |
| 分组标题 | **14 Bold accent / 15 Medium muted / 16 Medium ink / 18 Bold ink** | `SettingsPage.ets:73-78`、`Surfaces.ets:47`、`SettingsPage.ets:91`、`DistributionChart.ets:110` |
| 列表主标题 | **15 / 16 / 17** | `TaskLinkCard.ets:19`、`SettingsValueRow.ets:21`、`HomePage.ets:76` |
| 列表正文/值 | **13 / 14 / 15 / 16 / 17** | `Surfaces.ets:113/116`、`ProjectDetailPage.ets:324` |
| 元信息/说明 | **10 / 11 / 12 / 13** | `ProjectCard.ets:62`、`PhotoGrid.ets:137`、`Surfaces.ets:48`、`EventCalendar.ets:93` |
| 大数字 | **24 Regular / 25 / 26 Regular / 32 Lighter** | `ExpenseSummaryPage.ets:139`、`MePage.ets:53`、`HomePage.ets:65` |

**字重/行高**：`.fontWeight(` 39 处（Medium 23、Bold 8、Lighter 4，另 4 处三元动态），**0 token**；`.lineHeight(` 仅 **2 处**（`InteractiveLineChart.ets:593`、`LocalHtmlPage.ets:62`）；`.letterSpacing(` **0 处**。中文字体在 12–13vp 且无行高时，行距完全依赖系统默认值，长文本（帮助正文、日记）节奏不一致。

**最小字号**：10vp（`ProjectCard.ets:62`）、11vp（`PhotoGrid.ets:137`、`ProjectDetailPage.ets:272`）低于当前移动端可读下限；12vp 共 50 处，其中状态药丸与页脚均为 12vp。

#### 建议的 7 级语义 type scale（可直接替换）

| token | vp | 字重 | 行高 | 用途 | 替换现用值 |
|---|---|---|---|---|---|
| `fontDisplay` | 32 | Lighter (300) | 40 | 首页倒计时、活动日期块、完成率等“展示数字” | 30、32（保留 32，30→32） |
| `fontTitle` | 24 | Bold (700) | 32 | 问候/页面主标题、统计大数字、应用名 | 24、26 |
| `fontHeading` | 19 | Medium (500) | 26 | 详情实体标题、Sheet 标题、图表标题、事件名 | 18、19、20、21、23 |
| `fontSubheading` | 16 | Medium (500) | 22 | 卡片标题、设置行标签、空态标题、列表强调 | 15、16、17 |
| `fontBody` | 14 | Regular (400) | 21 | 正文、值、按钮 | 14 |
| `fontLabel` | 13 | Regular (400) | 19 | 表单标签、次级正文、FactRow 标签 | 13 |
| `fontCaption` | 12 | Regular (400) | 17 | 元信息、药丸、说明、页脚 | 8、10、11、12 |

> 角色变体（不新增字号）：`fontCaption` 用 Medium + `letterSpacing 0.3` 作为 **overline**（分组标题，替换 15 Medium / 14 Bold accent）；`fontDisplay`/`fontTitle` 固定 Lighter/Bold，不再出现同尺寸不同字重。
> 若要更激进，可把 13 合并进 14 得到 6 档；本报告建议保留 13，因为表单标签场景有 42 处，合并会让密集页（ProjectDetailPage 28 处、SettingsPage 20 处）明显变松。

**最小改造清单（type scale）**

| # | 动作 | 文件 | 成本 |
|---|---|---|---|
| T1 | 在 `Theme.ets` 增加 7 个字号 + 3 个行高 + 2 个 overline 常量（见 §4） | `common/Theme.ets` | S |
| T2 | `Surfaces.ets` 5 个公共组件（SectionHeading/EmptyState/StatusPill/FactRow/Field）全部改用 token | `component/Surfaces.ets:42-166` | S |
| T3 | 详情实体标题统一 `fontHeading` 19 Medium：改 4 个文件的 6 处 | `EventDetailPage:72`、`ProjectDetailPage:127`、`LibraryPage:57`、`AssetDetailPage:32`、`CharacterDetailPage:42`、`EventsPage:52`、`CosPage:66` | S |
| T4 | 分组标题统一 overline（12 Medium muted）：`SettingsPage.groupTitle`、`Surfaces.SectionHeading`、chart 标题 | `SettingsPage.ets:73-78`、`Surfaces.ets:47`、`DistributionChart.ets:110`、`InteractiveLineChart.ets:520` | S |
| T5 | 10/11vp 全部升 12vp（3 处）；`'›'` 24/26 改为 20vp 图标 | `ProjectCard.ets:62`、`PhotoGrid.ets:137`、`ProjectDetailPage.ets:272`、`HomePage.ets:82`、`CosPage.ets:69` | S |
| T6 | 统计数字统一：MePage 26 Regular → `fontTitle` 24 Bold（或 32 Lighter，二选一并全站一致） | `MePage.ets:53/58/63` | S |
| T7 | 全仓 185 处按映射表批量替换 + 逐页目检（重点 3 页占 59 处） | 35 个文件 | M |

### 2.2 圆角：11 种值，同名同级不同半径

`borderRadius(` 共 **54 处**：Token `Theme.cardRadius`(16) **20 处**；硬编码数字 **30 处 / 11 种值**（4、5、6、10、11、12、14、16、18、20、22）；计算值 4 处（`/2` 胶囊）。

| 圆角 | 次数 | 典型用途 | 问题 |
|---|---|---|---|
| 4 / 5 / 11 | 3 | 图例色点（`DistributionChart.ets:129`）、图表点（`InteractiveLineChart.ets:486`）、色板圆点（`ThemeColorPicker.ets:28`） | 装饰件，可归为 `radiusFull` |
| 6 | 1 | 版本徽章 `AppLogPage.ets:86` | 与 8 无区别 |
| 10 | 2 | 图表图例 chips `DistributionChart.ets:132`、`InteractiveLineChart.ets:493` | 与 12 无区别 |
| 12 | 4 | StatusPill `Surfaces.ets:99`、色板按钮 `ThemeColorPicker.ets:37` | 药丸应=全圆 |
| **14** | **10** | 卡片内媒体（`ProjectCard.ets:24/35`、`PhotoGrid.ets:121/128`、`CosPage.ets:51/60`、`HomePage.ets:213/216`、`EventCalendar.ets:75`、`PreparationTemplatePicker.ets:47`）+ `ManagedImage.radius` 默认 14 | **全仓最高频硬编码半径**；卡片是 16、内媒体 14，差值 2 无规律 |
| 16 | 7 + token 20 | 卡片 `Theme.cardRadius`、设置页三张卡 `SettingsPage.ets:207/241/259`、设置面板 `SettingsPanel.ets:310` | Token 与硬编码 16 并存 |
| **18** | **3** | Sheet 关闭键 `SheetHeader.ets:38`、角色版本行 `CharacterDetailPage.ets:101`、**装备行** `ProjectDetailPage.ets:381` | 同一详情页里 18/16/16/20 混排 |
| 20 | 1 | **打包行** `ProjectDetailPage.ets:535` | 同为“详情行” |
| 22 | 1 | 应用图标 `SettingsPage.ets:159` | — |

**同一页内的半径不一致（最有力证据）**：`ProjectDetailPage` 的四类列表行——装备行 18（`:381`）、团队行 16（`:441`）、花费行 16（`:483`）、打包行 20（`:535`），它们视觉层级完全相同。

**半径是否随层级递增**：粗看是（点 4/5 < chip 10/12 < 媒体/card 14/16 < 面板 18/20 < 图标 22），但同层内不收敛；按钮是系统胶囊（全圆）、卡片 16、输入框无圆角、媒体 14——**四种几何语言**同时出现。

### 2.3 间距：139 处硬编码 gap / 15 种 padding 值，不在 4/8 网格

| 统计项 | 总量 | 走 token | Token 化率 |
|---|---|---|---|
| `space:`（Row/Column/List 间距） | 166 | 27（`Theme.sectionSpacing` 等） | **16%** |
| `.padding(` | 70 | 22（`Theme.pagePadding` / `sectionTitlePadding`） | 31% |
| `.margin(` | 19 | 0 | **0%** |
| `.lineHeight(` | 2 | 0 | 0% |

**`space:` 值分布（13 种）**：12(35)、8(28)、10(16)、6(11)、5(11)、14(11)、16(9)、4(5)、3(4)、18(3)、1(3)、7(2)、2(1)。

**padding 数值原子分布（15 种 / 71 个原子）**：0(1)、2(7)、4(5)、5(2)、6(4)、7(4)、8(2)、10(3)、11(2)、12(7)、**14(11)**、**16(10)**、18(6)、20(1)、24(6)。

**问题**：
1. 页面 gutter `LAYOUT_PAGE_PADDING=14`（`constants.ets:144`）、分组间距 `LAYOUT_SECTION_SPACING=14`（`:140`）都不是 4 的倍数；而卡片内 padding 同时有 **14/16/18/20/24** 五档（`Surfaces.ets:15/79`、`ProjectDetailPage.ets:348`、`MePage.ets:100`、`Dashboard.ets:384`、`FormEditor.ets:357`）。
2. 同一屏内混用两套节奏：`PhotoGrid` 列表用 `Theme.sectionSpacing`=14（`PhotoGrid.ets:150`），而它所在的一级页 Column 用 `space: 12`（`CosPage.ets:75`、`HomePage.ets:242`）。
3. 奇数间距 5/7/11 集中在设置行内（`Surfaces.ets:52`、`SettingsPanel.ets:657`、`ProjectDetailPage.ets:325`），属于凭手感微调，没有系统依据。

### 2.4 阴影 / 描边 / 卡片层级：7 种“卡片”处理

| # | 处理方式 | 证据 | 用于 |
|---|---|---|---|
| 1 | `bg surface + border 1 + shadow r12/y3 + 点光源 + HDR filter` | `Surfaces.ets:27-32` | `InteractiveCard`（全站最常用卡片） |
| 2 | `bg surface + radius + shadow r8/y2 + 点光源`（无 border） | `Surfaces.ets:79-85` | `EmptyState` |
| 3 | `bg surface + radius16 + shadow r8/y2`（无 border） | `SettingsPage.ets:207/241/259`、`SettingsPanel.ets:310-312`、`AppLogPage.ets:101-103`、`DevPage.ets:86-87` | 设置类面板 |
| 4 | `bg surface + radius16/18/20 + 点光源`（无 border、无 shadow） | `ProjectDetailPage.ets:381/441/483/535`、`CharacterDetailPage.ets:101`、`MePage.ets:68` | 详情列表行 |
| 5 | `bg surface + radius + border 1`（无 shadow） | `DistributionChart.ets:146-147`、`InteractiveLineChart.ets:603-604` | 图表卡 |
| 6 | `bg surface + radius + border`（筛选选中态） | `ExpenseSummaryPage.ets:76-78` | 分类卡 |
| 7 | `bg tint` 无阴影无描边 | `DashboardSearch.ets:15` | 搜索框 |

- **border + shadow 叠加只有 1 处**（`Surfaces.ets:27-28`），但“点光源 + HDR 合成 + 缩放”是 4 层视觉效果叠加在同一节点（`Surfaces.ets:28-32`），全仓 `visualEffect` **116 处**、`compositingFilter` **116 处**、`attributeModifier` **112 处**。
- **阴影强度**：浅色 `#1A1A2B45`（10% alpha，`base/color.json:45`），深色 `#66000000`（40% 黑，`dark/color.json:45`）。深色下 40% 黑阴影叠在近黑背景上几乎不可见，属于“脏边”式无效层级。
- **卡片/分割线对比度全部 < 3:1**（见 §2.5）：浅色卡片面/页面背景 1.05–1.07:1、卡片描边 1.29–1.46:1、行分割线 1.59–1.90:1。
- **层级方向在深色模式反了**：深色 `surface`（#182231）比 `bg`（#1A2B3C）更暗，卡片是“凹”的；`tint`（#101927）最暗。五组深色 palette 全部如此（`dark/theme_colors.json`：green surface #1C312C < bg #203833；pink #30222C < #382733；orange #30271F < #382D22；red #312125 < #39282B）。截图 `.shots/90-dark.jpeg`、`.shots/91-dark-restart.jpeg` 可直观看到计划卡比页面底色更暗。

### 2.5 WCAG 对比度（浅色 + 深色 × 五组主题）

计算口径：WCAG 2.x 相对亮度；正文/小字阈值 **4.5:1**，大字号（≥18.66vp bold 或 ≥24vp）与图形/控件边界阈值 **3:1**。⚠️ 标记为不达标。

**浅色（base 资源）**

| 组合（前景 / 背景） | 阈值 | 蓝 | 绿 | 粉 | 橙 | 红 |
|---|---|---|---|---|---|---|
| 正文 `ink` / `bg` | 4.5 | 15.43 | 12.92 | 13.73 | 12.98 | 13.78 |
| 正文 `ink` / `surface` | 4.5 | 16.27 | 13.62 | 14.65 | 13.67 | 14.74 |
| 次级 `muted` / `bg`（12–13vp） | 4.5 | 5.14 | 4.75 | 5.06 | 4.81 | 5.03 |
| 次级 `muted` / `tint`（12–13vp） | 4.5 | 4.92 | **4.51** | 4.62 | 4.52 | 4.61 |
| 强调文字 `accent` / `surface` | 4.5 | 4.99 | 5.32 | 5.61 | 5.83 | 5.64 |
| 状态药丸 `accent` / `tint`（12vp） | 4.5 | **4.52** | 4.79 | 4.80 | 5.22 | 4.83 |
| 按钮字 `onAccent` / `brand`（14vp） | 4.5 | 4.99 | 6.26 | 5.85 | 6.50 | 5.48 |
| 危险文字 `danger` / `surface` | 4.5 | 5.28 | 5.28 | 5.28 | 5.28 | 5.28 |
| 卡片描边 `line` / `surface` | 3.0 | ⚠️1.29 | ⚠️1.29 | ⚠️1.42 | ⚠️1.38 | ⚠️1.46 |
| 行分割 `divider` / `surface` | 3.0 | ⚠️1.59 | ⚠️1.60 | ⚠️1.79 | ⚠️1.76 | ⚠️1.90 |
| 卡片面 `surface` / `bg`（层次） | 3.0 | ⚠️1.05 | ⚠️1.05 | ⚠️1.07 | ⚠️1.05 | ⚠️1.07 |
| 图形填充 `brand` / `surface`（进度、滑块、主按钮、色板） | 3.0 | 4.99 | ⚠️2.07 | ⚠️2.20 | ⚠️1.86 | ⚠️2.39 |

深色数值（资源文件读取）

| 组合（前景 / 背景） | 阈值 | 蓝 | 绿 | 粉 | 橙 | 红 |
|---|---|---|---|---|---|---|
| 正文 `ink` / `bg` | 4.5 | 13.09 | 11.63 | 12.73 | 12.53 | 12.65 |
| 正文 `ink` / `surface` | 4.5 | 14.51 | 12.77 | 13.79 | 13.67 | 13.91 |
| 次级 `muted` / `bg` | 4.5 | 6.86 | 6.96 | 7.20 | 7.33 | 7.14 |
| 次级 `muted` / `tint` | 4.5 | 8.39 | 8.69 | 8.72 | 8.97 | 8.68 |
| 强调文字 `accent` / `surface` | 4.5 | 5.45 | 8.35 | 7.93 | 8.79 | 7.44 |
| 状态药丸 `accent` / `tint` | 4.5 | 6.00 | 9.50 | 8.86 | 9.86 | 8.23 |
| 按钮字 `onAccent` / `brand` | 4.5 | 6.00 | 7.83 | 6.77 | 7.27 | 6.37 |
| 危险文字 `danger` / `surface` | 4.5 | 6.96 | 5.99 | 6.57 | 6.36 | 6.64 |
| 卡片描边 `line` / `surface` | 3.0 | ⚠️1.28 | ⚠️1.52 | ⚠️1.50 | ⚠️1.57 | ⚠️1.53 |
| 行分割 `divider` / `surface` | 3.0 | ⚠️1.39 | ⚠️1.83 | ⚠️1.76 | ⚠️1.93 | ⚠️1.85 |
| 卡片面 `surface` / `bg` | 3.0 | ⚠️1.11 | ⚠️1.10 | ⚠️1.08 | ⚠️1.09 | ⚠️1.10 |
| 图形填充 `brand` / `surface` | 3.0 | 5.45 | 8.35 | 7.93 | 8.79 | 7.44 |

**结论**

1. **文字层面基本达标**：正文 11.6–16.3:1、次级 4.51–8.97:1、按钮字 4.99–7.83:1、危险文字 5.28–6.96:1，全部 ≥4.5:1。这是配色资源直接对齐了 WCAG，值得肯定。
2. **临界项 4 个**：`muted`/`tint` 4.51（绿）、`accent`/`tint` 4.52（蓝）、4.61–4.83——都在 12vp 小字上使用，容差仅 0.01–0.3，任何一次主题微调就会跌破。建议把 `muted` 压深约 5%，把蓝色 `accent` 从 `#1E6FCD` 压到 `#1A64BC`（色相不变，`/tint` 5.30:1、`/surface` 5.84:1）。
3. **图形/控件边界全部不达标**：卡片描边 1.28–1.57、行分割 1.39–1.93、输入框填充（用 `Theme.bg`/`Theme.tint` 当输入面）仅 1.05–1.17——低于 3:1；`Field` 的 `TextInput` 直接 `backgroundColor(Theme.bg)`（`Surfaces.ets:145/156`），在浅色里白底上几乎看不见输入框。**这是 P0 级问题**。
4. **浅色四组主题的主按钮/进度/滑块填充 1.86–2.39:1**：蓝色 4.99 达标，绿/粉/橙/红全部不达标。
5. **深色下 help 图标** `question.png` 平均色 `#676767`（见 §2.6）在 surface `#182231` 上 **2.83:1**，低于 3:1；其余设置图标有深色版（`#FBFBFB`）。
6. **分段控件选中胶囊**：`segmented_color_selected` = `#22666666`（13% 灰）→ 合成后 `#EBEBEB`，对白卡 **1.19:1**；深色 `#22FFFFFF` → `#373F4C`，对 `#182231` **1.51:1**（`base/color.json:9`、`dark/color.json:9`、`HdsTitleBarSegment.ets:25/44`）。

### 2.6 图标：4 套体系 + 41 处文字符号冒充图标

`Icons.ets` 定义 36 个条目，**全部被引用（0 死条目）**，但来源分成 4 族：

| 来源 | 数量 | 证据 | 风格 |
|---|---|---|---|
| `sys.media.*`（系统 PNG 图标） | 11 | `Icons.ets:13-17/46-52` | 单色、边缘粗细不一 |
| `sys.symbol.*`（矢量符号） | 2 + 2 个 SymbolGlyphModifier | `Icons.ets:18/50/53-58` | 描边线性 |
| `app.media.*`（自绘 PNG，浅/深两版） | 21 | `Icons.ets:21-35/38-43` | 线性 1.7–2px，深色版 `#FBFBFB` |
| 文本符号当图标 | **41 处 / 12 个文件** | 见下表 | 字体字形，随字号变粗变细 |

**文本符号清单（41 处 / 38 行）**

| 符号 | 处数 | 位置 |
|---|---|---|
| `＋`（加） | 20 | `ProjectDetailPage.ets:66/80/168/180/258/292/347/387/409/446`、`ReferenceGallery.ets:20`、`EventCalendar.ets:109`、`HomePage.ets:119/159`、`CosPage.ets:103/117`、`EventsPage.ets:97`、`ExpenseSummaryPage.ets:118`、`FormEditor.ets:80/82` |
| `−`（删/减） | 7 | `ProjectDetailPage.ets:300/336/431/473/524`、`CharacterDetailPage.ets:92`、`ExpenseSummaryPage.ets:110` |
| `✓` / `○`（勾选态） | 5 | `ProjectDetailPage.ets:107/312`、`PhotoGrid.ets:135`**（“✓ 已选 / ○ 点选”纯文字表达选中态）** |
| `›`（箭头） | 4 | 文本：`HomePage.ets:82`（24vp）、`CosPage.ets:69`（26vp）、`AssetDetailPage.ets:63`；按钮：`EventCalendar.ets:35` |
| `★` / `☆`（收藏） | 3 | `CosPage.ets:66`、`CharacterDetailPage.ets:53` |
| `●`（事件圆点） | 1 | `EventCalendar.ets:68`（**8vp**） |
| `•`（项目符号） | 1 | `AppLogPage.ets:95`（16vp） |

**尺寸不统一**：图标渲染尺寸有 14（`ThemeColorPicker.ets:30` checkmark）、16（`TaskLinkCard.ets:22` chevron）、18（`SheetHeader.ets:32` xmark）、20（`TaskLinkCard.ets:17`、`SettingsActionRow.ets:16`）、22/24（`SettingsPanel.ets:84/666` 帮助图标）、24/26（`'›'` 文本）——**同一“菜单/箭头/动作图标”语义跨 6 档尺寸**，无尺寸 token。

**语义错位（底栏，截图可直接看到）**：`Icons.ets:13-17` 的底栏图标取自系统资源名——`home` 用 `return_home_fill`、`cos` 用 `ohos_user_auth_icon_face`（人脸认证图标）、`me` 用 `person_badge_waveform`（人像+声波）、`library` 用 `rectangle_filled_and_line_horizontal_and_rectangle`（字面意义的“矩形+横线+矩形”）。在 `.shots/93-light-restored.jpeg`、`.shots/91-dark-restart.jpeg` 中，五个 Tab 分别是“箭头房子 / 笑脸 / 时钟 / 层叠矩形 / 人像声波”，风格与语义均不统一。

**僵尸资产**：`resources/base/media/` 里有 11 个**零引用**的自绘 SVG（`nav_home/nav_cos/nav_event/nav_library/nav_me`、`action_add/check/delete/edit/import/share`），全部写死 `stroke="#598C72"`（绿色，`nav_home.svg` 等）——它们本可以统一图标风格，但与主题无关的硬编码色决定了它们一旦启用就会在其余四组主题下串色。

**深色图标缺版**：`base/media` 24 个 PNG 中，`question.png`（`Icons.help`，用于 `SettingsPanel.ets:82/664`）**没有 dark 版本**，其余 20 个功能图标都有（对比度实测 2.83:1，见 §2.5-5）。

### 2.7 触控目标：12 类 < 44vp，共 20+ 处

> 判定依据：ArkUI `Button` 默认高度 40vp；`Text` 行高 ≈ 1.4×字号；`.onClick` 挂载在哪个节点就把哪段几何当命中区。低于 44vp（任务给定阈值；HOS 建议 48vp）者列出：

| 元素 | 尺寸 | 证据 | 备注 |
|---|---|---|---|
| 关闭按钮（所有 Sheet） | **36×36** | `SheetHeader.ets:35-38` | 每张表单/详情 Sheet 都有 |
| 主题色板 5 个色块 | **34 宽 × 52 高**，间距 4 | `ThemeColorPicker.ets:36` + `:44`（Row 宽 190 / 5） | 相邻命中区间距仅 4vp，易误触 |
| 设置行内动作按钮 | **minHeight 36** | `SettingsValueRow.ets:35` | “说明/导出”等 |
| 角色收藏按钮 | **minHeight 36** | `CharacterDetailPage.ets:55` | — |
| “关联已有”按钮 | **minHeight 36** | `EventDetailPage.ets:137` | — |
| 滑块档位标签（可点） | **40 宽 × ~17 高** | `SettingsChoiceSlider.ets:72/75/79` | 宽度写死 40/64 |
| 帮助图标 | **22×22 / 24×24** | `SettingsPanel.ets:82-85`、`:664-668` | 带弹窗，属功能控件 |
| 用户名输入框 | **高 40** | `SettingsPanel.ets:77` | 触控目标即使可点区更高，视觉高度仍偏小 |
| EmptyState 按钮 | **minHeight 40** | `Surfaces.ets:72` | — |
| 默认高度按钮（未设 height） | **40** | `Button('编辑')` `ProjectDetailPage.ets:283`、`Button('＋')` `:292`、`Button('✓')` `:311`、`Button('今天')` `EventCalendar.ets:45`、`Button('›')` `:35`、`Button('−')` `ExpenseSummaryPage.ets:110` 等 | 全仓 61 个 Button 中大量未设高度 |
| 日历日期格 | **宽 38.3–44** | `EventCalendar.ets:73-75`（高 48、宽由 `columnsTemplate` 7 等分决定，行宽 = `(W-28-24)/7`，360vp 屏为 44，320vp 屏为 38.3） | 窄屏或大字号下进一步缩小 |
| 图表图例项 | **高 ~37** | `DistributionChart.ets:132-138`（`padding 10` + 12vp 文字） | 可点筛选 |

**StatusPill 单独说明**：`Surfaces.ets:93-102` 的 `StatusPill` **没有 `.onClick`**，不是可点元素；但它挂了 `PressFeedback` 的 `visualEffect/compositingFilter/attributeModifier`——**按下会缩放并点亮，却没有动作**，属“假按压反馈”（假可点暗示）。若后续把它做成可点筛选，其当前高度约 27vp（12vp 文字 + 上下 padding 5+5），仍需先补 44vp。

### 2.8 无障碍：标签覆盖较好，角色/键盘/大字号是短板

| 指标 | 数量 |
|---|---|
| `.onClick(` | 72 |
| `Button(` | 61 |
| `accessibilityText(` | 172 |
| `accessibilityDescription(` | 5 |
| `accessibilityRole(` | **5** |
| `accessibilityGroup(` | 16 |
| `accessibilityLevel('no')` | 18 |
| `.focusable(` | 2 |
| `.onKeyEvent(` | **0** |

- **可点元素缺标签**：基本没有。抽查 27 个非 `Button` 可点节点，绝大多数有 `accessibilityText`；仅 `SettingsPage.ets:147`（版本号连点 5 次进开发者）刻意无标签，可接受。
- **缺角色**：27 个非 `Button` 可点节点里只有 5 处声明 `accessibilityRole(BUTTON)`（`Surfaces.ets:35`、`SettingsChoiceSlider.ets:81`、`DistributionChart.ets:138`、`ExpenseSummaryPage.ets:80/105`）。以下可点节点**有 label 无 role**：`ProjectDetailPage.ets:331`（编辑任务）、`:369`（装备行）、`:426`（团队行）、`:468`（花费行）、`HdsMiniBarButton.ets:60`、`SheetHeader.ets:40`（关闭）、`SettingsPanel.ets:87`、`:670`（帮助图标）。读屏会读成普通文本而不是“按钮”。
- **重复朗读**：设置面板“清除缓存”一行在 4 个层级都设了标签——`Text('清除缓存')`（`SettingsPanel.ets:652`）、值文本（`:661`）、Row group（`:693`）、`HdsListItemCard`（`:643`）；用户名行同样 3 层（`:89-91`、`:649`）。`InteractiveCard` 父节点设 `accessibilityText` 但子 `Text` 未抑制（`Surfaces.ets:34-36`），存在“先读卡片名再逐条读内部文字”的风险。
- **键盘/2in1**：`module.json5` 声明支持 `2in1`，但全仓 `onKeyEvent` 0 处、`focusable` 仅 2 处，`Column` 卡片无法用回车/空格激活（`Surfaces.ets:34` 只 `focusable(true)`，无键盘激活）。
- **系统字体放大风险（已可从截图确认 + 代码定位）**：
  - 截图证据：`docs/validation/settings-phone-large-font-api26.png` 与 `settings-narrow-large-font-api26.png`（ohosTest 布局测试台，`setFontSizeScale(2)`）中，滑块档位“关闭/灵动/硬朗”“流畅/轻柔/精美”在 2× 字号下**每个 2 字标签被拆成单字竖排**（“关/闭”“灵/动”），与滑块刻度错位；同时“清除缓存”行右侧“缓存文件总大小：0 B”被挤出右缘。代码根因：`SettingsChoiceSlider.ets:34` 的 `labelWidth()` 写死 `40/64`、`:72/75` 的 `Text` 未随 fontScale 变化；`SettingsPanel.ets:645-694` 的 `trashContent` 用 `Flex(SpaceBetween)` 且两侧文本都没有 `layoutWeight/flexShrink`。
  - 代码风险点：固定高度 `cardHeight` 52/54/60/68/72/108/116（`SettingsPanel.ets:354/477/597/632`、`SettingsActionRow.ets:24`、`SettingsValueRow.ets:52`、`SettingsPreferenceRow.ets:24`）；固定宽度 190（7 处，滑块列）、76（`Surfaces.ets:113` FactRow 标签）、64/55（`HomePage.ets:74`、`EventsPage.ets:50`）、34（色板）；单行限制 `maxLines(1)` 9 处、`maxLines(2)` 若干；`HdsTitleBarSegment` 允许 `itemMaxFontScale: 2`（`:12`）但外框高固定 52（`:14`）。
  - 结论：**大字号在本应用不是“是否溢出”，而是“哪里折行错位”**；已有两张大字号截图证明滑块档位标签折行错位。
- **减少动效偏好**：全仓 **0 处** 读取 `AccessibilityManager`/动画缩放/`reduceMotion`/`fontScale`；动效只受自定义“材质等级/视觉效果”开关影响（`visualEffects.ets:48`、`STORAGE_KEY_VISUAL_EFFECTS`），不响应系统“减少动效”。

### 2.9 动效与按压反馈：参数集中，但“过量”且不响应系统偏好

- 页面转场 300ms/220ms + 缩放入场（`motion.ets:10-21`）；分组入场 100ms 延迟 + 125ms 步进 + 500ms 弹簧 × 最多 4 组（`motion.ets:26-42`、`constants.ets:22-26`）→ 首屏最后一块内容约 **975ms** 才就位，再叠加 300ms 转场 = **约 1.0–1.3s**。
- 按压反馈：缩放 0.985 + 130ms 弹簧 + 最短 140ms 点光源（`pressFeedback.ets:27/39/51`）。
- **嵌套双反馈**：`PhotoGrid` 的 `InteractiveCard` 内再放 `ManagedImage`（`PhotoGrid.ets:169-176` + `ManagedImage.ets:39-41`），`ReferenceGallery` 的 `Button` 内也放 `ManagedImage`（`ReferenceGallery.ets:43-49`）——一次按压同时触发两层缩放/点光源；`EmptyState` 同样父列 + 子按钮各有一套（`Surfaces.ets:75-85`）。
- **每张卡 4 层视觉节点**：`bg + border + shadow + visualEffect(点光源) + compositingFilter(HDR)`（`Surfaces.ets:27-32`），全仓 116 处 `visualEffect` + 116 处 `compositingFilter`；在照片网格一屏 8 张卡时约 48 个效果绑定。
- 反馈偏好：只读 AppStorage 的 `visualEffectsEnabled` / `lightFieldLevel`（`visualEffects.ets:25-48`），**不读系统动效/无障碍设置**。

### 2.10 主题切换一致性：覆盖了“色”，没覆盖“原生控件”

`Theme.ets:69-82`：非蓝主题通过 `WithTheme` 注入 **10 个 CustomTheme 颜色键**（brand、fontEmphasize、iconEmphasize、iconSubEmphasize、backgroundEmphasize、compBackgroundEmphasize、fontOnPrimary、iconOnPrimary、interactiveFocus、interactiveActive）；**蓝色主题注入 `{}`（保持系统默认）**。

| 原生控件/区域 | 是否随五组主题 | 证据 |
|---|---|---|
| 页面自绘元素（surface/ink/muted/accent…） | ✅ | `ThemePalettes.ets:21-97` |
| HDS 标题栏标题/菜单/返回 | ❌ 钉死系统色 | `SystemCapability.ets:34-35/41-42`：`mainTitleColor: sys.color.font_primary`、`iconColor: sys.color.icon_primary`、菜单底色 `sys.color.comp_background_tertiary` |
| 主底部 Tab 选中色 | ⚠️ 未显式指定 | `Dashboard.ets:656-664`（`BottomTabBarStyle` 无 `labelStyle`），而详情动作栏显式指定了（`HdsActionTabs.ets:30-31`）——两类底栏行为不一致 |
| SegmentButtonV2（TabSegmentButtonV2） | ⚠️ 选中胶囊固定 13% 灰，不随主题；选中文字色未传 | `HdsTitleBarSegment.ets:25/44/45` |
| Slider | ✅ 显式 brand/tint/surface | `SettingsPanel.ets:390-393`、`SettingsChoiceSlider.ets:57-60` |
| Toggle 开关 | ⚠️ 依赖 `nativeTheme` 的 `compBackgroundEmphasize`（已设） | `FormEditor.ets:237/273` |
| Select 下拉菜单 | ❌ 无主题参数，系统弹出菜单样式 | `FormEditor.ets:80/134/144/151/...`、`PhotoGrid.ets:54/90`、`EventsPage.ets:73` |
| DatePickerDialog / TimePickerDialog | ❌ 不在 `WithTheme` 子树、未传 color | `DateField.ets:20-29` |
| AlertDialog（清缓存） | ❌ 未传按钮色 → 系统强调色 | `SettingsPanel.ets:200-240` |
| showDialog（统一 confirm） | ✅ 显式传 `Theme.accent` / `Theme.danger` | `Confirm.ets:12-13` |
| Toast / bindPopup 帮助按钮 | ⚠️ 系统样式 | `safeUi.ets:14`、`SettingsPanel.ets:91/679` |

**两个致命细节**：

1. **蓝色主题下“系统蓝”与“应用蓝”不是同一个蓝**：`Theme.ets:69` 对 blue 注入空主题，系统原生控件使用 HarmonyOS 默认强调色（约 `#0A59F7`），而应用品牌色是 `#1E6FCD`（`base/color.json:13`）——蓝主题反而最容易暴露“两个蓝”。
2. **非蓝主题下原生对话框仍是系统蓝**：`DatePickerDialog`/`AlertDialog` 不在 `WithTheme` 子树（它们由 UIContext 以独立弹窗创建），且未传 `color`。绿/粉/橙/红主题打开日期选择器或“清除缓存”确认框时，确定键/选中项仍是蓝色，与页面 accent 冲突。这与 `Confirm.ets` 已经做对的写法（显式传色）自相矛盾。

### 2.11 强调色/语义色使用统计

| 颜色角色 | 使用次数 | 说明 |
|---|---|---|
| `Theme.muted` | 110 | 次级文字，使用健康 |
| `Theme.accent` | **64**（其中作 `fontColor` **55** 处） | **过度**：链接、次要按钮、状态药丸、分组标题、大数字、图标、图片占位首字全用它 |
| `Theme.tint`（浅色底） | 50 | 次要按钮底色 44 处 → 满屏浅色胶囊 |
| `Theme.brand`（实心主色） | 27 | 真正的实心主按钮仅 **8 处** `onAccent`；其余是进度条/滑块/色板 |
| `Theme.ink` | 54 | 正文，健康 |
| `Theme.danger` | **2**（`SettingsActionRow.ets:21`、`Confirm.ets:13`） | 危险语义只在两处出现；项目内大量“−/删除”按钮用 muted/accent（`ProjectDetailPage.ets:300/336/431/473/524`） |
| `Theme.releaseBadge`（橙） | **1** | 用于“正式版”徽章（`AppLogPage.ets:85-88`）——稳定版用警告橙 |
| `Theme.scrim` | **0**（仅定义） | 死 token |

**强调蓝 `#1E6FCD` 的双身份**：它同时是 `brand`（填充：主按钮/进度/滑块/色板）和 `accent`（文字：链接/药丸/次要按钮/分组标题/大数字/图标）——同一色值既做大面积填充又做小字文字色，是“强调色过载”的结构性原因；`Theme.ets:43/45` 两个字段都指向 `app.color.diff_content`，意味着设计上从未区分“可读的强调文字色”和“可铺的面积填充色”。

**语义色/强调色的实际用途分配**

| token | 浅色 | 深色 | 全仓用途 | 语义问题 |
|---|---|---|---|---|
| `diff_content`（=brand=accent） | `#1E6FCD` | `#4A9CE2` | 填充 27 处 + 文字 64 处 | 一色双身份（见上） |
| `v3_accent_red`（=danger） | `#CF2634` | `#FF8792` | 危险文字 2 处 | 与珊瑚红主题 accent 撞色（1.07:1） |
| `v3_accent_orange`（=releaseBadge） | `#B54708` | `#FFB75E` | 正式版徽章底 1 处 + 图表系列 3 | 警告橙被当“稳定版/装饰” |
| `v3_accent_cyan` | `#007D8A` | `#55C7D3` | 仅图表系列 2 | 无任何语义角色 |
| `v3_accent_green` | `#00875A` | `#52C999` | 仅图表系列 4 | success 语义未使用 |
| `v3_accent_purple` | `#7048E8` | `#B69AFF` | 仅图表系列 5 | 无任何语义角色 |
| `on_accent` | `#FFFFFF` | `#101927` | 按钮字 11 处 | 深色模式从“白字”变“深字”，跨主题极性翻转 |

**语义色被当装饰用的证据**：
- `v3_accent_orange`（`#B54708`）：既当“正式版”徽章底（`AppLogPage.ets:87`），又当环形图第 3 个分类色（`DistributionChart.ets:30-31`）。
- `v3_accent_green`（`#00875A`）/`v3_accent_purple`/`v3_accent_cyan`：只作为图表分类色，**全仓没有 success/info 语义角色**；而“已完成/已购票/已就绪”状态全部用同一个 accent 药丸。
- `v3_accent_red` = `danger`：在**珊瑚红主题**下，`danger`（`#CF2634`）与主题 `accent`（`#B33E50`）对比仅 **1.07:1**、色差 ΔE76=25.4——危险文字与普通强调文字不可区分；`danger` 与主题 `brand`（`#EF8B96`）对比 2.21:1。
- 杏橙主题同理：`warning`（`#B54708`）与主题 `accent`（`#995310`）ΔE76=18.6、对比 1.1:1。

---

## 3. Findings

### P0

#### P0-1 全应用没有排版系统：185 处硬编码字号 / 18 档 / 0 token
- **严重度**：P0（系统性地基）
- **证据**：`.fontSize(` 185 处、18 个字面量 + 1 个动态值（§2.1 分布表）；`Theme.ets:86-105` 只有布局尺寸，无任何 typography 字段；同类角色最多 5 个值（详情标题 19/20/21/23，列表正文 13/14/15/16/17）；`ProjectDetailPage` 单页 28 处、`SettingsPage` 20 处、`FormEditor` 11 处、`Surfaces` 10 处。
- **现象**：字号选择靠手感，13/14/15/16/17 五档都能当正文；同一个“详情页标题”在 4 个页面是 4 个大小；26vp 同时是页面问候（Bold）、统计数字（Regular）、`'›'` 箭头（Regular）；10/11/8vp 小于移动端可读下限。
- **用户影响**：界面“看起来哪里都不太对但说不出”——标题不压场、正文无节奏、小字发虚；大字号下进一步错位（见 P1-6）。这是“UI 有点糟糕”的第一来源。
- **修法**：按 §2.1 的 7 级 scale 落 token（`Theme.fontDisplay/fontTitle/fontHeading/fontSubheading/fontBody/fontLabel/fontCaption` + 3 个 `lineHeight` + overline 变体），按 T1–T7 最小清单替换；同时删除 8/10/11 三档。
- **成本**：M（加 token 与改公共服务 S，全量替换 M）

#### P0-2 浅色+深色都没有可读的“容器边界”：卡片/输入框/描边对比度 1.05–1.90:1
- **严重度**：P0（层级完全丢失，直接对应“糊成一片”）
- **证据**：浅色 `surface #FFFFFF` vs `bg #F6F9FF` = **1.05:1**；卡片描边 `line #D8E4F2` vs surface = **1.29:1**；输入框填充用 `Theme.bg`（`Surfaces.ets:145/156`）在 surface 上 = **1.05:1**；设置页输入框用 `Theme.tint`（`SettingsPanel.ets:72`）= 1.10:1；深色 `surface #182231` vs `bg #1A2B3C` = **1.11:1** 且方向反了；全局 12 组主题的描边/分割/层次全部 <3:1（§2.5 表）。
- **现象**：白卡叠在近白背景上、浅灰描边、10% alpha 阴影；深色下卡片比页面更暗（“凹陷”）。截图 `.shots/93-light-restored.jpeg` 与 `.shots/90-dark.jpeg` 中卡片边界只能靠阴影隐约分辨；`theme-palettes-api26.png`（控件参考页）浅色五列几乎看不到卡片轮廓。
- **用户影响**：扫读时无法区分“一屏有几组内容、哪块可点”；输入框看起来像普通文本块；深色模式显得“闷、塌”，不像原生应用。
- **修法**：
  1. 新增 `border_control`（3:1，仅用于控件）：浅色蓝 `#5D97DB`、绿 `#5CA287`、粉 `#CF7C9A`、橙 `#BB8C5F`、红 `#CC7E8A`；深色蓝 `#738395`、绿 `#749388`、粉 `#997D8C`、橙 `#948371`、红 `#9B7F84`。
  2. 新增 `border_subtle`（装饰卡边，1.5:1）：蓝 `#C8D4E1`、绿 `#BBD9CB`、粉 `#ECC7D5`、橙 `#E3CEB7`、红 `#EBC8CB`。
  3. 所有输入类控件改为 **surface 底 + 1vp `border_control`**（不再用 bg/tint 当输入面）。
  4. 深色 `surface` 提亮到高于 `bg`：蓝 `#233A50`、绿 `#284740`、粉 `#4B3444`、橙 `#483A2C`、红 `#4C363A`（对 bg 1.22–1.25:1，色相不变）。
  5. 阴影改为两级：`elevation1 = 0x1F0B1A33 / r10 / y2`、`elevation2 = 0x2E0B1A33 / r20 / y6`；深色不再用 40% 黑阴影，改由 surface 明度表达层级。
- **成本**：M（资源值 + Theme token + `Surfaces/Field/SettingsPanel` 三处输入面改造）

### P1

#### P1-1 同一“主按钮”在五组主题里一半白字一半黑字，且四组主按钮填充 <3:1
- **严重度**：P1
- **证据**：`theme_colors.json` 浅色 `onAccent`：蓝 `#FFFFFF`（`base/color.json:53`）vs 绿 `#10382A`/粉 `#522135`/橙 `#4B301A`/红 `#4D242D`（`base/theme_colors.json:33/81/129/177`）；对应 `brand` 是 `#58C89B/#F391B5/#F2B16E/#EF8B96`（`:37/85/133/181`）。按钮字对比 4.99/6.26/5.85/6.50/5.48 都达标，但 `brand` 填充对白卡只有 4.99/**2.07/2.20/1.86/2.39**（§2.5）。深色又反过来：`brand` 变亮（`#83DBB2` 等），文字变深。
- **现象**：蓝色主按钮是“深蓝底白字”，绿/粉/橙/红是“浅粉底黑字”；次级按钮 `tint` 底（44 处）与主按钮在浅色主题里同为浅色，主次对比消失（`theme-palettes-api26.png` 五列“继续准备”按钮可直接看到：蓝色白字、其余黑字）。
- **用户影响**：换主题后“最重要的按钮”变了一个物种；主操作不再突出，用户需要读字才能分清主次。
- **修法**：拆分两个 token——
  - `brandSolid`（实心 CTA，必须满足 `onBrandSolid` ≥4.5:1 且对 surface ≥3:1）：浅色直接用现有 `accent` 值 `#1E6FCD/#167A54/#B63866/#995310/#B33E50` + `onBrandSolid #FFFFFF`（对 surface 4.99–5.83:1，文字 5.0–5.8:1）；深色 `brandSolid` = 现深色 `brand`，`onBrandSolid` = 现深色 `onAccent`（6.0–7.8:1）。
  - `brand`（仅装饰性填充：进度条/滑块/高亮）保留浅色值，但若用于“状态填充”需提到 ≥3:1（绿 `#46A07C`、粉 `#CF7B9A`、橙 `#B68552`、红 `#CB7680`）。
- **成本**：M（改 5 组资源 + `Theme` 增加 brandSolid/onBrandSolid + 替换 8 处主按钮和 4 处进度/滑块）

#### P1-2 深色主题层级反转 + 深色阴影无效 + help 图标缺深色版
- **严重度**：P1
- **证据**：`dark/color.json:5/21/25`（bg `#1A2B3C` > surface `#182231` > tint `#101927`）；五组深色 palette 同样（`dark/theme_colors.json:7-9/55-57/103-105/151-153`）；`dark/color.json:45` 阴影 `#66000000`（40% 黑）；`question.png` 仅存在于 `base/media`（`dark/media` 20 个文件不含它，`SettingsPanel.ets:82/664` 使用），平均色 `#676767` 在深色 surface 上 **2.83:1**。
- **现象**：深色下卡片是“洞”，页面背景反而最亮；阴影看不见；设置页右上角帮助“?”比其他图标明显发灰（`.shots/90-dark.jpeg` 可见）。截图 `.shots/90-dark.jpeg`、`.shots/91-dark-restart.jpeg` 与代码计算一致。
- **用户影响**：深色模式覆盖全部五组配色，但看起来“比浅色还平”，且帮助入口在深色下更难被看到。
- **修法**：深色 `surface` 提亮（同 P0-2 第 4 条）；`shadow` 深色改为 `#33000000` 并降低使用频率；补 `dark/media/question.png`（重绘为 `#FBFBFB`，与其余图标一致）。
- **成本**：S（资源值 + 1 个图标）

#### P1-3 状态没有语义色：7+ 种状态同一款药丸，且危险/警告色与两组主题撞色
- **严重度**：P1
- **证据**：`StatusPill` 只有 `label` 一个参数（`Surfaces.ets:90-103`），7 个调用点全部 accent-on-tint（`ProjectCard.ets:42`、`AssetDetailPage.ets:38`、`EventDetailPage.ets:78`、`ProjectDetailPage.ets:133`、`HomePage.ets:80`、`LibraryPage.ets:61`、`EventsPage.ets:56`）；项目 9 种状态、装备 6 种状态、照片 8 种状态共用同一视觉。`danger #CF2634` vs 红主题 accent `#B33E50` 对比 **1.07:1**；`warning #B54708` vs 橙主题 accent `#995310` 对比 ~1.1:1（计算 ΔE76 25.4 / 18.6）。
- **现象**：“准备中/已完成/待维修/已借出/想买/已结束/日期待定”长得完全一样；在红/橙主题里，“清空本地数据”的红与普通强调色几乎无法区分。
- **用户影响**：状态只能逐字读，列表扫读效率低；高风险操作缺少视觉预警（危险色被主题色淹没）。
- **修法**：`StatusPill` 增加 `tone: 'neutral'|'info'|'success'|'warning'|'danger'`，映射到新增 `status*` token（文字色 + 10% tint 底，均已算过 4.5:1）：
  - info `#1D6BC5` on `#E8F1FA`（4.64）；success `#007B52` on `#E6F3EE`（4.66）；warning `#B54708` on `#F8EDE6`（4.72）；danger `#CB2533` on `#FAE9EB`（4.65）；neutral `#5F6B7A` on `#EFF0F2`（4.76）。
  - 状态映射：IDEA/ARCHIVED/日期待定→neutral；PLANNING/PREPARING/待修→info；READY/已购票/可用→success；EVENT/SHOOTING/已借出→warning 或 info；COMPLETED/已发布/成片→success；逾期/已结束→neutral；清空/删除→danger + 图标 + 文案（不单靠颜色，WCAG 1.4.1）。
  - 红主题的 `accent` 建议压深为 `#8F3145`（对白 7.8:1，与 danger `#CF2634` 明度差 1.48:1），橙主题 accent 压深为 `#7A4A12`（对白 7.46:1）。
- **成本**：M

#### P1-4 图标四套体系混用 + 41 处文字符号当图标
- **严重度**：P1
- **证据**：`Icons.ets` 同文件混用 `sys.media`（11）、`sys.symbol`（4）、`app.media`（21）三源（`:13-58`）；全仓 41 处文字符号（§2.6 清单，`ProjectDetailPage` 一页 17 处）；图标尺寸 14/16/18/20/22/24/26 共 7 档；底栏图标语义错位（`Icons.ets:13-17`，截图可证）；11 个自绘 SVG 零引用且写死 `#598C72`。
- **现象**：同屏出现“线性 PNG 图标 + 字体符号 `＋/−/✓/○` + 文本箭头 `›` + 系统矢量符号”；`＋` 在 20 处出现，字重、基线与真图标不一致（按钮内 `＋` 会随字号/字重变化）；收藏用 `★/☆`、选中态用“✓ 已选/○ 点选”纯文字（`PhotoGrid.ets:135`）。
- **用户影响**：界面显得“拼装感”，用户对“这排图标哪些能点”判断不稳；照片多选没有可识别的勾选控件。
- **修法**：统一为一套线性图标（建议启用已有 SVG 资产但把 `stroke` 从 `#598C72` 改为 `Theme.ink`/`Theme.muted` 的 currentColor 方案，或全部换 `sys.symbol` 线性符号），新增 `iconSm(16)/iconMd(20)/iconLg(24)` 三个 token；`＋/−/✓/○/›/★` 全部替换为 `Icons.add/remove/check/pending/chevronRight/star`；选中态改为 `Checkbox` 或图标；8vp 的 `●` 改为 6vp 圆点组件。
- **成本**：M

#### P1-5 触控目标系统性偏小（12 类 / 20+ 处 <44vp）
- **严重度**：P1
- **证据**：§2.7 表：Sheet 关闭 36×36（`SheetHeader.ets:35-38`）、色板 34 宽（`ThemeColorPicker.ets:36`）、设置行按钮 36（`SettingsValueRow.ets:35`）、收藏 36（`CharacterDetailPage.ets:55`）、帮助图标 22/24（`SettingsPanel.ets:84/666`）、EmptyState 按钮 40（`Surfaces.ets:72`）、默认 Button 40（61 个 Button 中大量未设高）、日历格 38.3（`EventCalendar.ets:73-84`）、滑块档位标签 40×17（`SettingsChoiceSlider.ets:72/75`）。
- **现象**：用户需要“瞄着点”；色板 5 个 34vp 靶子相邻仅 4vp；折叠屏/窄屏（<340vp）日历格进一步收缩到 38vp。
- **用户影响**：误触率上升（尤其单手、走动、戴手套的漫展场景——正是本应用的使用场景）；老年人/手抖用户更难。
- **修法**：新增 `touchMin = 44`（HOS 建议 48，可先 44）；Sheet 关闭 36→44、色板 34→44（或 Row 宽 190→220，间距 8）、设置行按钮 36→44、帮助图标外扩 `hitTestBehavior` 至 44×44、默认按钮统一 `.constraintSize({minHeight:44})`、日历格在窄屏降到 6 列或增大行高、滑块档位标签改为整列 44 高可点。
- **成本**：M

#### P1-6 系统大字号：固定宽/高 + 单行限制，已在截图中折行错位
- **严重度**：P1
- **证据**：大字号截图 `docs/validation/settings-phone-large-font-api26.png`、`settings-narrow-large-font-api26.png`（2 字标签拆成单字竖排、与刻度错位）；根因 `SettingsChoiceSlider.ets:34/72/75`（写死 40/64 宽）、`SettingsPanel.ets:449/577`（`width(40)` 档位标签）、固定 `cardHeight` 52–116（§2.8 清单）、`maxLines(1)` 9 处（如 `SettingsValueRow.ets:21/28`）、`Surfaces.ets:113` FactRow 标签固定 76 宽、`HdsTitleBarSegment` 固定 52 高。
- **现象**：2× 字号（布局测试台 `SettingsLayout.ets:71`）下档位文字竖排拆字、行内右侧文本被裁；固定高行内文字溢出/挤出行（`SettingsValueRow` 60/72 高塞 16+12+12vp 文本，2× 时约 32+24+24vp）。
- **用户影响**：系统无障碍大字是本应用目标用户（二次元人群、年轻用户）常用的设置之一；一旦开启，设置页和详情页的密集行会错位，属“看起来坏掉”。
- **修法**：几何 token 全部随 `fontScale` 派生——档位标签宽度 = `40 * fontScale`（或改为自适应 `layoutWeight`）；固定 `cardHeight` 改 `constraintSize({minHeight})`；`maxLines(1)` 只用于可省略的次要值并保留 `textOverflow`；关键行改用 `Flex wrap`（`SettingsPreferenceRow` 已有此模式，可复用）；给根容器 `maxFontScale(2)` 保持可控。
- **成本**：M

#### P1-7 几何无 token：11 种圆角 / 15 种 padding / 13 种 gap / 7 种卡片层级
- **严重度**：P1
- **证据**：§2.2/2.3/2.4 全部统计；尤其 `ProjectDetailPage.ets:381/441/483/535`（18/16/16/20 同级行）、`MePage.ets:100` 与 `Surfaces.ets:15`（同组件 padding 20 vs 14）、`SettingsPage.ets:207/241/259` 用硬编码 16 而非 `Theme.cardRadius`。
- **现象**：卡片内边距 14/16/18/20/24 五种；页面 gutter 14、分组间距 14 不在 4 网格；同一语义的“列表行”圆角 4 种。
- **用户影响**：页面对齐看起来“差 2vp”，整体不精致；跨页面不一致积累成廉价感。
- **修法**：§4 的 Spacing（4/8/12/16/24/32）与 Radius（8/12/16/full + 内媒体 12）token；`pagePadding=16`、`sectionSpacing=16`、`cardPadding=16`；规定层级映射：卡片 16 / 卡内媒体 12 / 输入 12 / 药丸 full / 徽章 8。
- **成本**：M

#### P1-8 强调色过载与主次倒置
- **严重度**：P1
- **证据**：§2.11：`accent` 作文字 55 处、`tint` 底按钮 44 处、`brand` 实心按钮 8 处；`accent` 同时用于分组标题（`SettingsPage.ets:76`）、大数字（`ExpenseSummaryPage.ets:139`、`MePage.ets:53-64`）、图标（`TaskLinkCard.ets:17`、`EventCalendar.ets:69`）、图片占位首字（`ProjectCard.ets:32`、`CosPage.ets:58`）、箭头（`HomePage.ets:110`）。
- **现象**：一屏里 accent 出现 6–10 次（ProjectDetailPage 一页 14 处 `fontColor(Theme.accent)`），“强调”失去层级意义；次要按钮（浅底 accent 字）数量是主按钮的 5.5 倍。
- **用户影响**：用户无法用颜色判断“哪里是主操作、哪里只是信息”；界面像“全部加粗的文档”。
- **修法**：规定颜色分配——`ink` 主文字、`muted` 次文字、`accent` 仅用于 **链接/选中态/可点文字按钮**（≤ 每屏 3 处）；大数字改 `ink` 或 `brandSolid`；分组标题改 overline muted；图标改 `ink/muted`；主按钮 `brandSolid`、次按钮 `surface+border_control`（不用 tint 底），或把 tint 次按钮限制在“成对操作”（Sheet 底部、空态）。
- **成本**：M

#### P1-9 主题切换只覆盖“色”，不覆盖原生控件与标题栏
- **严重度**：P1
- **证据**：§2.10 表（`Theme.ets:69-82` 仅 10 键；`SystemCapability.ets:34-35` 钉死 `sys.color.*`；`Dashboard.ets:656-664` 底栏无 labelStyle；`DateField.ets:20-29`、`SettingsPanel.ets:200-240` 未传色；蓝主题 `nativeTheme={}` 与 `#1E6FCD` 不是同一个蓝）。
- **现象**：绿/粉/橙/红主题下，日期选择器/清缓存确认框/下拉菜单/部分底栏选中态仍是 HarmonyOS 蓝；标题栏文字是系统中性色不是主题 ink；蓝色主题反而出现“两个蓝”。
- **用户影响**：主题切换“只换了一半”，用户会觉得配色方案不专业、像是主题器没做好——这正是“UI 糟糕”的典型观感来源。
- **修法**：① 对 blue 也注入 nativeTheme（brand=`#1E6FCD`），不再依赖系统蓝；② `SystemCapability.titleBar` 的 title/icon/menu 色改为 `Theme.ink`/`Theme.muted`/`Theme.tint`（HDS titleBar 接受 ResourceColor）；③ `DatePickerDialog/TimePickerDialog/showAlertDialog` 全部走统一封装并显式传 `Theme.accent/Theme.danger`（参照 `Confirm.ets`）；④ 主底栏 `BottomTabBarStyle` 显式 `labelStyle({selectedColor: Theme.accent, unselectedColor: Theme.muted})`，与 `HdsActionTabs.ets:30-31` 对齐；⑤ Select 的弹层无法主题化时，把筛选统一改成 `HdsTitleBarSegment`/chip 组（已主题化）。
- **成本**：M–L（①–④ S，⑤ 视筛选数量 M）

### P2

#### P2-1 分段控件选中态几乎不可见
- **严重度**：P2
- **证据**：`segmented_color_selected` `#22666666`/`#22FFFFFF`（`base/color.json:9`/`dark/color.json:9`），合成后对白卡 1.19:1、对深卡 1.51:1；选中文字色未传（`HdsTitleBarSegment.ets:44`）。
- **现象**：“作品/时间轴”“准备/打包/照片”当前选中项只靠 13% 半透明灰胶囊区分。
- **用户影响**：用户不确定自己在哪个分段（尤其浅色主题/低亮度屏）。
- **修法**：显式设置选中文字色为 `Theme.accent`（对 surface 4.99–5.83:1），胶囊底色改用 `Theme.tint` + 1vp `border_control`；或选中项改 `Theme.ink` 加粗（非仅颜色）。
- **成本**：S

#### P2-2 分组标题有 3–4 套写法
- **严重度**：P2
- **证据**：`SectionHeading` 15 Medium muted + 12 trailing（`Surfaces.ets:47-48`）；`SettingsPage.groupTitle` 14 Bold **accent**（`:73-78`）；帮助 Sheet 16 Medium ink（`:91/93/105/108/110/112`）；图表标题 18 Bold ink（`DistributionChart.ets:110`）。同一设置页内分割线还有两档：`Theme.divider`（`SettingsPage.ets:71`，页面级）与 `Theme.groupDivider`（`:72`，卡片内 action rows）。
- **现象**：设置页的分组标题是**蓝色加粗**，其它页是灰色常规；“帮助/数据与备份/设置”看起来像链接而不是标题（截图 `102-settings-light-icons.jpeg`、`80-mist.jpeg`、`.shots/90-dark.jpeg` 可证）。
- **用户影响**：分组层级不统一，设置页显得比其它页“重”。
- **修法**：所有分组标题统一 overline：`12 Medium` + `Theme.muted` + `letterSpacing 0.3`；分割线统一 `divider`（0.5vp）；删掉 accent 分组标题。
- **成本**：S

#### P2-3 卡片层级 7 种处理，border+shadow 叠层过度
- **严重度**：P2
- **证据**：§2.4 表。`InteractiveCard` 同节点叠 `border + shadow + visualEffect + compositingFilter`（`Surfaces.ets:27-32`）。
- **现象**：同类容器在不同页面用不同组合（有 border 无 shadow / 有 shadow 无 border / 都没有），阴影 10%（浅）与 40% 黑（深）两个极端。
- **用户影响**：卡片“轻/重”不一致，跨页跳转时层级感断掉；低端机上多层特效可能掉帧。
- **修法**：收敛为 3 级：L0 页面（bg）/ L1 卡片（surface + `border_subtle`）/ L2 浮动与可点卡（surface + `elevation2`）；`EmptyState`、详情行、设置卡全部归为 L1；点光源只保留在 L2 可点卡上，且去掉 HDR filter 作为默认。
- **成本**：M

#### P2-4 动效不响应“减少动效”，且入场叠加约 1 秒
- **严重度**：P2
- **证据**：§2.9；无任何 `AccessibilityManager`/reduceMotion 读取（全仓 grep 为 0）；`motion.ets:26-42` + `constants.ets:24-26`；嵌套双按压 `PhotoGrid.ets:169-176`+`ManagedImage.ets:39-41`、`ReferenceGallery.ets:43-49`。
- **现象**：页面进入时“转场 300ms + 4 组错峰 975ms”同时进行；一次点按照片触发两层缩放和两个点光源；开启系统“减少动效”无效。
- **用户影响**：前庭敏感用户/低端机会觉得晃；每次进入页面都要等近 1 秒内容才齐。
- **修法**：读 `AccessibilityManager.isAnimationEnabled`（或系统 animationScale）为 0 时直接 `step=groups`、转场改 `TransitionEffect.OPACITY`；把 stagger 默认组数从 4 降到 2、间隔 60ms；去掉嵌套按压（子 `ManagedImage` 在可点卡内时禁用自身反馈）。
- **成本**：S

#### P2-5 图表配色与语义色混用，浅色下首系列最“轻”
- **严重度**：P2
- **证据**：`DistributionChart.ets:29-32` 分类色 = `[Theme.brand, v3_accent_cyan, v3_accent_orange, v3_accent_green, v3_accent_purple, Theme.muted]`；浅色四组 `Theme.brand` 对白卡 1.86–2.39:1，而 cyan/orange/green/purple 是 4.55–5.55:1 → **第一大分类反而最看不清**；`AppLogPage.ets:87` 又用 orange 当“正式版”徽章；浅/深色下同一图表权重反转（深色 brand 5.45–8.79:1）。
- **现象**：环形图/图例的主色在浅色主题下像“禁用色”；橙色既表示“正式版”又表示第 3 类照片状态。
- **用户影响**：数据可读性差，语义混淆。
- **修法**：新增固定 6 色 `chart_series_1..6`，按明度阶梯设计（浅色 4.5–5.5:1、深色 6–9:1），与 brand/semantic 解耦；第一系列用 accent 而非浅 brand。
- **成本**：S

#### P2-6 读屏：非按钮元素缺 role，父子重复朗读，2in1 无键盘激活
- **严重度**：P2
- **证据**：§2.8；`accessibilityRole` 仅 5 处；`onKeyEvent` 0；`SettingsPanel.ets:640/652/661/693` 四层标签；`Focusable` 仅 `Surfaces.ets:34` 与 `DistributionChart.ets:134`。
- **现象**：可点 `Column/Image/Stack` 被读成普通文本；清缓存行被重复朗读 3–4 次；键盘用户无法激活卡片。
- **用户影响**：视障用户操作效率低、误触；2in1 用户必须用鼠标。
- **修法**：给 27 个非 Button 可点节点补 `accessibilityRole(BUTTON)`；父子只保留一层 `accessibilityText`（父级加 `accessibilityGroup(true)`，子级 `accessibilityLevel('no')`）；卡片上加 `onKeyEvent`（Enter/Space 触发 action）。
- **成本**：S

#### P2-7 宽屏策略不统一（1440 / 840 / 无上限；仅 3 页分栏）
- **严重度**：P2
- **证据**：`LAYOUT_CONTENT_MAX_WIDTH=1440`（`constants.ets:146`）、`READING_MAX_WIDTH=840`（`:106`）；内容页用 1440（`HomePage.ets:261` 等 13 处），阅读页用 840（`LocalHtmlPage.ets:70`、`ExpenseSummaryPage.ets:155`、`DevPage.ets:133`、`AppLogPage.ets:121`）；**`SettingsPage` 窄屏分支无 maxWidth**（`:331` 仅 padding）；仅 Home/Me/Settings 用 `DashboardSplitLayout`（`SettingsPage.ets:309-319`、`HomePage.ets:245-253`），Cos/Events/Library/详情页不分栏。
- **现象**：800vp 平板或折叠屏展开时，设置页列表拉满全宽；同样的宽屏，Home 是 4:6 分栏、Cos 是全宽单列。
- **用户影响**：平板/2in1 用户体验参差，行宽过长难读。
- **修法**：统一三档（手机单列 / ≥600 双列或分栏 / 阅读页 840）+ 一处 `PageScaffold` 组件承载 maxWidth、padding、topInset、入场动画；SettingsPage 窄屏加 `maxWidth(720)`。
- **成本**：M

#### P2-8 Token 命名与死资源：语义映射混乱，存在未用 token/资源
- **严重度**：P2
- **证据**：`Theme.brand = $r('app.color.diff_content')`（`Theme.ets:43/45`，`diff_content` 是 Dashboard 差异视图遗留名）；`Theme.line = nd_card_border`、`Theme.divider = border`、`Theme.groupDivider = v3_chart_grid`（`:39-41`，图表网格色当分割线）；`Theme.scrim` 0 使用；`page_text_font_size: 50fp` 未使用（`base/element/float.json:3-5`）；11 个 SVG 未使用；`start_window_background` 浅色 `#FFFFFF` vs bg `#F6F9FF`、深色 `#0F1A2A` vs bg `#1A2B3C`（`base/color.json:48-49`、`dark/color.json:48-49`）；`theme_*_shadow` 深色 5 组同为 `#66000000`。
- **现象**：改一个品牌色要去改一个叫 `diff_content` 的键；图表网格色同时是分割线色；启动页与首页底色不一致（冷启动闪一下色差）。
- **用户影响**：可维护性差、主题扩展易漏；冷启动闪色影响“专业感”。
- **修法**：资源命名规范化为 `brand / accent / ink / muted / surface / surfaceRaised / surfaceSunken / tint / line / borderControl / divider / onAccent / danger / warning / success / info / focus / shadow / scrim / segmentedBg / segmentedFg`；`start_window_background` 取各主题 bg；删除未用 token/float/SVG（或修复后启用）。
- **成本**：M（纯重构，风险低）

#### P2-9 顶部安全区三套常量各自维护，标题栏与内容叠压
- **严重度**：P2
- **证据**：`LAYOUT_CONTENT_TOP=100`、`LAYOUT_DETAIL_TOP=90`、`LAYOUT_DETAIL_TOP_WITH_SEGMENT=112`（`constants.ets:134-136`），与 HDS 标题栏实际高度（状态栏 + 标题区）无推导关系；标题栏背景透明（`SystemCapability.ets:32/39`），内容滚动时会透过材质显示（截图 `102-settings-light-icons.jpeg`、`81-sky.jpeg` 顶部卡片与标题栏叠压）。
- **现象**：不同页面首屏留白 90/100/112 三种；滚动时标题栏下的内容与标题互相干扰。
- **用户影响**：首屏留白不一致；滚动时标题与卡片重叠，读起来乱。
- **修法**：用一个 `PageScaffold` 从 `HdsNavigation` 实际标题栏高度 + 安全区推导 topInset；标题栏在滚动时加不透明度/模糊遮罩，避免与正文叠字。
- **成本**：M

#### P2-10 空态/设置/详情三处的“小控件”样式各写一遍
- **严重度**：P2
- **证据**：设置页滑块档位标签两套实现——可点（`SettingsChoiceSlider.ets:79`）与不可点（`SettingsPanel.ets:449/577`），外观相同；档位标签用 `SpaceBetween` 分布在固定 190 宽轨道上，标签中心与滑轨端点/刻度不重合（`SettingsChoiceSlider.ets:30/34/86-88`）；空态按钮 40 高（`Surfaces.ets:72`）vs 主按钮默认 40/48/52/56（`ProjectDetailPage.ets:108`、`FormEditor.ets:347`、`Dashboard.ets:374`、`EventDetailPage.ets:43`）无规范。
- **现象**：看起来一样的档位文字，有的能点有的不能；按钮高度 40/48/52/56 四档。
- **用户影响**：可点性不可预测，误以为不能点。
- **修法**：档位标签统一用 `SettingsChoiceSlider` 一份实现；按钮高度规范为 `controlSm=40 / controlMd=48 / controlLg=56` 三档 token。
- **成本**：S

---

## 4. 建议新增的设计令牌清单（可直接落到 `Theme.ets`）

> 原则：**颜色**继续用 Resource 以保持深浅色自动切换；**字号/间距/圆角/层级**用 number 常量（本轮不需要随主题变化）；每个 token 都给出映射与验收阈值。

```ts
// ── Typography（新增）────────────────────────────────────────────
readonly fontDisplay: number = 32;        // Lighter · 行高 40 · 展示数字
readonly fontTitle: number = 24;          // Bold    · 行高 32 · 页面主标题/统计大数
readonly fontHeading: number = 19;        // Medium  · 行高 26 · 详情标题/Sheet/图表标题
readonly fontSubheading: number = 16;     // Medium  · 行高 22 · 卡片标题/设置行
readonly fontBody: number = 14;           // Regular · 行高 21 · 正文/值/按钮
readonly fontLabel: number = 13;          // Regular · 行高 19 · 表单标签/次级正文
readonly fontCaption: number = 12;        // Regular · 行高 17 · 元信息/药丸/说明
readonly lineHeightBody: number = 21;
readonly lineHeightHeading: number = 26;
readonly lineHeightCaption: number = 17;
readonly overlineTracking: number = 0.3;  // 分组标题：fontCaption + Medium + tracking

// ── Spacing（4vp 网格；替换现有的 14/14/4 三个 LAYOUT_*）──────────
readonly space1: number = 4;
readonly space2: number = 8;
readonly space3: number = 12;
readonly space4: number = 16;
readonly space6: number = 24;
readonly space8: number = 32;
readonly pagePadding: number = 16;        // 原 LAYOUT_PAGE_PADDING 14
readonly sectionSpacing: number = 16;     // 原 LAYOUT_SECTION_SPACING 14
readonly sectionContentGap: number = 8;
readonly cardPadding: number = 16;        // 原 14/18/20 混用
readonly listRowPaddingH: number = 16;

// ── Radius（4 档 + 内媒体派生）────────────────────────────────────
readonly radiusSm: number = 8;            // 徽章/chip
readonly radiusMd: number = 12;           // 输入/卡内媒体/图例
readonly radiusLg: number = 16;           // 卡片/面板（= 原 cardRadius）
readonly radiusFull: number = 999;        // 药丸/头像/图标按钮
// 卡内媒体 = radiusLg - space1 = 12，禁止再写 14

// ── Elevation（替代 11 处 shadow + 8 处 border 的随机组合）────────
readonly elevation1Radius: number = 10;
readonly elevation1OffsetY: number = 2;
readonly elevation1Color: string = '#1F0B1A33';
readonly elevation2Radius: number = 20;
readonly elevation2OffsetY: number = 6;
readonly elevation2Color: string = '#2E0B1A33';
// 深色不用黑阴影表达层级，用 surface 明度（见下）

// ── Touch / Icon ────────────────────────────────────────────────
readonly touchMin: number = 44;           // 48 为 HOS 推荐，先 44
readonly iconSm: number = 16;
readonly iconMd: number = 20;
readonly iconLg: number = 24;

// ── Color 语义扩展（每个 palette 从 12 键扩到 18 键）──────────────
// 现有：bg / surface / ink / muted / line / divider / groupDivider /
//       onAccent / brand / accent / tint / shadow
// 新增：
//   borderSubtle   装饰卡边（1.5:1）
//   borderControl  控件/输入边界（3:1）
//   surfaceRaised  浮起面（深色用于修正层级方向）
//   surfaceSunken  凹陷面（输入框内底）
//   brandSolid     实心主按钮底色（onBrandSolid ≥4.5:1）
//   onBrandSolid   主按钮文字
//   statusInfo/statusSuccess/statusWarning/statusDanger（文字 + 10% tint 底成对）
//   segmentedBg / segmentedFg
//   focus          焦点环
//   scrim          遮罩（启用现有 v3_scrim）
```

**建议色值（保持色相；均已按 WCAG 计算）**

| 新 token | 蓝 | 绿 | 粉 | 橙 | 红 |
|---|---|---|---|---|---|
| `border_subtle`（浅，1.5:1 vs surface） | `#C8D4E1` | `#BBD9CB` | `#ECC7D5` | `#E3CEB7` | `#EBC8CB` |
| `border_control`（浅，3:1 vs surface） | `#5D97DB` | `#5CA287` | `#CF7C9A` | `#BB8C5F` | `#CC7E8A` |
| `brandSolid`（浅，对 white 4.99–5.83:1） | `#1E6FCD` | `#167A54` | `#B63866` | `#995310` | `#B33E50` |
| `onBrandSolid`（浅） | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` |
| `surface`（深，提亮后 vs bg 1.22–1.25:1） | `#233A50` | `#284740` | `#4B3444` | `#483A2C` | `#4C363A` |
| `border_control`（深，3:1 vs 新 surface） | `#738395` | `#749388` | `#997D8C` | `#948371` | `#9B7F84` |

状态色（跨主题固定，不随五组 palette 改变；tint = 文字色 10% 叠白，深色 12% 叠 surface）：

| tone | 浅色文字 / 底色 | 对比 | 深色文字 / 底色 | 对比 |
|---|---|---|---|---|
| info | `#1D6BC5` / `#E8F1FA` | 4.64 | `#4A9CE2` / `#20364D` | 4.21 → tint 降到 10% 或文字提亮至 4.6 |
| success | `#007B52` / `#E6F3EE` | 4.66 | `#52C999` / `#213D42` | 5.62 |
| warning | `#B54708` / `#F8EDE6` | 4.72 | `#FFB75E` / `#3D3A38` | 6.55 |
| danger | `#CB2533` / `#FAE9EB` | 4.65 | `#FF8792` / `#3D3241` | 5.28 |
| neutral | `#5F6B7A` / `#EFF0F2` | 4.76 | `#A8B4C3` / `#2F3948` | 5.55 |

**Theme.ets 改造结构建议**：把 `ThemeTokens` 拆成 `@ObservedV2 ColorTokens`（Resource，随主题变）+ `export const Type/Spacing/Radius/Elevation`（number，常量），避免每个组件都从 `@ObservedV2` 对象读常量造成不必要的依赖追踪。

---

## 5. 值得保留的优点

1. **颜色 100% 资源化**：全仓 `.ets` 内 **0 个十六进制颜色字面量**（已 grep 验证），五组 × 浅深各 68 个色值全部在 `resources/{base,dark}/element/*.json`，切换主题零重绘逻辑。
2. **文字对比度达标**：正文 11.6–16.3:1、次级 4.51–8.97:1、按钮字 4.99–7.83:1、危险 5.28–6.96:1；五主题 × 浅深 10 套全部 ≥4.5:1，只差 3 个临界项微调。
3. **主题架构方向正确**：`ThemePalettes.ets` 单一解析入口 + 同键名资源 + `WithTheme(nativeTheme)` 覆盖原生控件；蓝主题保留系统默认的降级策略（虽需按 P1-9 调整为显式注入）。
4. **公共组件雏形已存在**：`InteractiveCard/SectionHeading/EmptyState/StatusPill/FactRow/Field`（`Surfaces.ets`）已经把最常用模式收口，改造 token 时只需改这 6 个组件即可覆盖大部分页面。
5. **大数字用 Lighter 的设计意图清晰**：32/32/32/25 四处 `FontWeight.Lighter`（`HomePage.ets:65`、`EventsPage.ets:48`、`ProjectCard.ets:30/59`）已经形成“展示数字”母题，值得固化为 `fontDisplay` 而非丢弃。
6. **按压反馈/动效参数集中**：`pressFeedback.ets`、`visualEffects.ets`、`motion.ets` + `constants` 统一收敛（130ms、300ms、500ms 等），没有散落魔法数；材质/光场开关集中在 `visualEffectsEnabled`。
7. **无障碍标签覆盖率高于同类项目**：172 个 `accessibilityText` / 72 个可点节点，装饰图标 18 处 `accessibilityLevel('no')`，`InteractiveCard` 已带 role/label/description（`Surfaces.ets:34-36`）。
8. **HDS 外壳与宽屏意识**：HdsNavigation/HdsTabs 材质、浮动栏、`contentMaxWidth 1440`、`READING_MAX_WIDTH 840`、Home/Me/Settings 已实现 4:6 分栏——宽屏不是从零开始，只差统一。
9. **深浅两套图标资产**：`dark/media` 已为 20 个设置类图标提供深色版（`#FBFBFB`），仅 `question.png` 缺版，补齐即完整。
10. **设置项有“窄屏/大字号”布局意识**：`SettingsPreferenceRow` 的 `Flex wrap` + `contentWidth < 330` 换行分支（`:14-20`）是正确方向，应推广到所有行。

---

## 6. 整改批次

### 批次 A · 令牌与对比度修正（1–2 天，S/M，低风险，先落地）
目标：不动结构，先把“看得见的错”修掉，且给后续替换提供 token。
1. `Theme.ets` 增加 Typography / Spacing / Radius / Elevation / Touch / Icon 常量（§4）。
2. 修 4 个对比度硬伤：输入框改 `surface + border_control`（P0-2）；浅色四组 `brand` 用于主按钮处换 `brandSolid`（P1-1）；深色 `surface` 提亮 + 补 `dark/media/question.png`（P1-2）；`segmented selected` 选中文字改 accent（P2-1）。
3. 蓝主题也注入 `nativeTheme`（brand `#1E6FCD`）；`DatePickerDialog/AlertDialog` 统一走 `Confirm` 式显式传色（P1-9 的 ①②③ 与 ⑤ 中的小项）。
4. 10/11vp → 12vp；`'›'` 文本改图标；`＋/−/✓/○` 先做字形基线对齐（完整替换放到 B）。

### 批次 B · 组件与几何统一（3–5 天，M，需逐屏目检）
1. `Surfaces.ets` 6 个组件按 token 重写：`SectionHeading`（overline）、`StatusPill`（tone）、`Field`（border_control）、`FactRow`（自适应标签宽）、`EmptyState`（elevation1）、`InteractiveCard`（elevation2 + 去 HDR 默认）。
2. 圆角收敛到 4 档：全仓 30 处硬编码替换（14→12、18/20/22→16、4/5/6→8 或 full）。
3. 间距收敛到 4/8/12/16/24/32：`pagePadding 14→16`、`sectionSpacing 14→16`、卡片 padding 统一 16；去掉 5/7/11/18/20 奇数档。
4. 触控目标统一 ≥44（§2.7 的 12 类）。
5. 图标统一：启用/修复 11 个 SVG（改 currentColor）或全量换 sys.symbol；补齐 `Icons.star/remove/check/chevron`，删除文字句柄；统一 16/20/24 三档尺寸。
6. 收敛分组标题与分割线为 1 套；死 token/资源清理（`scrim` 启用或删、`float.json` 删、`start_window_background` 对齐 bg）。

### 批次 C · 排版全量替换与结构性适配（5–8 天，M/L，风险最高，最后做）
1. 按 §2.1 映射表批量替换 185 处字号（工具替换 + 人工复核；重点 `ProjectDetailPage` 28、`SettingsPage` 20、`FormEditor` 11、`Surfaces` 10）。
2. 大字号适配：固定 `cardHeight`/`width(40|76|190)` 全部改自适应；`maxLines(1)` 只保留在可省略值上；滑块档位标签宽度随 fontScale；补一张 2× 字号的回归截图。
3. 深色层级方向 + 阴影体系在所有页面复核；宽屏统一（`PageScaffold` + 三档 maxWidth + 分栏策略）。
4. 动效：接 `isAnimationEnabled`，stagger 减到 2 组/60ms，去掉嵌套双反馈。
5. 主题覆盖收尾：底栏 `labelStyle`、标题栏色、Select 替换为 chip 分组、原生菜单/弹窗逐一检查非蓝主题。

**验收建议（不跑设备，仅代码/静态）**：`grep -c '\.fontSize([0-9]'` 应只剩 token 引用；`grep -c 'borderRadius([0-9]'` = 0；`grep -cE 'padding\([0-9]'` 中仅允许 0；新增 `python3 scripts/test_theme_colors.py` 检查每个 palette 18 键齐全且新增 semantic 键在两组模式下对比度 ≥ 阈值（脚本扩展）。

---

## 附录 A · 关键证据索引

| 主题 | file:line |
|---|---|
| Token 入口 / 无排版字段 | `common/Theme.ets:31-51`、`:86-105` |
| nativeTheme 10 键 / 蓝色空对象 | `common/Theme.ets:69-82` |
| 布局常量 90/100/112、14/14/4/16 | `common/constants.ets:134-150` |
| 五组 palette 定义 | `common/ThemePalettes.ets:21-97` |
| 浅色基础色值 | `resources/base/element/color.json:4-81` |
| 深色基础色值（surface<bg） | `resources/dark/element/color.json:5/21/25/45/53` |
| 浅色主题色（brand/accent/onAccent） | `resources/base/element/theme_colors.json:32-45`（绿）、`:80-93`（粉）、`:128-141`（橙）、`:176-189`（红） |
| 深色主题色（brand=accent） | `resources/dark/element/theme_colors.json:36-41`（绿）、`:84-89`（粉）、`:132-137`（橙）、`:180-185`（红） |
| 分段选中色 13% 灰 | `base/element/color.json:9`、`dark/element/color.json:9` |
| 图标四源 | `common/Icons.ets:13-58` |
| 按压/光场 | `common/visualEffects.ets:42-71`、`common/pressFeedback.ets:27/39/51` |
| 转场/入场 | `common/motion.ets:10-42`、`constants.ets:22-26` |
| 卡片/药丸/事实行/输入 | `component/Surfaces.ets:27-37`、`:90-103`、`:107-128`、`:130-165` |
| 设置行 / 滑块 / 面板 | `component/SettingsPreferenceRow.ets:14-25`、`component/SettingsChoiceSlider.ets:30/34/72-84`、`component/SettingsPanel.ets:55/72/77/82-85/200-240/310-312/354/477/597/632/443-467/620-694` |
| 标题栏钉死系统色 | `common/SystemCapability.ets:26-43` |
| 底栏无 labelStyle | `pages/Dashboard.ets:656-664`、对照 `component/HdsActionTabs.ets:30-31` |
| 分段按钮 | `component/HdsTitleBarSegment.ets:12-14/25/44-50` |
| 原生日期/时间选择器 | `component/DateField.ets:20-29` |
| 图表色/图例/环形图 | `component/charts/DistributionChart.ets:29-32/110-147` |
| 详情页圆角/字号/文字符号 | `pages/detail/ProjectDetailPage.ets:66/127/272/300/312/336/381/441/483/535` |
| 分组标题 accent | `pages/more/SettingsPage.ets:72-78/207/241/259` |
| 徽章橙色 | `pages/more/AppLogPage.ets:85-88` |
| 主题色板 | `component/ThemeColorPicker.ets:25-44` |
| Sheet 关闭键 36 | `component/SheetHeader.ets:30-45` |
| 大字号截图 | `docs/validation/settings-phone-large-font-api26.png`、`settings-narrow-large-font-api26.png` |
| 主题五组截图 | `docs/validation/theme-palettes-api26.png` |
| 深色观感 | `.shots/90-dark.jpeg`、`.shots/91-dark-restart.jpeg` |
| 浅色观感 | `.shots/93-light-restored.jpeg`、`.shots/102-settings-light-icons.jpeg`、`.shots/81-sky.jpeg` |

## 附录 B · 复现命令（只读）

```bash
# 字号分布
grep -rhoE '\.fontSize\([0-9]+\)' entry/src/main/ets --include='*.ets' | sort | uniq -c | sort -rn
grep -rho '\.fontSize(' entry/src/main/ets --include='*.ets' | wc -l          # 185
# 圆角 / 间距 / 阴影
grep -rhoE 'borderRadius\([0-9]+\)' entry/src/main/ets --include='*.ets' | sort | uniq -c
grep -rhoE 'space: [0-9]+' entry/src/main/ets --include='*.ets' | sort | uniq -c
grep -rhoE 'padding\([^)]*\)' entry/src/main/ets --include='*.ets' | grep -oE '[0-9]+' | sort -n | uniq -c
grep -rn '\.shadow(' entry/src/main/ets --include='*.ets'
# 图标 / 文字符号
grep -rn "app.media.nav_\|action_add\|action_delete" entry/src/main/ets   # 0 引用
grep -rnE "'[^']*[＋−✓○›★☆●•][^']*'" entry/src/main/ets --include='*.ets' | wc -l   # 38 行 / 41 处
# 对比度：按 WCAG 2.x 相对亮度公式用 Python 计算（脚本口径见 §2.5，输入值取自 resources/*/element/*.json）
```

### 审计限制
- 未运行构建/测试/设备套件（任务约束）；大字号结论来自既有截图 + 代码几何推断，未在新构建上复验。
- `.shots/*` 与 `settings-*-large-font` 截图早于当前提交（改名前的“天蓝/雾蓝”外观文案），因此仅用于布局/字号/图标观感，不用于颜色数值结论。
- `Select` 弹出菜单、`DatePickerDialog` 的实际渲染色无法从代码 100% 证明（取决于系统实现），按“未传主题参数 + 不在 WithTheme 子树”判定为未覆盖；如需铁证应在非蓝主题真机截图复核。
