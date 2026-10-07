# 华为账号与云空间接入

2026-10-07。当前包名 `top.rayawa.elvacos`，最低 API 23。账号和云数据是两项独立能力。

## 当前诊断

用户已确认应用 Client ID `6917618412076034516`，现已按字符串配置在 entry module 的 `metadata.client_id`，并声明 INTERNET。没有提供 APP ID，因此不推测或复制为 `app_id`。端侧不保存 Client Secret。

API 26 手机从正式设置页面点「登录」后，Account Kit 返回 `1001502003`：`Invalid input parameter value. Invalid clientId or profile.`，未成功登录。已核对签名 HAP 内实际 Client ID 与用户提供的值完全相同。当前调试 Profile 的包名是 `top.rayawa.elvacos`，`app-identifier` 为 `6918744149341255159`；需在 AGC 核对 Client ID 和 Profile 是否属于同一应用，必要时重新下载调试 Profile。应用标识符、Client ID 与 APP ID 不视为可互换值。

当前签名证书公开 SHA-256 指纹：

```text
DF:21:A3:C0:9F:79:54:57:93:05:F8:5C:64:F8:0C:AD:86:F7:98:53:EE:3A:88:7C:1D:EC:95:D2:18:DF:3A:37
```

该指纹同时由实际签名 HAP 中的叶证书确认。SDK `hap-sign-tool.jar verify-app` 验证签名、代码签名及权限签名成功，Profile 在有效期内。自动签名链中间证书与叶证书的指纹不同，不能将其当作证书不匹配证据；签名包验证成功也不能证明 AGC 账号身份校验通过。

没有云项目配置，不能将本机 OpenID 登录态当成云同步已开通。Account Kit 的 1001500001 还可能由签名指纹不匹配、证书更换或平台配置未生效导致，需结合实际错误码确认。

## 配置账号

1. 在 AGC 为实际 HarmonyOS 应用开通 Account Kit，使用应用的 Client ID，不使用项目 Client ID。
2. 将当前调试签名的 SHA-256 证书指纹配置到同一应用；发行包需要配置发行证书指纹。勿把私钥、密码或 client_secret 放入端侧工程。
3. 按 `config/huawei-account.example.json` 准备只含公开 ID 的配置文件，`appId` 可省略。当前公开配置为 `config/huawei-account.json`。执行 `python3 scripts/configure_account.py --config /absolute/path/account.json`。脚本先验证包名与字段，再写入 module.metadata 的 client_id、明确提供时的 app_id 和 INTERNET 权限；未提供真实值时不修改工程，省略 appId 时保留已有值。
4. 执行 `./scripts/build.sh`，使用已登记的签名重新安装，再测试登录和退出。

登录请求使用每次生成的随机 state，并核对响应 state；只保存 OpenID / UnionID / 展示名 / 登录时间，不持久化令牌。登录失败不会写入成功状态。

显式真机登录验收：`HDC_TARGET_ID=<目标设备> sh scripts/account-test.sh`。此脚本构建、覆盖安装且保留业务数据，从正式设置页点登录，成功时保存正常的本机登录态，不自动退出/撤销授权。不输出身份标识或令牌。真实登录失败时脚本必须失败，不能把安装成功或 aa 返回码当成登录成功。

## 云空间边界

现阶段未实现应用云同步，设置明确显示「尚未接入」，说明弹层提供已有的元数据导出入口。系统文件选择器可选择设备上可用的云空间位置；JSON 不含照片。系统 BackupExtension 已注册，但真实跨设备全量备份/恢复仍需单独验收。

Cloud Foundation Kit 的云数据库/云存储属于开发者云后端，不能凭保存的 OpenID 自动访问个人云空间。要接入该方案还需要真实项目、用户凭据来源、云数据库/存储实例及账号隔离配置；在这些配置缺失时不创建能点击但不能同步的入口。

设备日历由 Calendar Kit 的系统确认页管理：用户选择日历账户和提醒。保存在华为账号日历账户的日程是否上传，由系统云空间的日历同步开关决定；它不代表应用内角色、准备任务或照片已经同步。

## 依据

- [Account Kit 配置与错误排查](https://developer.huawei.com/consumer/cn/doc/doccenter-atomic-service/account-guide-atomic-faq)
- [Calendar Kit](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/calendarmanager-overview-V14)
- [华为云空间日历同步](https://consumer.huawei.com/cn/support/content/zh-cn16010818/)
- 本机 SDK：authentication.d.ts 的 LoginWithHuaweiIDRequest / Response 与随机 state；cloudCommon.d.ts 的 AuthProvider。
