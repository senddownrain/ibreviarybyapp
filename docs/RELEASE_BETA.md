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

## Through GitHub

GitHub → Actions → **MyBrev Beta Release** → Run workflow:
`platform` (both / ios / android), `android_track` (internal / beta),
`release_notes`. Manual only; one run at a time; the summary shows the commit,
versions, build numbers and destinations; iOS and Android report separately.

Runs on the self-hosted runner with labels `self-hosted, macOS,
mybrev-release` (this Mac). Check it first with **Release runner smoke test**.

### Secrets — environment `beta` (names only)

| Secret | Content |
|---|---|
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` | API key ids (App Manager) |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | `base64 -i AuthKey_XXXX.p8` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` | `base64 -i service-account.json` |
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/.mybrev-release/upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | from `~/.mybrev-release/key.properties` |

Variables of the environment: `ANDROID_BETA_TRACK` (closed testing track id
from `fastlane android tracks`), `IOS_TESTFLIGHT_GROUPS` (optional,
comma-separated), `PLAY_RELEASE_STATUS` (`draft` until Google has reviewed the
app once, then empty = `completed`).

Secrets become temporary files (0600) only for the run and are deleted when
fastlane exits; nothing is uploaded as an artifact or printed.

## The runner after a reboot

The runner is installed as a launchd service (`./svc.sh install` in the runner
directory) and starts with the user session. Check / restart:

```bash
cd ~/actions-runner-mybrev && ./svc.sh status
cd ~/actions-runner-mybrev && ./svc.sh start
```

The service has its own PATH: `runner-smoke.yml` shows what it sees
(Flutter, Xcode, Java 17, Homebrew Ruby).

## Known local issue

`flutter build appbundle` may end with «failed to strip debug symbols» on this
Mac: Android cmdline-tools 22.0 `apkanalyzer` cannot read the SDK registry, so
Flutter cannot verify the stripping. The bundle is fine; `fastlane android`
checks the same thing directly (`libflutter.so.sym` in `BUNDLE-METADATA`) and
stops on any other build failure.

## Codemagic

`codemagic.yaml` stays as a fallback (`ios-testflight`, debug builds, visual
audit) until the fastlane path has two successful iOS and two Android uploads.
