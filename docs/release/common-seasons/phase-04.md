# ФАЗА 04 — Android native (A1–A5) — отчёт исполнителя

**Дата (UTC):** 2026-10-30  
**Исполнитель/тестировщик:** Claude Code (сессия sc-flutter-qa)  
**Web HEAD:** `08b1283` (origin/main на момент проверки)  
**Flutter HEAD:** `57fe300` (origin/main, включает #41)  
**Branch / PR / CI:** `claude/sc-flutter-qa` / Draft PR (только отчёты и доказательства, код не менялся)

## Результат: **BLOCKED / NOT TESTED**

Факты окружения:
- Android SDK есть (`~/Library/Android/sdk`, adb, emulator), но системный образ только **API 36** (google_apis_playstore arm64); образа API 34 для `MyBrev_Test_API34` нет, скачивание ~1,5 ГБ не выполнялось.
- Существующие AVD (`analytics_test`, `lv_test`, `play_916`) принадлежат другим сессиям, не использовались.
- Попытка создать собственный AVD (копия образа) оборвалась: **на диске осталось 3,3 ГБ** (`No space left on device`); незавершённые файлы и каталог `build/` удалены. Gradle-сборка debug APK и userdata эмулятора требуют больше места.
- `adb devices`: устройств нет.

| ID | Итог |
|---|---|
| A1 | NOT TESTED (BLOCKED: нет места/эмулятора) |
| A2 | NOT TESTED (нужен старый совместимо подписанный APK) |
| A3 | NOT TESTED |
| A4 | NOT TESTED |
| A5 | NOT TESTED |

Шаги для человека (после освобождения ≥15 ГБ):
1. `flutter build apk --debug --dart-define=PRIEST_USE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2` (недостижимый эмулятор Firestore вместо production), Flutter 3.41.4.
2. Создать AVD Pixel 7 (API 34 или имеющийся API 36), включить airplane mode до установки, `adb install -r`.
3. A1: 19.10.2026 → «Пра законнікаў» → Час чтений/Ютрань; force-stop и повтор. A3: Ютрань → Нешпары → `adb shell input keyevent 4` ×3. A4: Гродно 04.12.2026, 09.11.2026, 05.12.2026. A5: dark/light + шрифт 180% + низ страницы. `adb logcat -b crash`.
Production: НЕТ. Код не менялся.
