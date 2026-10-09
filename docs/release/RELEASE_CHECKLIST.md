# DayTrace Release Checklist

**Languages / 语言：** [English](#daytrace-release-checklist) · [简体中文](#简体中文)

This checklist separates local automation, signed Development validation, and
Developer ID distribution. A passed automation build is not evidence of TCC,
Chrome runtime, notarization, or Gatekeeper success.

## Repository and identity

- [ ] Git tree is clean before release work.
- [ ] Version/build increment is intentional.
- [ ] Mac App Bundle ID is stable, developer-owned, and configured for the candidate.
- [ ] Legacy `com.daytrace.spike` is retained only for migration/rollback.
- [ ] Native Messaging host remains `com.daytrace.spike` unless a migration is approved.
- [ ] Chrome extension ID in the installed manifest matches the developer's extension.

## Automated gates

- [ ] Unsigned Debug build passes.
- [ ] Full XCTest passes with no failures.
- [ ] Native Host build passes and is arm64 on Apple Silicon.
- [ ] Native Host configuration regression passes.
- [ ] Migration, restore, backup portability, and installer tests pass.
- [ ] Localization, privacy audit, and `git diff --check` pass.

## Development installed build

- [ ] Apple Development signed app build succeeds.
- [ ] `codesign --verify --deep --strict` passes.
- [ ] Input Monitoring / Event Tap manual test passes.
- [ ] Chrome Native Messaging runtime test passes.
- [ ] NookX and NetEase detector tests pass.
- [ ] Pause, Lock/Unlock, Sleep/Wake, relaunch persistence, Restore, Selective Delete,
      Launch at Login, and timezone tests pass.

## Distribution build

- [ ] Release build is produced by `scripts/release/build-release.sh`.
- [ ] Developer ID Application signing passes.
- [ ] Native Host signing and verification pass.
- [ ] DMG is created by `scripts/release/build-dmg.sh`.
- [ ] Notary credentials are supplied through an existing Keychain profile.
- [ ] `scripts/release/notarize.sh` completes and stapling validates.
- [ ] Gatekeeper assessment passes.
- [ ] Final install smoke test passes.

Do not tag or publish until all applicable checks are complete.

## 简体中文

本清单区分本地自动化、签名开发验证和 Developer ID 分发。自动化构建通过不代表 TCC、Chrome 运行、公证或 Gatekeeper 已通过。

### 仓库与身份

- [ ] 发布前 Git 工作树状态已检查，版本号/构建号变更有意为之。
- [ ] App Bundle ID 稳定、由开发者拥有并已配置。
- [ ] 旧 `com.daytrace.spike` 仅用于迁移/回滚。
- [ ] Native Messaging Host 名称未变，或已完成明确批准的迁移。
- [ ] 安装 manifest 的 Chrome 扩展 ID 与开发者扩展匹配。

### 自动化门禁

- [ ] 未签名 Debug build 成功。
- [ ] 完整 XCTest 在目标 revision 上通过。
- [ ] Native Host build 成功；Apple Silicon 产物架构符合预期。
- [ ] Native Host 配置回归检查通过。
- [ ] 迁移、恢复、备份可移植性和安装器测试通过。
- [ ] 本地化、隐私审查和 `git diff --check` 通过。

### 开发安装版

- [ ] Apple Development 签名 App 构建成功，`codesign --verify --deep --strict` 通过。
- [ ] Input Monitoring / Event Tap 人工测试通过。
- [ ] Chrome Native Messaging 真实运行测试通过。
- [ ] NookX、NetEase 检测器测试通过。
- [ ] Pause、锁屏/解锁、睡眠/唤醒、重启持久化、恢复、选择性删除、登录启动和时区测试通过。

### 分发构建

- [ ] 由 `scripts/release/build-release.sh` 生成 Release。
- [ ] Developer ID Application 签名通过。
- [ ] Native Host 签名及验证通过。
- [ ] 由 `build-dmg.sh` 生成 DMG。
- [ ] 使用已有 Keychain profile 提供公证凭据。
- [ ] `notarize.sh` 完成、公证票据 stapling 和验证成功。
- [ ] Gatekeeper 评估通过。
- [ ] 最终安装冒烟测试通过。

所有适用检查完成前，不要打 tag 或发布。
