# ФАЗА 09 — D‑1 во Flutter (выбор одного законного второго чтения) — отчёт исполнителя

**Дата и час (UTC):** 2026-10-30  
**Исполнитель/тестировщик:** Claude Code (сессия sc-d1-flutter); production Firestore / Hosting / магазины не затрагивались  
**Web HEAD:** `08b12838fcc7a737149dccd4225a043b6efcaec3` (origin/main, содержит WEB D‑1 #164)  
**Flutter HEAD:** ветка `claude/sc-d1-flutter` от `57fe300` (main после #41)  
**Branch / PR / CI:** `claude/sc-d1-flutter`, Draft PR (ссылка в описании PR); CI не ожидался на момент отчёта  
**Тестируемый build/package/version:** Flutter 3.41.4, Chrome (web-server) harness `tool/d1_reading_choices_smoke.dart`; iOS/Android не запускались

## 1. Содержание изменений

- **Контракт выбора (порт WEB `liturgicalAlternatives.js`, вид `office-reading`)** — `lib/utils/liturgical_alternatives.dart`: рубрика «Выбіраюцца найбольш адпаведныя тэксты …» — заметка (`reference`), а не чтение; границы выбора «Або іншае, пра …:» / «Іншае, пра …:»; заголовки вариантов (книга + стих, «Першае пасланне» + автор, произведение + автор отцов Церкви, лимит 84); `getReadingChoices()` → `{notes, options}`. Дополнительно `_textOf` теперь считает `<br>` пробелом, как веб-парсер (без этого заголовки вида «прэзбітэра(Nn. …)» расходились с WEB).
- **UI** — `lib/widgets/alternative_text.dart`, `lib/screens/ora_screen.dart`: заметка над переключателем; при одном варианте переключателя нет; выбранный вариант показывается ОДИН целиком (без склейки), подпись «Чытанне · N з M»; существующий bottom-sheet Flutter (не смешан с «Іншыя варыянты дня»).
- **Память выбора** — новый `lib/utils/reading_choice.dart`: по полю + дата + id варианта Часа (+ диоцез), в памяти сессии приложения, не в Hive; смена дня/периода/диоцеза/Proper↔Common/поля или число вариантов меньше сохранённого индекса → вариант по умолчанию. Тот же контракт, что `readingChoice.js`; диоцез добавлен в контекст как более строгий.
- **Данные в bundle** — `scripts/refresh_common_bundle.mjs` (оффлайн, `--web ../mybrev`, WEB `08b1283`): бандл был старше WEB (dry-run: `holy-women` R1/R2/`_seasonalVariants`, Proper `22-10-sv-john-paul-ii`). Применено с `--allow-text-drift holy-women,22-10-sv-john-paul-ii`; digest `liturgicalTemplates` `fd4b4f8eac9c9902` → `316b5f1487846faf`. **`--templates-revision 3 --proper-revision 4` взяты из прежнего бандла: реальные опубликованные ревизии (после #165/#166) без чтения production неизвестны — release manager должен проставить их перед выпуском.**
- **Parity-оракулы** пересобраны от WEB main оффлайн: `scripts/build_common_parity.mjs --full` (`common_office_parity.json`, `office_assembly_parity.json`, `ordo_parity.json.gz`); новый `scripts/build_reading_choices_parity.mjs` → `test/fixtures/reading_choices_parity.json` (386 полей Common/Proper, только хеши). Ожидаемые digest в `test/common_office_test.dart` обновлены.
- **Pius XII** — только там, где печатает том III: в I/II (сезонные варианты) его нет; тест это проверяет.
- Осознанно НЕ затронуто: текст литургии (не писался ИИ), Firestore/manifest/Hosting/магазины, «Іншыя варыянты дня», Hive, `pastors_hymn_parity.json` (см. §4).
- Защита параллельной работы: отдельный worktree `ibreviarybyapp-d1`; правки общего кода узкие; чужие файлы не менялись.

## 2. Автоматические тесты

| Команда | Итог | Счётчик/exit code | Лог |
|---|---|---|---|
| `flutter test test/reading_choices_test.dart` (новые: 10 по томам, parity 386 полей = 0 расхождений, память, D1-F1/F2/F3/F5, 320px/180%/dark/semantics) | PASS | 18/18 | локально |
| `flutter test test/hours_parity_test.dart` (Web↔Flutter, 2025–2035 × 4 диоцеза) | PASS | 0 расхождений (после обновления оракула) | локально |
| `flutter test` (полный, concurrency 4) | 2 FAIL → исправлено → повторены затронутые | было +1480 −2: `common_office_test` (старые digest) и `pastors_hymn_web_parity_test` (см. §4); после правки digest `common_office_test`, `pastors_hymn_web_parity_test` (старая фикстура), `reading_choices`, `alternative_text`, `liturgical_alternatives` — 38/38 PASS | локально |
| `flutter analyze --no-fatal-infos` | PASS | 12 info (все старые: `pastors_hymn.dart`, `consent_mock_test.dart`), 0 error/warning | локально |

Полный `flutter test` целиком после последней правки digest отдельно не перезапускался (первый прогон завис после обрыва сессии; второй — выше). Остальные ~1480 тестов были зелёными во втором прогоне до правки digest, которая затрагивает только константы в одном тесте.

## 3. Реальные UI проверки

Chrome (Flutter web, 390×844), офлайн-бандл. Картинки: `docs/release/common-seasons/phase-09-screens/`.

| ID | На чём | Что нажато | Что увидел (ФАКТ) | Ожидалось | Итог | PNG |
|---|---|---|---|---|---|---|
| D1-F1 | Chrome 390 px, Жанна Франсуаза 12.08.2026 (Common `holy-women`, Звычайны перыяд), Час чытанняў | открыл «Чытанне · 1 з 5» → вариант 4 «Кніга Прыпавесцяў 31, 10-31» | заметка «Выбіраюцца … с. 1580-1583», подпись «Чытанне · 4 з 5»; показан один текст («Іншае, пра святую, якая жыла ў сужэнстве» + Прып 31), остальные не подряд | один B, правильный заголовок/источник | PASS | `d1-f1-1…3` |
| D1-F2 | то же | выбор B → смена часа/назад | **Не проверено на экране** (перезагрузка harness сбрасывает память сессии); логика проверена widget-тестом (push/pop Navigator: B сохраняется) | B сохраняется в контексте, Back не ломается | PASS (widget) / NOT TESTED (экран, Android Back) | — |
| D1-F3 | Chrome, Моника 27.08.2026 (собственные R1/R2) | открыл Час чытанняў | собственное чтение «Споведзь» Аўгустына, без Common-переключателя; другие день/диоцез/поле/Proper сбрасывают выбор (widget) | Proper приоритетнее, B не протекает | PASS | `d1-f3-…` |
| D1-F4 | офлайн bundle | harness без сети (`isOfflineProvider=true`), бандл из assets | тексты читаются, ошибок декодирования нет; **обновление поверх старой версии на устройстве не проверялось** | нет ошибки, настройки сохранены | PASS (offline) / NOT TESTED (update поверх) | — |
| D1-F5 | Chrome 390 px, dark + крупный шрифт; widget 320 px, ×1.8, dark | прокрутка к чтению; тест семантики | читаемо, без обрезания; Semantics «Выбар чытання» + «Чытанне · 1 з 3 …»; все варианты достижимы скроллом листа | читаемые варианты, доступные labels | PASS (Chrome/widget) | `d1-f5-dark-180.jpg` |
| Android / iOS / TalkBack / VoiceOver | — | — | не запускались | — | **NOT TESTED** | — |

Замечания по виду: текст заметки показан красным (стиль рубрики), в WEB — обычный цвет с акцентной полосой; на усмотрение владельца.

## 4. Найденные ошибки → исправления → повторная проверка

| Ошибка | Корень | Fix | Повтор | Результат |
|---|---|---|---|---|
| Заголовки вариантов расходились с WEB («…прэзбітэра(Nn. …)») | `_textOf` не превращал `<br>` в пробел | `<br>` → пробел | parity 386 полей | 0 расхождений |
| `hours_parity_test` красный на старом бандле | бандл отставал от WEB (holy-women, JPII) | обновление бандла + оракулов оффлайн | `hours_parity_test` | PASS |
| **НЕ исправлено (вне D‑1):** `pastors_hymn_web_parity_test` красный на оракуле от WEB main | WEB `src/utils/pastorsHymn.js` на main упрощён после WEB-коммита, от которого собрана фикстура Flutter #41 (`edb3a2b`, не на main): `transformed` 2000 → 400 | фикстура оставлена прежняя (зелёная), расхождение Flutter↔WEB main зафиксировано | — | **ОТКРЫТО**: нужно решение, какое поведение гимна Pastors каноническое |

## 5. Production/магазинные операции

- Совершались? **НЕТ**. Firestore не читался и не писался, Hosting/магазины/merge не выполнялись.
- Ревизии `templatesRevision`/`properTextsRevision` в бандле — старые (3/4), реальные значения неизвестны.

## 6. Результат и следующий шаг

**Вердикт:** PASS по коду, тестам и Chrome-проверке D1-F1/F3/F5 · NOT TESTED: Android/iOS-устройства, Android Back на устройстве, обновление поверх старой версии, TalkBack/VoiceOver, экранная проверка D1-F2 · ОТКРЫТО: pastors hymn parity.

**Что осталось и кто продолжает:** (1) реальная проверка на Android/iOS (D1-F2/F4/F5); (2) решить расхождение Pastors hymn (Flutter#41 vs WEB main) и пересобрать фикстуру; (3) release manager: выставить реальные ревизии бандла, отдельный beta-релиз.  
**Запрос от release manager (не QA):** разрешение на сборку/Play alpha/TestFlight и реальные `templatesRevision`/`properTextsRevision`.  
**Следующая фаза:** фаза C (бета и manifest) после приёмки.
