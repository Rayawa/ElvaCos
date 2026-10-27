# ElvaCos

[English](README.md) | 简体中文

离线优先的 HarmonyOS Cos 计划、装备、活动、照片与花费管理应用。

## 项目概述

核心流程在本机完成：整理角色与计划，分别记录准备和装包状态，关联活动与装备，归档照片并登记实际付款。数据使用加密关系数据库，支持增量迁移与元数据备份。账号接入尚未完成验收，云同步未实现。

## 技术栈与依赖

ArkTS、ArkUI/HDS、HarmonyOS Stage 接口、ArkData、OHPM、Hvigor。目标 API 26，最低 API 23。业务未声明第三方运行时包，测试使用 Hypium 与 Hamock。

## 文件结构

- `entry/src/main/ets/` — ArkTS 应用代码
- `entry/src/main/resources/` — 资源与路由
- `AppScope/` — 应用配置
- `build-profile.example.json5` — 构建配置模板
- `oh-package.json5` — 包依赖
- `entry/src/main/ets/model/` — 领域实体
- `entry/src/main/ets/data/` — 数据库与仓储
- `entry/src/main/ets/pages/` — 当前五入口导航与页面
- `docs/` — 设计、数据及发布说明
- `scripts/` — 构建与验证工具

## 快速上手

1. 使用 DevEco Studio 打开仓库根目录，并安装 `build-profile.example.json5` 指定的 SDK。
2. 将模板复制为 `build-profile.json5`，恢复 OHPM 依赖；如需真机安装，在本地配置签名。
3. 选择 `entry` 模块和兼容设备或模拟器，在 IDE 中构建运行。证书及机器路径不进入版本控制。

执行 `./scripts/build.sh` 完成默认调试构建。当前导航为首页 / Cos / 活动 / 衣柜 / 我的，`docs/` 中后续重构方案尚未作为现有界面实现。调试构建可能初始化本地示例数据，Release 不自动填充。签名与打包参见[发布说明](docs/RELEASE.md)。
