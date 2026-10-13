# Beta releases: TestFlight and Google Play testing

Test identities (temporary, bound to their store entries — never rename):

| | iOS | Android |
|---|---|---|
| Store app | App Store Connect «MyBrev Test» | Google Play «MyBrev Test» |
| Id | `by.mybrev.testflight2026` | `by.mybrev.playtest2026` |
| Team / signing | `QYGFV6QH5U`; Apple Distribution certificate + App Store profile from the API key (no devices needed), Runner only, per build | upload key → Play App Signing |
| Firebase app | `1:344097781816:ios:e3feba9d3a782b7dfd8ecd` | `1:344097781816:android:92f6c24311cce114fd8ecd` |
| Destination | TestFlight (never App Store review) | `internal`, then closed testing «MyBrev Beta» (never production) |

The Android code namespace stays `com.example.mybrev_flutter`: it only names
the Kotlin/R classes, Google Play never sees it, and changing it would move
`MainActivity` for no gain.

## Locally (the developer Mac)

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH" LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
bundle config set --local path vendor/bundle && bundle install

bundle exec fastlane ios check          # API access + latest TestFlight build
bundle exec fastlane ios beta           # signed IPA → TestFlight
bundle exec fastlane android check      # service account + version codes in use
bundle exec fastlane android internal   # signed AAB → internal testing
bundle exec fastlane android tracks     # track ids (closed testing has its own)
bundle exec fastlane android beta       # → closed testing (ANDROID_BETA_TRACK)
```

A release refuses uncommitted changes (`ALLOW_DIRTY=1` overrides on
purpose). Build numbers come from the stores: next = highest uploaded + 1, and
never below the pubspec build number. `RELEASE_NOTES` sets the notes; without
it: «MyBrev beta build 1.0.0 (N) (commit)».

Local credentials (outside Git):

| What | Where |
|---|---|
| Android upload key | `~/.mybrev-release/upload-keystore.jks` + `~/.mybrev-release/key.properties`; copy the latter to `android/key.properties` (ignored by Git) |
| App Store Connect API key | `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_PATH` (the `.p8` file) |
| Google Play service account | `GOOGLE_PLAY_JSON_KEY_PATH` (the JSON file) |

**Back up `~/.mybrev-release/` (password manager / encrypted storage).** A
lost upload key can only be replaced through Google Play support.

## Как выпустить тестовую версию (кратко)

1. GitHub → **Actions** → **MyBrev Beta Release** → **Run workflow** (ветка `main`).
2. Выберите `platform` (both / android / ios), `android_track` (internal — по умолчанию; beta — закрытое тестирование), при желании `release_notes` — что проверить тестировщикам.
3. Нажмите **Run workflow** и дождитесь окончания (Android ≈ 15 мин, iOS ≈ 20–40 мин).
4. Откройте запуск → **Summary**: по каждой платформе `SUCCESS` / `FAILED` / `SKIPPED`, коммит, версия, номер сборки, канал, ссылка на консоль и, при ошибке, причина и следующий шаг.
5. Тестировщики ставят: Android — по ссылке-приглашению internal testing в Google Play; iOS — из приложения TestFlight. Пока `PLAY_RELEASE_STATUS=draft`, релиз Android нужно один раз раскатать вручную: Play Console → Internal testing → релиз → Roll out.

Запуск с другой ветки (проверка самого пайплайна) возможен только с `allow_non_main=true`.

## Through GitHub

`platform` (both / ios / android), `android_track` (internal / beta),
`release_notes`, `allow_non_main` (default false), `run_full_tests` (default
false). Manual only (`workflow_dispatch`): pushes and pull requests never
publish. The summary shows the commit, versions, build numbers and
destinations; iOS and Android report separately.

Pipeline: `prepare → quality → preflight-<platform> → <platform> → summary`.

| Job | Where | What it guarantees |
|---|---|---|
| `prepare` | ubuntu | the ref is a **branch tip**: `main` at the current `origin/main`, or another branch only with `allow_non_main=true`; the checkout equals the SHA of the run and is clean; track is `internal`/`beta`; the Flutter version is derived from `pubspec.yaml` and must agree with `codemagic.yaml` |
| `quality` | ubuntu | installed Flutter equals the pubspec requirement; `pub get --enforce-lockfile`; `flutter analyze --no-fatal-infos`; the quick tests |
| `preflight-android` | ubuntu | secrets present (names only), track/status allow-list, the upload keystore decodes and has the alias |
| `preflight-ios` | Mac runner | clean checkout, free disk, Flutter/Xcode/Java/fastlane on the runner, App Store Connect secrets present |
| `android` / `ios` | ubuntu / Mac runner | build exactly the SHA of the run; fastlane lane; `jarsigner` check of the AAB (no debug key); version code / build number is the store maximum + 1 and is **checked again right before the upload** |
| `summary` | ubuntu | per-platform verdict, runs `always()` |

A critical error in `prepare`, `quality` or a preflight stops everything
before signing and any store upload. Neither platform needs the other's
success: each has its own preflight and release job; `prepare`/`quality` only
judge the commit that both stores would receive.

**What does not block.** `flutter analyze --no-fatal-infos`: analyzer
*infos* (style hints, deprecations) are old and non-critical and do not stop
a test release; analyzer errors and warnings do (the tree has none today).
A single flaky info must not keep testers from a build, but a real error must.

**Tests.** By default the quick subset listed in
`tool/release/quick_tests.txt` runs (≈50 s, 169 tests): content offline/
migration, lectionary delivery/model/policy, liturgical calendar/resolution,
civil date, Mass reading sets, readings metadata, office assembly, routing and
app shell state, Ordo content/day flow, readings references. It covers what a
tester sees first (today's liturgical day and its readings) without the slow
parity suites (`*_parity_test.dart`, several minutes). Set `run_full_tests`
for the full `flutter test` before a significant release.

**Concurrency.** Android releases queue behind each other
(`mybrev-beta-release-android`), iOS releases behind each other
(`mybrev-beta-release-ios`); `cancel-in-progress: false`, so a running upload
is never killed. (GitHub keeps one pending run per group: a third dispatch
replaces a waiting second one.) Android and iOS never wait for each other.

**Build numbers.** next = highest number in the store + 1 (never below the
pubspec build number), computed at the start and re-checked right before the
upload; a number that has been taken meanwhile stops the release with
«Version code conflict» (just run it again).

**Production is impossible.** Allow-lists in the workflow, in
`tool/release/check_ref.sh` and in `fastlane/Fastfile`: Play track only
`internal` or `beta` (`ANDROID_BETA_TRACK` must not contain `prod`), release
status only `draft`/`completed`, and no lane calls App Store review or a
production rollout.

**Flutter version: one source.** `pubspec.yaml` `environment.flutter`
(`>=3.41.4`): the lower bound is what CI installs
(`tool/release/flutter_version.sh`). `prepare` fails with «Flutter version
drift» if `codemagic.yaml` pins another version, `quality` and
`preflight-ios` fail if the installed SDK differs. To move to a new Flutter:
edit `pubspec.yaml` and `codemagic.yaml`, nothing else.

Toolchain (checked against Flutter 3.41.4): Dart `^3.11.1`, Java 17 (AGP 8.11.1,
Gradle 8.14, Kotlin 2.2.20; compile/min/target SDK come from the Flutter
Gradle plugin), Ruby 3.4 + Bundler 2.6.9 (`Gemfile.lock`), fastlane ~> 2.240,
CocoaPods 1.16.2, Xcode 26.4 on the Mac.

Where it runs:

- **Android** — a GitHub-hosted Linux runner (`ubuntu-latest`): no Mac needed.
- **iOS** — the self-hosted runner with labels `self-hosted, macOS,
  mybrev-release` (the Mac must be on; Apple signing needs macOS). Check it
  first with **Release runner smoke test**. If the Mac is off, the iOS job
  waits in the queue (no timeout until a runner appears); Android and the
  summary are not affected. An optional variable `IOS_FLUTTER_BIN` points the
  runner to a Flutter 3.41.4 `bin/flutter` when its PATH has an older one.

Known failures and what the summary tells you: missing secret name · track not
allowed · stale branch/SHA · Flutter mismatch · keystore does not open · debug
signing · version code / build conflict · Play «draft app» (release must stay
`draft`; roll it out in the Console) · Play/App Store access denied · iOS
signing · build failure. The class is derived by
`tool/release/classify_failure.sh` from the fastlane log without ever printing
log lines into outputs.

### Secrets — repository secrets (names only; Settings → Secrets and variables → Actions; the private repo is on GitHub Free, so no Environments)

| Secret | Content |
|---|---|
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` | API key ids (App Manager) |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | `base64 -i AuthKey_XXXX.p8` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` | `base64 -i service-account.json` |
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/.mybrev-release/upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | from `~/.mybrev-release/key.properties` |

Repository variables: `ANDROID_BETA_TRACK` (closed testing track id
from `fastlane android tracks`), `IOS_TESTFLIGHT_GROUPS` (optional,
comma-separated), `IOS_FLUTTER_BIN` (optional), `PLAY_RELEASE_STATUS`
(`draft` until Google has reviewed the app once, then empty = `completed`).

Secrets become temporary files (0600) only for the run and are deleted when
fastlane exits; nothing is uploaded as an artifact; no step uses `set -x`;
GitHub masks secret values; the keystore check prints nothing from the file.

## Что должен сделать владелец репозитория для iOS (admin)

Нужны права admin на `senddownrain/ibreviarybyapp` (у `glebanya13` их нет:
`actions/runners` отвечает 404). Один раз:

1. **Раннер.** Settings → Actions → Runners → New self-hosted runner → macOS ARM64. На Mac:
   ```bash
   mkdir -p ~/actions-runner-mybrev && cd ~/actions-runner-mybrev
   # скачать и распаковать архив runner с указанной страницы, затем:
   ./config.sh --url https://github.com/senddownrain/ibreviarybyapp --token <TOKEN со страницы> \
     --name mybrev-mac --labels mybrev-release --work _work
   ./svc.sh install && ./svc.sh start && ./svc.sh status
   ```
   (метки `self-hosted` и `macOS` добавляются сами; нужна именно `mybrev-release`).
2. **Секреты iOS** уже добавлены в репозиторий (`APP_STORE_CONNECT_KEY_ID`, `_ISSUER_ID`, `_PRIVATE_KEY_BASE64`, 2026-10-13). Если нужно пересоздать (значения не публиковать):
   ```bash
   source ~/.mybrev-release/app-store-connect.env
   printf '%s' "$APP_STORE_CONNECT_KEY_ID" | gh secret set APP_STORE_CONNECT_KEY_ID --repo senddownrain/ibreviarybyapp
   printf '%s' "$APP_STORE_CONNECT_ISSUER_ID" | gh secret set APP_STORE_CONNECT_ISSUER_ID --repo senddownrain/ibreviarybyapp
   base64 -i ~/.mybrev-release/AuthKey_2NFRMNSHJU.p8 | tr -d '\n' | gh secret set APP_STORE_CONNECT_PRIVATE_KEY_BASE64 --repo senddownrain/ibreviarybyapp
   ```
3. **Flutter на Mac-раннере** должен быть 3.41.4 (`flutter --version` из сервиса, см. smoke-тест) либо задайте переменную `IOS_FLUTTER_BIN=/Users/<user>/.cache/flutter-3.41.4/bin/flutter`.
4. Запустите **Release runner smoke test**, затем MyBrev Beta Release с `platform=ios`. Сертификат Apple Distribution должен быть в связке ключей пользователя раннера (как на Mac разработчика).

Первый запуск на Mac-раннере делается из `~/.mybrev-release`-окружения владельца;
до этого iOS-сборки выпускаются локально: `bundle exec fastlane ios beta`
(TestFlight 8 и 9 загружены именно так).

## Google Play: первоначальная настройка (уже сделана)

Приложение «MyBrev Test» (`by.mybrev.playtest2026`) создано; сервис-аккаунт
подключён с правами на выпуск; ключ загрузки (upload key) создан, включён
Play App Signing; секреты Android лежат в репозитории; `PLAY_RELEASE_STATUS=draft`
(пока приложение не проверено Google, релиз остаётся черновиком и раскатывается
вручную в Play Console → Internal testing). Подтверждено: versionCode 10
загружен запуском GitHub Actions 38387005961 (ubuntu, Flutter 3.41.4).

## The runner after a reboot

The runner is installed as a launchd service (`./svc.sh install` in the runner
directory) and starts with the user session. Check / restart:

```bash
cd ~/actions-runner-mybrev && ./svc.sh status
cd ~/actions-runner-mybrev && ./svc.sh start
```

The service has its own PATH: `runner-smoke.yml` shows what it sees
(Flutter, Xcode, Java 17, Homebrew Ruby).

**Flutter version.** `pubspec.yaml` requires Flutter `>=3.41.4` (the single
source of truth, see above). The Mac that builds iOS needs
the same Flutter: either upgrade the Flutter on the runner's PATH, or keep a
second SDK and point the release at it, e.g.
`FLUTTER=$HOME/.cache/flutter-3.41.4/bin/flutter bundle exec fastlane ios`
(`fastlane/Fastfile` reads the `FLUTTER` environment variable; default
`flutter` from PATH). Check with `$FLUTTER --version` before a release.

## Known local issue

`flutter build appbundle` may end with «failed to strip debug symbols» on this
Mac: Android cmdline-tools 22.0 `apkanalyzer` cannot read the SDK registry, so
Flutter cannot verify the stripping. The bundle is fine; `fastlane android`
checks the same thing directly (`libflutter.so.sym` in `BUNDLE-METADATA`) and
stops on any other build failure.

## Codemagic

`codemagic.yaml` stays as a fallback (`ios-testflight`, debug builds, visual
audit) until the fastlane path has two successful iOS and two Android uploads.
