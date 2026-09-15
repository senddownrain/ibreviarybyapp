# Android audit emulator — current state (2026-09-15)

Repository: `C:\Users\User\Documents\GitHub\ibreviarybyapp`.

Created reusable script: `tools/recreate_android_audit_avd.ps1`. It discovers the user SDK, limits deletion to `Pixel7_API34_Audit`, checks WHPX, reuses the installed image, creates a Pixel 7 AVD, cold boots with no snapshot and wipe-data, checks `sys.boot_completed` and Settings, then only proceeds to Flutter/app if System UI passes. The script has been edited after the latest run; that exact revision has not yet been rerun. Do not claim it passed end to end.

SDK: `C:\Users\User\AppData\Local\Android\Sdk`. Emulator: 36.4.10.0. WHPX acceleration: usable. Image: `system-images;android-34;google_apis;x86_64` already installed. Target AVD exists and was recreated cleanly several times; other AVDs were left alone. Pixel 7 profile: 1080×2400 px, 420 dpi, RAM 4096 MB. Host: 4 physical cores, 8 threads, about 16 GB RAM. Latest AVD config has 2 virtual CPU cores because 4 virtual cores saturated this host during first boot.

Latest controlled attempt: `-no-snapshot -wipe-data -gpu auto` with 2 cores reached `sys.boot_completed=1` on `emulator-5554` but Settings generated an ANR for `com.android.settings.FallbackHome` (`Input dispatching timed out`, 2026-09-15 10:06:53 emulator time). One software fallback for this same 2-core AVD also reached `sys.boot_completed=1`, but before Settings an ANR occurred in `com.android.systemui/.keyguard.KeyguardService` (10:12:26). It was stopped. `adb devices` now shows no running emulator.

Earlier 4-core software attempt showed a visible `System UI isn't responding` dialog; its screenshot is `settings-clean-boot.png`, and Android events also showed `am_anr` for `com.android.systemui/.SystemUIService`. This confirms the blocker is in the clean emulator/System UI before the app. No Flutter device or app launch was attempted after these failures, so splash and navigation modes remain untested. No production or Flutter UI/business code was changed by this task.

Evidence: `recreation.log`, `device-info.txt`, `blocker-diagnostics.log`, `settings-clean-boot.png`, `systemui-anr.png`, and short emulator stdout/stderr logs in this directory. The current `blocker.log` was overwritten by a screenshot-capture error during the last script run and should be corrected to the System UI ANR before final reporting.

Pre-existing uncommitted changes at task start: `docs/audit-evidence/android-layout/emulator-start.log`, `lib/repositories/bible_repository.dart`, `pubspec.lock`, `test/bible_repository_test.dart`. Leave them untouched. This task added only `tools/recreate_android_audit_avd.ps1` and `audit-evidence/emulator/` files. Do not start visual audit or modify app code.

Next: review/fix the script's SDK license path and screenshot/diagnostics handling, syntax-check it, correct `blocker.log`, and report the clean System UI ANR as the current infrastructure blocker. Do not run repeated GPU combinations without a new evidence-based reason. Stable Android environment acceptance is not yet met.
