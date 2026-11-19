# Codex Cloud — MyBrev Flutter

This is the setup hand-off for a **private Codex Cloud environment** for `senddownrain/ibreviarybyapp`. This document and the linked script do **not** mean the environment has been created or published. Publication must be confirmed in the Codex Cloud interface.

## Proposed environment

- Name: `MyBrev Flutter`. Repository: `senddownrain/ibreviarybyapp`; branch: `main`.
- Keep the separate `senddownrain/mybrev` Web environment. Use the Web repo as reference only for parity tasks.
- Privacy: **Only me**. No signing keystore, Google Play credentials, production Firebase admin key, or release secrets.
- Make feature branches / Draft PRs only. No merge, store upload, Firebase production modification, or public release without the owner's explicit permission.
- Keep Android beta release signing/publishing in `.github/workflows/beta-release.yml` (GitHub Actions).

## Paste into Codex Cloud's initial setup conversation

> Prepare a private reusable Codex Cloud Linux environment for `senddownrain/ibreviarybyapp`. Do not edit app code, touch production Firebase, deploy, sign or publish. Resolve the Flutter version with `bash tool/release/flutter_version.sh` and `pubspec.yaml` (currently exactly 3.41.4); the README has older setup instructions. Install that Flutter SDK, its Dart SDK, Java 17 and Flutter/Dart dependencies. Ensure `flutter` is found in PATH on a **new cloud task**, not only in this setup shell. Prefer working Chrome/Web visual smoke capability; install Android command-line SDK tools only if this is feasible within setup limits, keeping debug APK support optional for the initial environment. Run `bash tool/cloud/flutter_preflight.sh --quick` and report actual results. Explain whether Chrome can be launched and screenshots captured; never claim visual verification from widget tests alone. Do not request production credentials. Save a tested install script and startup instructions for new tasks. If some tools fail, document the exact blocker and preserve a working Dart/Flutter test environment. Present the setup and allow owner review before Publish.

## Versions and verification

- Flutter SDK is pinned by `tool/release/flutter_version.sh`, currently **3.41.4**. `pubspec.yaml` requires `>=3.41.4 <4.0.0`.
- Java **17** for Android; Android Gradle wrapper **8.14**.
- `flutter pub get --enforce-lockfile` without changing the lockfile.
- `bash tool/cloud/flutter_preflight.sh --quick`: Flutter version, locked dependencies, analyzer, targeted widget test.
- `bash tool/cloud/flutter_preflight.sh --full`: entire Flutter test suite; run when scope warrants it.
- `bash tool/cloud/flutter_preflight.sh --apk`: debug APK only, requires Android SDK and licenses. Does not publish or release anything.
- `AGENTS.md` requires **actual Chrome visuals/screenshots** for shared UI changes and a native device check for native features/releases. Neither widget tests nor building an APK substitutes for these.
- iOS build requires macOS/Xcode and is outside the Linux cloud setup.

## Network configuration

Use the Codex Cloud **Package managers** preset first (includes GitHub, Gradle/Maven and some Google downloads). Add the exact hosts Flutter needs: typically `pub.dev` and `storage.googleapis.com`. For Android SDK, `dl.google.com` is included in the preset. If a download redirects elsewhere, add that exact host only when observed in setup logs. Test the downloaded dependencies during setup; avoid unrestricted internet and production secrets unless specifically authorized.

## Token-conscious routing and safety

- Heuristic, **not a proven token-spend ratio**: roughly **70% of routine fixes local**, **30% of substantial autonomous work in Cloud**.
- Local Codex: narrow Dart/UI changes, interactive debugging, smallest effective model. Cloud: complex multi-file work, Web/Flutter parity, substantial audits, autonomous Draft PR preparation.
- Run deterministic commands and GitHub CI without agent calls when possible. Start with targeted tests, avoid repeated full builds/logs, and escalate the model only when necessary.
- Local and Cloud Codex do **not** provide separate quota pools.

## Owner action to finish setup

1. Open Codex > **Work in > Cloud > Select environment > Create environment**, or **Settings > Codex Cloud > Environments > Create environment**.
2. Choose only `senddownrain/ibreviarybyapp`, select **Get started**, paste the setup prompt above and let Codex inspect dependencies.
3. Review installed tools, network restrictions, saved install/start scripts and preflight output. Select **Publish**.
4. Create a **new** task in `MyBrev Flutter`. Ask for read-only verification of Flutter/Java versions, locked dependencies, analyze/test output, Chrome/Android capability and `git status --short`. No source modifications.
5. If the new-task verification fails, **Edit > Republish** and validate in a new task.

Codex Cloud docs: https://developers.openai.com/codex/environments/cloud-environments
