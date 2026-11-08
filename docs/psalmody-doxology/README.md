# Полное славословие в bundle

Связанный Web PR: https://github.com/senddownrain/mybrev/pull/210

Это локальный кандидат бандла. Firestore, production contentManifest, правила, deploy и версия `pubspec.yaml` не изменены.

Исходная проблема и полный аудит: Web `docs/psalmody-doxology/README.md`. В `assets/content` исправлены те же 295 документов / 2 598 полей псалмодии: Templates 11/224, Proper 7/40, days 277/2 334. Чтения/гимны/молитвы не меняются. Дан 3, 57–88.56 сохранён; две альтернативы третьего заупокойного псалма имеют по одному окончанию. Камплета и Заклік уже правильны.

Расширен существующий `scripts/refresh_common_bundle.mjs` флагом `--psalmody-only`. Правила, исключения и HTML-правки импортируются из зафиксированного Web checkout. Нет отдельной копии алгоритма в Dart/UI. Состав документов и схема сохраняются; у исправляемых полей Templates/Proper берётся точный canonical HTML после проверки, что различие вне окончания ограничено пробелами между абзацами. Существующие ограничения allowlist сохранены.

Использованы реально прочитанные опубликованные `properTextsRevision=6` и `templatesRevision=4` (у старого bundle были 4/3); это штатное обновление двух полей `liturgicalCalendarMeta/current`, без изменения других ревизий. Версия коллекций и bundle рассчитана существующим механизмом времени Web commit, а не назначена вручную. Это подготовка к штатному app release; production-манифест не публикуется.

```sh
node scripts/refresh_common_bundle.mjs --web ../mybrev --allow-unmerged-web \
  --proper-revision 6 --templates-revision 4 --psalmody-only
# Проверить список changed; только затем те же аргументы и:
# --allow-text-drift <точные id из dry-run> --apply-bundle
node scripts/build_common_parity.mjs --web ../mybrev --allow-unmerged-web
# В Web:
npm run audit:doxologies -- --flutter ../ibreviarybyapp --check
```

`bundle-dry-run.json`, `bundle-applied-local.json`, `bundle-second-run.json` фиксируют исходные/целевые digest, id и поля. Повторный запуск — пустые changes. Parity oracle построен штатным `build_common_parity.mjs`: 19 сборок, включая 12.11.2026 Пінск с обоими Commons, 02.11 и торжество с I/II Нешпарамі. Flutter-тест учитывает диоцезию каждого случая и ожидаемый Te Deum.

Проверки в окружении с Flutter SDK:

```sh
dart format test/doxology_bundle_test.dart test/common_office_test.dart
flutter analyze --no-fatal-infos
flutter test test/doxology_bundle_test.dart test/common_office_test.dart \
  test/content_offline_test.dart test/ordo_content_update_test.dart \
  test/psalmody_html_modes_test.dart test/psalm_choir_html_test.dart
flutter devices
flutter run -d chrome -t tool/common_office_smoke.dart --web-port 5238
```

Добавлены проверки обеих заупокойных альтернатив и всех часов, двух Commons св. Язафата, Дан 3, обычного псалма и замещения старого локального overlay новым baseline с повторным открытием хранилища. Существующие ContentStore reconciliation/atomic-generation тесты включены в PR CI.

**Проверено в CI:** [Flutter PR checks, run 42455320175](https://github.com/senddownrain/ibreviarybyapp/actions/runs/42455320175) — форматирование, analyze, unit/widget, паритет и обновление старых локальных данных прошли. Отдельный реальный Chrome smoke выполняется в CI (`doxology-visual.yml`); его изображения ещё требуют просмотра.

**Локальное окружение:** Flutter SDK отсутствует (`flutter devices`: command not found), поэтому нельзя считать Dart/widget/analyze и Flutter Web visual smoke выполненными локально. Анализ и тесты выполнены на CI-раннере; визуальный smoke проверяется отдельно. Нативный smoke нужен перед релизом, а не для изменения платформенного кода (платформенный код не менялся).

Для визуальной приёмки использовать существующий offline harness, выбирать даты 12.11.2026 (Пінск), 02.11.2026 и воскресенье I недели, а также I/II Нешпары. Проверить 390px/desktop, светлую/тёмную тему, крупный шрифт, оба выбора Пс 146/150, переносы, красные знаки и чередование строф. Web-снимки из связанного PR не заменяют Flutter-снимки.

Публикация: уже изменение days 277/736 и 27.0 MiB документов превышает SAFE CONTENT PATCH. Production manifest отстаёт от live и ещё не включает Proper. Сначала отдельное разрешение на точечную запись Firestore с updateTime/readback; затем свежий snapshot, `content:app-release --compare-live`, штатный релиз приложения и отдельно согласованная публикация manifest. Не использовать override массового патча без владельца. Старый overlay уступает более новому baseline по существующему ContentStore; после повторной синхронизации текст не дополняется заново.
