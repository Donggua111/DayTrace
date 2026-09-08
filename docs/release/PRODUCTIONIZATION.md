# DayTrace Productionization V1

## Current identity decision

The current development identity remains `com.daytrace.spike`. No final
ownership-safe production Bundle ID has been selected, so this repository does
not guess one. The Native Messaging host remains `com.daytrace.spike` for
compatibility. The active unpacked Chrome extension ID is
`mmnoopahcchjobiajnhembdlipkhbjgo`.

The identity map is maintained in `scripts/daytrace-identity.sh` and mirrored
by `DayTraceIdentity` for diagnostics and migration helpers.

## Artifact classes

1. Automation build: unsigned, used only for local build and XCTest.
2. Development installed build: Apple Development signed, used for TCC and
   real-Mac validation.
3. Distribution build: Developer ID signed, notarized, stapled, and assessed
   by Gatekeeper.

The first class must never be reported as evidence for Input Monitoring.

## Stable locations and migration

The Core Data store is already at the Bundle-ID-independent user location:
`~/Library/Application Support/DayTrace/DayTrace.sqlite`. Backups remain under
`~/Library/Application Support/DayTrace/Backups`. The existing Native Host
development location remains under the same DayTrace-owned Application Support
root. No real-user data-location migration is required in this sprint.

When a future production Bundle ID is selected, the app runs a one-time,
idempotent migration of known UserDefaults keys from `com.daytrace.spike` only.
Existing production values win, unknown keys are ignored, and the old store is
not deleted. Activity backups remain logical and portable across identities.

## Installation and rollback

`scripts/install-development.sh` installs to the user Applications directory,
updates the Native Host with an atomic sibling-copy/rename, and retains the
previous app bundle for rollback. It requires a verified Apple Development
signature unless `--allow-unsigned` is explicitly supplied for non-TCC local
automation.

The Native Messaging installer writes a validated manifest to the user Chrome
directory through a temporary sibling and atomic rename. It rejects arbitrary
extension IDs and never touches TCC or unrelated Chrome data.

## Signing and distribution

The project has Debug and Release configurations with marketing version `0.9.0`
and build `1`. Signing remains automatic and uses the Team configured in the
project; credentials are never stored in the repository. Developer ID signing
and notarization are pipeline capabilities only until credentials exist.

Use `scripts/release/build-release.sh`, `build-dmg.sh`, `notarize.sh`, and
`validate-release.sh`. By default, generated Release artifacts are written to
the stable user-level directory `~/Applications/DayTrace/ReleaseArtifacts`;
set `DAYTRACE_RELEASE_OUTPUT_DIR` to override it. The repository `release/`
directory remains ignored for ad-hoc local artifacts and is not tracked.

## Runtime safety and privacy

The app owns a kernel-held lock under its DayTrace runtime directory so two
instances cannot simultaneously checkpoint the same store or own the Unix
socket. Existing tracking accounting, Native Messaging, Unix socket, Input
Monitoring, and privacy boundaries are unchanged. Diagnostics expose health,
version, identity class, and configuration metadata, not activity history,
typed content, full URLs, or personal paths.

## Manual validation status

Signed Input Monitoring, Chrome runtime IPC, background detectors, pause,
lock/sleep lifecycle, relaunch persistence, Restore, Selective Delete, Launch
at Login, and timezone re-anchor remain real-Mac acceptance gates. No runtime
PASS is inferred from static inspection.
