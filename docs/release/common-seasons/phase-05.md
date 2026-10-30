# ФАЗА 05 — iOS Simulator (I1–I4) — отчёт исполнителя

**Дата (UTC):** 2026-10-30  
**Исполнитель/тестировщик:** Claude Code (сессия sc-flutter-qa)  
**Web HEAD:** `08b1283` (origin/main на момент проверки)  
**Flutter HEAD:** `57fe300` (origin/main, включает #41)  
**Branch / PR / CI:** `claude/sc-flutter-qa` / Draft PR (только отчёты и доказательства, код не менялся)  
**Устройство:** iPhone 16, iOS 18.6 Simulator, `lib/main.dart`, `by.mybrev.testflight2026`, debug, Flutter 3.41.4, `--dart-define=PRIEST_USE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=localhost` (Firestore направлен на закрытый localhost — production не читается).

## Результат: **FAIL / BLOCKED** — приложение не стартует до экрана

| ID | Факт | Итог |
|---|---|---|
| I1–I4 | Сборка успешна (Xcode 477 с), но `main()` падает на `Firebase.initializeApp` (`main.dart:25`): `Unhandled Exception: [core/duplicate-app] A Firebase App named "[DEFAULT]" already exists`; перед этим FirebaseCore пишет «No app has been configured yet». Экран остаётся на сплэше (голубь), UI не появляется. Воспроизведено 3 раза: `flutter run` ×2 после чистой установки и автономный `simctl install/launch` | **BLOCKED** (I1–I4 NOT TESTED) |

Контекст: Flutter 3.41.4 при сборке автоматически мигрирует `ios/` на UIScene (`AppDelegate`, `Info.plist`, схема; правки откатаны `git checkout ios/`, в PR их нет). Параметры в `firebase_options.dart` совпадают с `GoogleService-Info.plist` (appId/sender/project/bucket). Причина не установлена; не проверено, воспроизводится ли это на немигрированном проекте/TestFlight-сборке (попытка прямого xcodebuild не завершена). P03 (24.10) на этом же симуляторе запускалось — вероятна регрессия после миграции/зависимостей; нужна отдельная диагностика. Критический NO GO для iOS-релиза до выяснения: проверить собранный TestFlight build.

Предложение узкого фикса (не применено, нужна диагностика): воспроизвести без UIScene-миграции; при подтверждении защитить инициализацию (`Firebase.apps.isEmpty` / try-catch duplicate-app) и добавить тест.

Доказательства: `phase-05/I-launch-stuck-splash-duplicate-app.png`, `phase-05/ios-sim-launch-log.txt`. Production: НЕТ. Код не менялся.
