# Evidence — Этап 1

Базовый SHA: `24f8d94` (origin/main). Режим: только документы.

## Статусы

| Проверка | Статус | Основание |
|---|---|---|
| Перебор 1 824 пар дата×диоцезия движком и загрузчиком | PASS (программно) | `enumerate_dates.dart.txt`, `enumeration-summary.md` |
| Маршруты `/prayers/songs`, `/prayers/compendium` | PASS (по коду router.dart) | матрица §5 |
| Три даты на Android (emulator-5554, API 34) | NOT TESTED | APK собран, `adb install` зависает: системные сервисы эмулятора недоступны после нехватки места; перезапуск эмулятора не выполнен |
| Три даты на iOS (iPhone 16, iOS 18.6) | NOT TESTED | сборка симулятора не завершена на момент записи |

Снимков экрана нет, пока статус не PASS с файлом снимка — считать NOT TESTED.

## Как воспроизвести

```bash
export PATH=/Users/gleb/.cache/flutter-3.41.4/bin:$PATH
# Android (эмулятор)
flutter build apk --debug --dart-define=PRIEST_USE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
# iOS (симулятор)
flutter build ios --simulator --debug --dart-define=PRIEST_USE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=localhost
```

Без `FIREBASE_EMULATOR_HOST` приложение остаётся на заставке (`main.dart:36`).
Даты: 2026-11-09, 2026-12-04, 2026-11-08 → «Чытанні» → «Іншыя варыянты».
