# ElvaCos

English | [简体中文](README_zh.md)

An offline-first HarmonyOS application for cosplay plans, equipment, events, photos and expenses.

## Overview

Core workflows run locally: organize characters and plans, track preparation and packing separately, associate events and equipment, archive photos and record actual payments. Data is stored in an encrypted relational database with incremental migrations and metadata backup. Account integration is incomplete and cloud synchronization is not implemented.

## Technology and Dependencies

ArkTS, ArkUI/HDS, HarmonyOS Stage APIs, ArkData, OHPM and Hvigor. Target API 26, minimum API 23. Business logic has no declared third-party runtime package; Hypium and Hamock support tests.

## Repository Structure

- `entry/src/main/ets/` — ArkTS application code
- `entry/src/main/resources/` — resources and routes
- `AppScope/` — application metadata
- `build-profile.example.json5` — build configuration template
- `oh-package.json5` — package dependencies
- `entry/src/main/ets/model/` — domain entities
- `entry/src/main/ets/data/` — database and repositories
- `entry/src/main/ets/pages/` — current five-tab navigation and screens
- `docs/` — design, data and release notes
- `scripts/` — build and validation tools

## Quick Start

1. Open the repository root in DevEco Studio with the SDK required by `build-profile.example.json5`.
2. Copy that template to `build-profile.json5`, restore OHPM dependencies and configure signing locally if installing on a device.
3. Select the `entry` module and a compatible device/emulator, then build and run from the IDE. Keep certificates and machine-specific paths outside version control.

Run `./scripts/build.sh` for the default debug build. Current navigation is Home / Cos / Events / Wardrobe / My; the later restructuring plan in `docs/` is not the implemented interface. Debug builds may seed local example data; release builds do not seed it automatically. See [release notes](docs/RELEASE.md) for signing and packaging.
