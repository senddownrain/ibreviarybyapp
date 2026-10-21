# Common: соответствие опубликованному Web

Эталон: `senddownrain/mybrev`, production commit
`0612d534cacbc847ab6c6b7e0102137333f07211` (PR #141, #145).
Ветка Flutter: `codex/common-office-web-parity`.

## Аудит до реализации

| Web | Flutter до изменения | Недостающее поведение / результат |
| --- | --- | --- |
| `fetchProperTexts` → `liturgicalProperTexts` | `ContentStore`, `LiturgicalContentService._properById`, приоритет Proper перед legacy `days` | Доставка предусмотрена кодом и bundle содержит 291 Proper; опубликованный manifest эту коллекцию не включает |
| `assemblyChoices` | `assemblyChoices`, `DayTemplate`, существующий picker | Порядок «З дня» / Common и идентичность выбора уже поддерживаются |
| `assembleOffice`, `commonBaseRule` | `office_assembly.dart` | Не было праздничной сборки трёх основных часов, разрешённой базы, строгой диагностики пропущенной базы |
| `_commonBase`, `_templates` | Raw map модели `LiturgicalDay` сохраняет вложенные поля | Bundle ревизии 2 не содержал опубликованные 29 привязок в 27 документах |
| `_fieldRules` | Правила `source`, `ref`, `omit`, `allowCurrentDay` уже разбирались | В 159 bundled Proper отсутствовали актуальные опубликованные правила; Common `omit` требовал поддержки |
| `seasonalTemplateGetter` | `computeSeason` уже есть, сборщик использовал плоские шаблоны | Добавлена локальная материализация сезонного Common, включая базовый; сезон выбранного дня передаётся из сервиса |
| Sunday Week I | `sunday-week-1` в `liturgicalTemplates` | Источник уже доступен; теперь используется при праздничной Ютрані, после Proper / явного правила |
| Te Deum | `shouldShowTeDeum` возвращал `false` для memorial | Учтён локальный `festiveCommon` без изменения ранга |
| Invitatorium | Общий слот антифоны, отдельный выбор пригласительного псалма в `OraScreen` | Proper → выбранный Common сохранён; механизм выбора псалма не менялся |
| Web cache revisions | Bundle + Hive overlay; manifest hashes/digests; `ContentStore.revision` → providers | Flutter обновляется по manifest, а не по одному `properTextsRevision`; изменение ревизии в Firestore само по себе не доставляет Proper |

Получение temporal-документов, Ordo, диоцезов и выбор дня остаются в
`LiturgicalContentService` / существующем picker. Собранные часы не записываются
в общий кеш: сборка заново использует документы конкретного дня, диоцеза и
выбранный Common. Route ID содержит вариант; session override привязан к дате
и диоцезу. ContentStore инвалидирует результаты после обновления источников.

## Данные и доставка

Адресная read-only сверка 20 октября 2026 года подтвердила:

- Proper: 291 документ, `properTextsRevision = 4`, digest `16c87c1e79df5370`;
- Common: 16 документов, `templatesRevision = 3`, digest `fd4b4f8eac9c9902`;
- доступны `holy-men`, `holy-women`, `religious`, `educators`, `works-of-mercy`,
  Sunday Week I; 13 Common содержат сезонные варианты;
- локальные публичные исходники Web совпадают с live Proper по хешам;
- опубликованный manifest не содержит Proper и метаданные календаря.

Bundle обновлён адресно, только в трёх коллекциях:

- `liturgicalProperTexts`: 168 документов с изменениями метаданных/правил
  (159 `_fieldRules`, 27 `_commonBase`, с пересечением), 0 добавлений/удалений;
- `liturgicalTemplates`: 13 обновлённых документов, 0 добавлений/удалений;
- `liturgicalCalendarMeta/current`: ревизии Proper 4, Common 3.

Ни одно собственное текстовое поле Proper не изменено: refresh-скрипт
сравнивает все поля, кроме `_commonBase`, `_fieldRules` и bookkeeping, и
отказывается работать при расхождении. Это существующие тексты и формуляры,
без сочинения или переноса текстов между ними. Common сверены с опубликованным
digest. Изменения `readings`, `prayers` и прочих коллекций в bundle не включены.

Офлайн-доставка теперь обеспечена новой установкой / обновлением приложения.
Формат bundle и публичный контракт manifest не меняются. Старая overlay-версия
уступает новой baseline своей коллекции; более свежая остаётся. Настройки и
личные данные не очищаются. Будущие патчи по-прежнему атомарно проверяются и
активируются существующим `ContentUpdater`.

Скрипты без сетевых обращений:

```powershell
node scripts/refresh_common_bundle.mjs --web ../mybrev --publication <publication-after.json>
# После проверки dry-run: тот же запуск с --apply-bundle (только локальные assets).
node scripts/build_common_parity.mjs --web ../mybrev --full
```

Refresh закреплён за production commit и проверенными digest. Входной backup
остаётся вне Git; полные приватные snapshots и credentials не копируются.
`scripts/audit_common_delivery.mjs --web ../mybrev` — отдельный явно запускаемый
read-only сетевой аудит: читает только публичные Proper, current meta и manifest.

## Правила сборки

«З дня» сохраняет прежнюю ветку сборки. Выбор Common для memorial / optional
memorial включает праздничный формуляр только в Гадзіне чытанняў, Ютрані и
Нешпарах. Приоритет: собственный текст → собственное структурное правило →
выбранный Common → разрешённая база. Псалмы Ютрані по умолчанию берутся из
Sunday Week I. Собственные чтения, респонсории (в исходных полях чтений),
коллективные формулировки и молитвы сохраняются. Единственная молитва святого
в `laudesPr` используется и для `officeOfReadingsPr`, как в Web.

`commonBaseRule` применяется только к religious, educators, works-of-mercy:
сначала явная `_commonBase`, затем подтверждённые структурные Common bindings
(pastors/holy-men; virgins/holy-women). Противоречивые, отсутствующие,
недопустимые и title-inferred привязки диагностируются. Имена, пол по имени,
ID святого и произвольные тексты не используются. Пробелы в обязательных
источниках остаются пустыми с `_integrityErrors`; будничного fallback нет.

Сезонные `string`, `array`, `null` и `{rule}` материализуются в отдельную карту
на одну сборку. Локальные кеши Common не мутируют. Поддержаны `_mainSection`
марианского Common и исключение для субботнего воспоминания согласно Web.
Te Deum учитывает явный запрет / собственное значение, затем festive Common.
Календарный ранг, малые часы, Комплеторий и право на первые Нешпары не меняются;
праздничный вариант не создаёт текстов первых Нешпараў.

## Проверки

- Web parity: 16 068 дней (2025–2035, 4 диоцеза), 37 738 сборок;
  **0 расхождений структуры, 0 расхождений текстов**.
  Отчёт: `reports/flutter-hours-parity.json`.
- Адресный oracle: 15 вариантов на реальных Proper A–F, хеш каждого поля,
  provenance, missing, integrity, Te Deum; в тестовом файле нет копий текстов.
  Павел Креста 19.10.2026, Франциск 04.10.2027 (в 2026 году эта дата —
  воскресенье), Клара 11.08.2026, сервиты 17.02.2026, Альжбета Португальская
  (works-of-mercy), Ангела Меричи (educators).
- Локальные тесты ошибок метаданных, приоритета Proper, отсутствующих
  Common/Sunday Week I, refs, сезонного наследования и отсутствия мутаций;
  сохранение выбора при переходах дат/часов и изоляция диоцезов.
- Кеш: новая baseline заменяет старые Proper/Common overlays без удаления
  настроек; регрессионные тесты atomic update / offline / crash recovery.
- **101 unit/widget и регрессионный тест прошёл** (последовательный запуск):

  ```powershell
  flutter test --no-pub --concurrency=1 --timeout 2m test/common_office_test.dart test/office_assembly_test.dart test/ordo_content_update_test.dart test/content_offline_test.dart test/hours_regression_test.dart test/hours_root_test.dart test/liturgical_resolution_test.dart test/ordo_picker_test.dart
  ```

  Отдельный `flutter test --no-pub --concurrency=1 --timeout 15m test/hours_parity_test.dart`
  также завершился успешно. Первый параллельный прогон offline-тестов дал
  таймауты стандартных 30 секунд; повторный последовательный прогон с лимитом
  2 минуты завершён без ошибок. Ограничения проверок не ослаблялись.
- `dart format`; анализ затронутого кода — **No issues found**.
- `flutter build apk --debug --no-pub` — **успешно**.
- Native smoke: не выполнялся; эмулятор не запускался, нативные зависимости
  не менялись. Отдельный native smoke обязателен перед мобильным релизом.

Chrome visual smoke **частичный, не считается завершённым**. `flutter devices`
подтвердил Chrome, затем запущен ровно один экземпляр:

```powershell
flutter run -d chrome -t tool/common_office_smoke.dart --web-port 5238
```

Проверен точный URL `http://localhost:5238/` через CDP запущенного Flutter
Chrome. Сохранены и просмотрены реальные снимки главного экрана 19.10.2026
и существующего picker со всеми тремя вариантами, включая выбор пастырей:
`audit-evidence/common-office/01-hours-light.png`, `02-picker-light.png`,
`03-picker-pastors.png`. Затем инструмент Computer Use остановил управление:
он не смог достаточно уверенно определить URL окна для enforcement политики.
Дальнейшие UI-действия прекращены. Не проверены визуально документы трёх часов,
Invitatorium, тёмная тема, крупный шрифт, мобильная ширина, прокрутка/ссылки и
переходы между часами. Сборка и widget-тесты этот пробел не заменяют.
Офлайн harness использует production screens/router/picker и публичный bundle,
Firebase в нём не инициализируется. Параметры `?theme=dark&scale=large`
позволяют воспроизвести недостающие состояния.

## План серверной доставки и релиза (не выполнен)

Firestore/Hosting, магазины и manifest в этой задаче **не публиковались**.
Merge не выполнялся. После проверки Draft PR и visual/native smoke:

1. Выпустить Flutter с обновлённым bundle. Проверить установку и обновление
   поверх старого кеша на целевых Android/iOS.
2. Повторить строго адресный dry-run в Web checkout:

   ```powershell
   npm run content:manifest -- --collection liturgicalProperTexts --collection liturgicalCalendarMeta --introduce-collections
   ```

   Фактический dry-run этой задачи: 291 Proper + 1 meta, 0 изменений и
   0 удалений существующих документов; другие коллекции сохранены.
   Evidence: `audit-evidence/common-office/scoped-manifest-dry-run.json`.
3. Отдельно авторизованная публикация владельцем — та же команда с `--apply`,
   только после повторной проверки diff. Не запускать общий manifest apply,
   `--allow-large-patch`, массовую синхронизацию или удаление документов.
   Не включать известные посторонние расхождения
   `readings/ordinary-w29-d1--A` и `prayers/0AAlyUXOjOtzbPdt3Gql`.
4. Проверить, что contentManifest/current содержит эти две коллекции, а их
   digest совпадает с release bundle. После этого будущие изменения Proper
   доставляются обычными проверенными патчами; одно увеличение метаревизии
   без публикации manifest недостаточно.
