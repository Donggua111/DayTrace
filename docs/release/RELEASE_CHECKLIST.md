# DayTrace Release Checklist

This checklist separates local automation, signed Development validation, and
Developer ID distribution. A passed automation build is not evidence of TCC,
Chrome runtime, notarization, or Gatekeeper success.

## Repository and identity

- [ ] Git tree is clean before release work.
- [ ] Version/build increment is intentional.
- [ ] Mac App Bundle ID is `com.wudonggua.daytrace` for the production candidate.
- [ ] Legacy `com.daytrace.spike` is retained only for migration/rollback.
- [ ] Native Messaging host remains `com.daytrace.spike` unless a migration is approved.
- [ ] Canonical Chrome extension ID is `mmnoopahcchjobiajnhembdlipkhbjgo`.

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
