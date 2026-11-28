# Mybrev Flutter

Мобильная версия Mybrev — белорусского католического молитвенника. Приложение
содержит литургический календарь, Литургию часов, чтения, молитвы, избранное и
пользовательские настройки. Данные загружаются из Firebase Firestore и
кэшируются локально в Hive.

## Требования

- **Flutter 3.38.9** (ровно эта ветка 3.38.x). В более новых версиях Flutter класс
  `IconData` стал `final`, и библиотека иконок `phosphor_flutter 2.x` не компилируется.
  Ограничение записано в `pubspec.yaml`, на другой версии `flutter pub get` сразу
  сообщит об ошибке. Codemagic собирает на той же версии;
- Chrome для web-запуска;
- Android Studio / Android SDK и эмулятор либо физическое устройство для Android.

Проверить окружение:

```powershell
flutter doctor -v
flutter pub get
```

Переключить Flutter на нужную версию (если Flutter установлен через git):

```bash
cd "$(dirname "$(which flutter)")/.." && git fetch --tags && git checkout 3.38.9 && flutter --version
```

## Запуск на iOS-симуляторе (macOS)

Нужны Xcode и CocoaPods.

```bash
flutter pub get
cd ios && pod install --repo-update && cd ..
open -a Simulator
flutter run
```

Если `pod install` падает с `Unicode Normalization not appropriate for ASCII-8BIT`,
терминал не в UTF-8. Добавьте в `~/.zshrc` строку `export LANG=en_US.UTF-8` и откройте
терминал заново.

Если сборка падает на подах или на `phosphor_flutter`, сначала проверьте
`flutter --version` (должно быть 3.38.9), затем выполните полную очистку:

```bash
flutter clean && flutter pub get
cd ios && rm -rf Pods && pod install --repo-update && cd ..
```

Первая сборка под iOS занимает 10–15 минут.

## Запуск в Chrome

```powershell
flutter run -d chrome
```

На Windows можно также запустить `run_in_chrome.bat`.

Правила проверки UI — [Chrome-first в AGENTS.md](AGENTS.md): логика проверяется
unit/widget-тестами, общий UI — также визуально в Chrome; нативные функции
и мобильный релиз требуют проверки на соответствующем устройстве.
Изолированный экран для проверки форматирования молитв:
`flutter run -d chrome -t tool/prayer_formatting_smoke.dart --web-port 5237`
(локальный URL `http://localhost:5237/`). Проверенный контракт чтения молитв: [MyBrev 1.1 и Chrome-снимки](docs/prayer-formatting-parity-1.1.md).

Все тексты (Литургия часов, чтения, молитвы, Библия, Спеўнік, Кампендый)
входят в приложение и работают без сети с первого запуска. Сеть нужна только
для проверки обновлений текстов (раз в сутки, один маленький документ) —
см. `docs/data-loading-architecture.md`.

## Запуск на Android

Посмотреть устройства и эмуляторы:

```powershell
flutter emulators
flutter devices
```

Запустить установленный эмулятор и приложение:

```powershell
flutter emulators --launch Pixel_5_API_34
flutter run -d emulator-5554
```

Идентификатор устройства может отличаться — используйте значение из
`flutter devices`.

## Проверки

```powershell
flutter test
flutter analyze
flutter build web
flutter build apk --debug
```

Debug APK создаётся в `build/app/outputs/flutter-apk/app-debug.apk`.

## iOS

Провайдеры App Check и проверки подписанных релизов описаны в [инструкции](docs/firebase-app-check.md).

Проект содержит iOS-конфигурацию, однако собирать и запускать iPhone-версию
нужно на macOS с Xcode.
