# ElvaCos (绮秀)

English | [简体中文](README_zh.md)


A native, offline-first HarmonyOS management application for cosplayers. Core workflows run locally, from character inspiration, cosplay plans, preparation and packing to event schedules, photo archives and actual spending.

Current version: **1.0.0-beta.1**, build **10000001**, package `top.rayawa.elvacos`. Target API 26, minimum API 23. Phones are the primary validation devices; the manifest also declares Tablet / 2in1.

A clean Release build and package-content verification were completed on 2026-10-08. Current signing uses a **development/debug Profile**, suitable for Beta testing on authorized devices; market distribution still requires a distribution certificate/Profile. Full results, artifact fingerprints and known limits are in the [Beta packaging record](docs/RELEASE.md).

## Implemented Features

- **Characters and plans**: characters/versions, successive plan creation, preparation templates, custom categories/tasks, deadlines and notes. Preparation completion, equipment availability and packing confirmation are recorded separately. Equipment can be reused across plans or created inside a plan with packing entries.
- **Events and travel**: tentative, single-day or multi-day events, time slots, list/month-calendar views and linked plans. Notification permission is requested only when system reminders are enabled. Events can be passed to the device calendar confirmation page; accounts and reminders are managed by the system.
- **Photos and references**: selected images are imported through the system PhotoPicker, with originals and thumbnails stored in the sandbox. Features include filtering, multiselect, batch status changes, character covers, references and portfolios. Portfolios show only final work and published photos; “published” is a local status record.
- **Teams and spending**: local names/roles/notes, individual payments, budget comparisons, plan/category filtering, category spending bars, monthly trends for the past six months and a processing-status doughnut chart for all photos. Wardrobe prices are not automatically recorded as spending.
- **Navigation and appearance**: five HdsTabs—Home / Cos / Events / Wardrobe / My—with independent navigation. Details cover the home screen; forms and associations use sheets. Five palettes—blue, mint, cherry pink, apricot and coral—support independently persisted light/system/dark modes. Home and settings adapt between one and two columns by container size; photo grids adapt to width.
- **Settings and system capabilities**: materials, haptics, one-handed/optional grip-aware interaction, first-entry settings behavior and native list touch handling. Update logs filter Beta / RC / release versions. Local privacy text uses a native reader; Share Kit shares project summaries and versioned business objects.
- **Data protection**: encrypted RDB v3, incremental v1→v2→v3 migration, transactions and portable metadata backup v3 compatible with v1/v2. System BackupExtension is registered.
- **Offline examples**: 16 characters, 24 plans, 84 equipment items, 12 events and associated tasks, expenses and images. Debug builds seed an empty database on first launch; Release builds do not seed automatically. Examples can be appended manually from developer options by tapping the settings version number five times. See [demo data](docs/DEMO_DATA.md).

The account is an optional identity entry. Account Kit and a public Client ID are configured, but an earlier real login returned `1001502003` and has not passed acceptance testing. Cloud synchronization is not implemented. Local team records do not provide online collaboration.

## Building and Packaging

Local toolchain: DevEco Studio 26.0.0 with bundled Release SDK 26.0.0.105; ArkTS / ArkUI / Stage. There are no third-party business-runtime dependencies; Hypium / Hamock are used only for tests.

For a new checkout, copy `build-profile.example.json5` to `build-profile.json5`. The example has no signing references and supports unsigned builds. Configure local signing in DevEco when device installation or distribution is required. Keep `build-profile.json5`, certificates, private keys and passwords outside version control.

```sh
# 开发 HAP（默认 debug）
./scripts/build.sh
# 测试 feature
./scripts/build.sh assembleHap ohosTest
# Release 全量 HAP / APP
./scripts/build.sh clean default release
./scripts/build.sh assembleApp default release
# 仅生成 Release HAP
./scripts/build.sh assembleHap default release
```

Script arguments are `[task] [target] [debug|release]`. assembleApp uses project mode; other tasks use module mode. The default DevEco path is `~/Applications/DevEco-Studio.app`; `DEVECO_HOME` may point to the app or Contents directory.

HAP files are written to `entry/build/default/outputs/default/`; APP files to `build/outputs/default/`. Delivery copies and SHA-256 manifests are in `build/releases/1.0.0-beta.1/`; build directories are not committed. **Release compilation and distribution signing are separate concerns**: an automatically debug-signed package is not a market-distribution package.

## Verification

```sh
# 基础确认（开发期默认，不需要设备）
./scripts/build.sh
python3 scripts/test_schema.py
python3 scripts/test_theme_colors.py

# 设备套件（仅用户要求或发布候选；已连接且解锁，可用 HDC_TARGET_ID 选择设备）
./scripts/device-test.sh
./scripts/ui-test.sh
./scripts/demo-test.sh
# 修改相关布局/主题时选用
./scripts/layout-test.sh
./scripts/settings-layout-test.sh
./scripts/theme-test.sh
./scripts/ui-polish-test.sh

# 发布候选：核对交付产物
python3 scripts/check_release.py --hap build/releases/1.0.0-beta.1/ElvaCos-1.0.0-beta.1-release-signed.hap --app build/releases/1.0.0-beta.1/ElvaCos-1.0.0-beta.1-release-signed.app
```

**Basic checks are the default**: one `build.sh` invocation plus Python checks selected for the change type, without a device. Each device-suite script rebuilds the main and test packages, replaces the installation and runs on a physical device. `theme-test.sh` also clones the project for repeated builds and restored installations. Running several suites repeatedly builds the same source and costs several times more than the change itself. Run them only when explicitly requested or finalizing a release candidate, selecting one directly relevant suite at a time.

Device scripts run serially through `device_test_lock.py`. Judge Hypium by Pass / Failure / Error / Ignore. Hard-coded `Tests run: N` values represent current case counts; if they differ, first determine whether the expected count is outdated rather than repeatedly rerunning. Domain/demo tests use separate encrypted databases and media directories; layout/theme hosts use in-memory data or separate Preferences. Tests do not clear the user's `personal.db`. Most scripts produce a debug main package; reinstall the saved delivery copy to restore this Release HAP. Final packaging checks retest the Release main package; see [validation records](docs/VALIDATION.md).

Wide-screen canvases on a phone verify component layout only, not real Tablet / 2in1 devices, multiple windows, foldables or system safe areas. Complete evidence is still missing for API 23 hardware, manual font-size/screen-reader use, full cross-device system backup, actual background reminder delivery and some hardware capabilities.

## Structure and Data

```text
entry/src/main/ets/
├── ability/          # Stage / 系统备份生命周期
├── common/           # appState、偏好、Theme、图标与系统能力
├── component/        # 导航、设置、表单、网格、Canvas 图表
├── pages/
│   ├── Dashboard.ets # 五页导航与启动调度
│   ├── main/         # 首页、Cos、活动、衣柜、我的
│   ├── detail/       # 角色、计划、装备、活动、照片、参考图
│   └── more/         # 设置、花费、更新日志、隐私阅读
├── model/            # ApplicationState、实体、领域规则与统计
└── data/             # database、repository、media
```

UI → ApplicationState/domain rules → Repository → RDB. `common/appState.ets` supplies shared V2 state through AppStorageV2. Settings persist through Preferences / DiskStorage / AppStorage and bind through StorageLink. Pages retain local filtering, overlays, scrolling and navigation context. Staged startup and cancellation guards prevent stale asynchronous writes; destruction waits for pending operations and database closure.

Metadata JSON **does not contain images**. Restore validates data before transactional replacement and preserves the existing data on failure. Matching local media can be reused; complete cross-device media migration requires system backup and separate validation. Removing an app-local copy does not delete the original from the system album.

## Documentation

| Document | Contents |
| --- | --- |
| [Packaging record](docs/RELEASE.md) | Builds, artifacts, signing and delivery boundaries |
| [Architecture](docs/ARCHITECTURE.md) | State, database, media and lifecycle |
| [Capability matrix](docs/CAPABILITIES.md) | API / SysCap / permissions and fallbacks |
| [UI reference](docs/UI_STYLE.md) | Dashboard sources, interactions, responsiveness and feedback |
| [UI/UX audit](docs/UI_UX_AUDIT.md) | Existing P0/P1/P2 issues, design-system recommendations and implementation batches |
| [Themes](docs/THEMES.md) | Five resource sets, persistence and readability |
| [Demo data](docs/DEMO_DATA.md) | Counts, sources, seeding rules and isolated tests |
| [Huawei account](docs/HUAWEI_ACCOUNT_SETUP.md) | Public IDs, certificates, login issues and cloud-space boundaries |
| [Validation records](docs/VALIDATION.md) | Latest results and historical evidence |
| [Roadmap](docs/ROADMAP.md) | Current capabilities, known issues and optional directions |
| [Video reference](docs/UX_REFERENCE.md) | Historical observations and implemented scope |
| [Experience restructuring specification v2](docs/UX_RESTRUCTURE_PLAN.md) | Unimplemented design specification: constraints, navigation/routes, data definitions, migration and stages |

Documents explain current behavior and tradeoffs; historical plans and test lists do not automatically constrain later tasks. The single source for privacy text remains `entry/src/main/resources/rawfile/privacy.html`. Its cloud-service, account-deletion and withdrawal descriptions differ from current offline capabilities; the discrepancy is recorded, but the policy text has not yet been revised. Verify actual capabilities and image-use permissions before public release.
