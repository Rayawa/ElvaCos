# 1.0.0-beta.1 打包与交付记录

核对日期：2026-10-08。版本 `1.0.0-beta.1`，构建号 `10000001`，包名 `top.rayawa.elvacos`，vendor `Rayawa`。本次基于当前工作区，包括尚未提交的既有功能修改；没有创建 Git 标签或推送发行。

**结论：Release HAP / APP 已生成，包结构、资源与签名核验通过；最后页面冒烟尚未通过复测，当前签名仅供授权设备测试，不能标为全部验收通过或市场发行就绪。**

## 构建与配置

- `./scripts/build.sh clean default release` 成功。
- `./scripts/build.sh assembleApp default release` 全量构建成功：42 tasks，42 executed，0 up-to-date；同时生成 Release HAP 与 APP。
- 生成的 BuildProfile 为 BUILD_MODE_NAME=release、DEBUG=false；HAP 与 APP 内嵌 HAP 的清单均为 buildMode=release、debug=false。
- 最低 API 23 / 6.1.0，目标 API 26，编译 SDK 26.0.0.105；Stage 单 entry 模块，设备声明 phone / tablet / 2in1。
- 当前 Release 配置未开启混淆。构建记录含 163 条带文件位置的 ArkTS 警告，主要涉及异常处理、弃用 API 与已有 Builder bind；构建成功不等于零警告。
- 版本、构建号与应用内日志一致；日志日期更新为 2026-10-08，并补充主题、图表、照片刷新及离线示例。修正公开 vendor / 工程描述占位；未修改本机私密签名配置。
- 签名示例移除不存在的 default signingConfig 引用，新检出可先未签名构建；设备安装与发行需自行配置对应签名。

## 产物

交付副本位于 `build/releases/1.0.0-beta.1/`，由 .gitignore 的 build 规则排除。后续 debug 构建不会覆盖这些副本。

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `ElvaCos-1.0.0-beta.1-release-signed.app` | 3247786 | `c006a61dff6ab793e2bf30adfbc58cadde3a0e1f2ca9e18b0dbebd8e96bfc916` |
| `ElvaCos-1.0.0-beta.1-release-signed.hap` | 4407668 | `b6beff9247b0d50cf2986b429f25f23b46d0d216b9496a1abbce0ada1b69fe6f` |
| `ElvaCos-1.0.0-beta.1-release-unsigned.app` | 3232457 | `683035092aa6bf69f45c5b21be90ef1be3792f9c6fc693fc875cc88da49a3dd4` |
| `ElvaCos-1.0.0-beta.1-release-unsigned.hap` | 4362806 | `497d61c21e1f11dcf448563cacfb8c21cf3c5421a736f93adba738d7d8a37bbd` |

同目录有 `SHA256SUMS.txt`，可在交付目录执行 `shasum -a 256 -c SHA256SUMS.txt`。HAP 用于设备安装，APP 为工程打包产物；unsigned 副本保留供维护者使用真实发行配置重新签名。切换发行签名后须重新核验，当前哈希不适用于重新签名的文件。

## 包内容与签名

`python3 scripts/check_release.py --hap build/releases/1.0.0-beta.1/ElvaCos-1.0.0-beta.1-release-signed.hap --app build/releases/1.0.0-beta.1/ElvaCos-1.0.0-beta.1-release-signed.app` 通过，结果见 [包核对报告](validation/beta1-package-check-report.txt)。

包内版本、vendor、公开 Client ID、设备类型和五项权限与源码一致；唯一业务 Ability 为 EntryAbility，备份扩展 EntryBackupAbility 为非导出；未发现测试入口、测试运行器或私密配置资源。privacy.html 与全部 rawfile 逐字节一致，demo 含两份 JSON 和 32 个 JPEG；Release 不自动加载示例，保留手动追加入口。

SDK hap-sign-tool verify-app 的代码签名、权限签名及整体核验通过，Profile CMS 验证成功，证书/Profile 有效。**Profile type=debug**，与 Release 编译模式独立；当前签名包仅可供 Profile 授权设备测试。没有发行 Profile，不推断可以应用市场分发。公开摘要见 [签名报告](validation/beta1-signature-report.txt)。

本次从 Profile 的 development-certificate 确认应用开发证书 SHA-256 为 `3F:0E:3F:76:46:D3:43:AA:F1:38:87:A9:1D:9F:56:0B:72:AB:7B:65:BB:3B:9D:55:EE:17:88:AC:1F:35:EC:7B`。旧文档的 DF:21:…:3A:37 属于根证书，已更正当前说明；历史报告保留并注明。签名正确不代表 Account Kit / AGC 认证通过，详见 [账号说明](HUAWEI_ACCOUNT_SETUP.md)。

## 本次验证与未完成复测

| 检查 | 结果 | 范围 |
| --- | --- | --- |
| SQLite 模型 | 12/12 通过 | 关系、迁移、约束、替换失败回滚；临时数据 |
| 主题资源 | 3/3 通过 | 成对资源、蓝色锚点、明度与文字对比度 |
| 原生 Hypium | Pass 55 / Failure 0 / Error 0 / Ignore 0 | 当前源码 debug 主包 + 测试 feature，隔离库/媒体与领域规则 |
| Release 安装 | 成功 | 覆盖安装交付 HAP，保留用户记录 |
| 首轮 Release 页面冒烟 | Pass 1 / Failure 0 / Error 10 / Ignore 0 | 首个错误为设置首屏未找到用户名，其后停留设置页导致后续错误 |
| 页面测试修正 | 测试 HAP 编译/签名成功；设备复测未完成 | 改为滚动定位用户名、云同步、材质、操作标签与帮助，版本信息滚到底检查 |
| 最终包结构/资源与签名 | 通过 | HAP 和 APP 内容检查，SDK 验签与 Profile 核对 |

报告：[原生回归](validation/beta1-native-api26-report.txt)、[修正前页面失败](validation/beta1-release-ui-before-scroll-fix-api26-report.txt)。最后手机断开，设备列表为空；本次重连尝试未恢复，不能将测试编译成功或源码定位当作页面复测通过。最新成功安装的业务主包为本次 Release HAP，尚未安装修正后的测试 feature。

修正后只需在已连接、解锁的授权设备执行下面的最终页面复测，不必重复无关设备矩阵：

```sh
./scripts/build.sh assembleHap ohosTest
# 使用 DevEco 自带 hdc，并明确选择实际连接设备
hdc -t <device> install build/releases/1.0.0-beta.1/ElvaCos-1.0.0-beta.1-release-signed.hap
hdc -t <device> install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
hdc -t <device> shell aa force-stop top.rayawa.elvacos
hdc -t <device> shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyUITestRunner -s timeout 120000
```

应确认安装成功及 `Tests run: 11, Failure: 0, Error: 0, Pass: 11, Ignore: 0`，aa 返回码本身不足以判断。账号已配置时「缺少配置」分支跳过真实登录，因此即使页面套件通过也不能宣称真实 Account Kit 登录成功。示例 5 项与主题切换/恢复、UI polish 等旧报告见 VALIDATION，本次没有重新运行这些专项，原生 55 项不包含示例专项。

## 对外发布的已知边界

- 应用云同步未实现，Account Kit 真实登录此前返回 1001502003，仍需核对 AGC / 实际应用签名；本次未重新拉起账号授权。
- privacy.html 的云端服务、注销与撤回描述仍与实际离线能力不同；本次没有改写提供的正文，市场发布前需要修订或明确处置。
- 示例中的官方角色图片有公开溯源信息，尚未记录发行使用授权；调试展示与公开分发分别确认。
- 系统 BackupExtension 已注册，跨设备完整媒体恢复尚未验证；便携 JSON 不含图片，恢复是事务替换。
- API 23 真机、真实 Tablet / 2in1 / 多窗 / 折叠、系统字号与读屏体验、实际提醒投递及部分硬件反馈仍无完整验收证据。
- 后续 UX_RESTRUCTURE_PLAN 属于未实施提案，本次未变更五 Tab 导航或升级数据库/备份版本。

README、AGENTS 与 docs 全部 Markdown 已按本版本核对；VALIDATION 保留历史过程，旧报告与截图不批量改写成最新证据。后续范围由用户任务决定，以上边界不是每次开发的固定执行清单。
