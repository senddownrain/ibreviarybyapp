# Короткие источники молитв — Flutter companion

Web PR: https://github.com/senddownrain/mybrev/pull/259

Единственный справочник canonical source остаётся в Web `src/data/sourceBibliography.json`. Flutter читает готовое optional string поле `source`, не сокращает его и не создаёт собственный справочник. Библиография и copyright остаются на https://ibreviaryby.web.app/sources.

Модель Prayer теперь сохраняет source через fromMap, toMap и copyWith. Обычный reader и devotional office показывают простое примечание. Старые записи без source читаются без footer. English Mass использует `The Roman Missal`; полный существующий notice сохранён в Web source registry.

Штатный assets/content bundle, его manifest, schemaVersion, тексты молитв и литургические данные не изменены. Подготовленный в Web ignored backups кандидат prayers содержит 52 уверенные замены из 115 старых публичных записей и 63 спорных; это не release-ready bundle и не свежий snapshot.

Пакет PR #255 (7 791 поле / 749 документов) — отдельный Web-only слой. Его не следует считать уже опубликованным в Firestore или автоматически включать в shipped bundle. Конкретный порядок согласования Firestore/bundle/manifest, исключения 843 held и 406 уже опубликованных Proper, границы Advent и hashes: https://github.com/senddownrain/mybrev/blob/codex/unify-prayer-sources-20261116/docs/audits/prayer-sources-2026-11-16/FLUTTER_CONTRACT.md

## Проверки и release gate

Продолжение 2026-11-17: установлен Flutter 3.41.4 / Dart 3.11.1. Форматирование, analyze по CI-политике --no-fatal-infos и все 50 целевых тестов прошли, включая 6 source tests. Реальный Flutter Web проверен в Google Chrome: ordinary/office, 390px, light/dark 200%, прокрутка и ссылка. Скриншоты и логи: audit-evidence/prayer-sources/. Проверка установленного мобильного приложения и production-публикация не заявляются. Native smoke не требовался для данной общей UI-правки; перед мобильным релизом выполнить предусмотренный репозиторием отдельный smoke.

```sh
dart format lib/models/prayer.dart lib/widgets/prayer_content.dart lib/screens/prayer_detail_screen.dart test/prayer_source_test.dart
flutter analyze --no-fatal-infos
flutter test test/prayer_source_test.dart test/prayer_formatting_widget_test.dart test/mass_reader_test.dart
flutter devices
flutter run -d chrome -t tool/prayer_formatting_smoke.dart --web-port 5237
```

Chrome: обычная молитва и office, light/dark, крупный шрифт, мобильная ширина, прокрутка, ссылки; сохранить и просмотреть скриншоты. Только после этого согласовать app/bundle release. В данной задаче production-записей и manifest-публикаций нет.
