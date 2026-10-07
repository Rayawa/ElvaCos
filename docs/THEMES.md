# 应用主题

版本基线：**1.0.0-beta.1（10000001）**；文档核对：2026-10-08。现状与历史证据；最终构建、签名与交付结论见 [打包记录](RELEASE.md)。

主题配色与应用外观分开管理。配色为蓝、绿、粉、橙、红；外观为浅色、跟随系统、深色。每个配色都有对应的浅色和深色资源，默认保留蓝色与原有外观选择。

## 官方方案与实施取舍

- [华为：深色模式适配最佳实践](https://developer.huawei.com/consumer/cn/doc/doccenter-ui-dev/bpta-dark-mode-adaptation)：自定义色值放入 base / dark 下的同名资源，保留 `$r` 引用，系统随颜色模式解析；手动模式通过 ApplicationContext.setColorMode，跟随系统使用 COLOR_MODE_NOT_SET。本工程沿用这套机制，无需配置监听、字符串色值缓存或导航重建。
- [华为：主题换肤 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V14/js-apis-arkui-theme-V14)：CustomTheme 通过品牌色、强调色等语义令牌适配原生控件。已核对本机 API 26 SDK 的 `@ohos.arkui.theme.d.ts` 与 `with_theme.d.ts`，WithTheme 自 API 12 支持，满足最低 API 23。
- [华为：应用内卡片色彩原则](https://developer.huawei.com/consumer/cn/doc/design-guides/harmonyos-widget2-0000002731312633)：配色应克制，避免大量高饱和色，辅助色仅作点缀。本工程将彩色主要用于操作、分组标题、状态标签和选择控件，大面积背景只保留轻微色相。

`ThemeControl.setDefaultTheme` 适合设置初始默认主题；这里选择在 Dashboard 根节点使用 `WithTheme({ theme: Theme.nativeTheme })` 处理运行时更新。自定义页面继续消费 `@ObservedV2 Theme` 的 Resource 令牌。蓝色传空主题恢复原生默认样式；其他配色仅覆盖原生强调与强调背景上的前景色，中性样式和警示语义仍交给系统，避免改变原有蓝色的系统控件表现。

## 配色关系

蓝色的全部原资源值保留。2026-10-08 调整新增主题：粉色参考 app_icon.png 的明亮樱花粉，绿色采用薄荷绿，橙色采用杏橙，红色采用珊瑚红。深色对应使用更明亮的同色系强调色，背景仍有足够的深浅层次。

浅色的图形填充与强调文字分为两个语义角色：brand 用于按钮、滑块、进度和配色色块，accent 用于强调文字及需要清晰识别的图标。这样可以使用轻盈的填充色，同时保证文字可读性。onAccent 为填充上的深色前景；蓝色的 brand / accent 均引用原 diff_content，onAccent 也保持原值。

| 配色 | 浅色填充 brand | 浅色文字 accent | 深色填充 / 文字 |
| --- | --- | --- | --- |
| 蓝（原样） | #1E6FCD | #1E6FCD | #4A9CE2 |
| 薄荷绿 | #58C89B | #167A54 | #83DBB2 |
| 樱花粉 | #F391B5 | #B63866 | #F8A3C4 |
| 杏橙 | #F2B16E | #995310 | #F4BF83 |
| 珊瑚红 | #EF8B96 | #B33E50 | #F49DA7 |

每组包含 bg、surface、tint、ink、muted、brand、accent、onAccent、line、divider、groupDivider、shadow；遮罩、透明色、分段选中底色和业务警示色沿用共同资源。正文、次级文字及强调文字在页面底、卡片底、次级底上分别验证，正文至少 7:1，其余文字至少 4.5:1。按钮前景针对 brand 验证，避免以加深所有填充色来满足文字对比度。

## 状态与兼容

- `common/ThemePalettes.ets` 是配色目录及资源映射，`Theme.ets` 是唯一视觉令牌入口。
- Preferences 新增 `themeColor`，缺失或无效时回落 blue；不重写已有 appearance，不更改历史迁移标记或业务数据库。
- appearance 仍保存 sky / system / mist，显示文案改成浅色 / 跟随系统 / 深色。
- SettingsService 保存成功后应用主题，StorageLink 更新设置控件；AppState 的串行设置队列按字段合并，避免不同设置相互覆盖。
- 首屏前加载配色；深浅色切换继续使用资源限定词，既有 base / dark 图标不需复制五份。

## 验证

`python3 scripts/test_theme_colors.py` 验证资源成对、引用完整、蓝色锚点、明度层次、文字对比度与新增填充色的明亮程度。

`./scripts/theme-test.sh` 在临时构建中加载生产偏好控件，使用唯一测试 Preferences 和独立旧偏好文件，始终不打开 personal.db。验证无 themeColor 的既有浅色选择、十种配色组合、跟随系统与配色独立、窄屏两倍字号，以及强制结束进程后的持久化恢复。完成后恢复生产包；测试 Ability 只加入临时 manifest。

2026-10-08 调色后复测结果：主包与测试包构建成功；资源检查 3 项、API 26 真机切换检查 3 项、强制结束进程后的恢复检查 1 项通过，Failure / Error 均为 0。40 个实际渲染颜色锚点（页面底、卡片底、强调文字与图形填充）与资源值一致（RGB 单通道 ±1）。[真机参考图](validation/theme-palettes-api26.png)展示同一组生产偏好控件在十种组合下的实际表现；测试宿主未打开业务数据库，完成后已恢复正式包。

## Beta 收尾

2026-10-08 最终资源检查再次 3/3 通过，Release HAP 携带 base / dark 资源；配色与外观的持久化键保持兼容。本次没有修改色值，前述十种组合与恢复报告属于调色阶段证据，不当作本次重新执行的全量主题套件。最终打包回归见 RELEASE / VALIDATION。
