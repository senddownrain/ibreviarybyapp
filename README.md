# Mybrev Flutter

Мобильная версия Mybrev — белорусского католического молитвенника. Приложение
содержит литургический календарь, Литургию часов, чтения, молитвы, избранное и
пользовательские настройки. Данные загружаются из Firebase Firestore и
кэшируются локально в Hive.

## Требования

- Flutter 3.41 или новее;
- Chrome для web-запуска;
- Android Studio / Android SDK и эмулятор либо физическое устройство для Android.

Проверить окружение:

```powershell
flutter doctor -v
flutter pub get
```

## Запуск в Chrome

```powershell
flutter run -d chrome
```

На Windows можно также запустить `run_in_chrome.bat`.

При первом запуске откройте **Налады → Сінхранізаваць**, чтобы загрузить полный
офлайн-кэш. Текущие литургический день и чтения подгружаются автоматически.

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

Проект содержит iOS-конфигурацию, однако собирать и запускать iPhone-версию
нужно на macOS с Xcode.
