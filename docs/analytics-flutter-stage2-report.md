# Отчёт: Flutter, локальная аналитика, этап 2 (контракт v2), 2026-10-16

Ветка `feature/analytics-stage2` (от `feature/analytics-local`, PR #15 слит). Коммит `93918e2`.
Статус: **локальный счёт только в тестовых сборках (`--dart-define=ANALYTICS_LOCAL=true`), сети нет и она не реализована.**
D-10 = B, региона нет: всё `UNKNOWN`. Источник контракта: веб `mybrev`, PR #128 / #129 (оба не слиты), `docs/analytics-contract.md` §16.

## 1. Что сделано

- Порт контракта **v2** (`schema_version = 2`): `reading:day`, событие `catalog_open`, каталоги, части компендиума `comp:p1…p4`. Эталон `analytics-contract-v2.json` и инвентарь (750 ID) взяты из веба. `vespers → vesper` сохранено.
- **Длина текста и `er`:** общий `ReaderScaffold` считает отрисованный текст в памяти (`reader_hooks.dart`) и сообщает только длину. Текст не сохраняется. Если надёжной длины нет, `er` не создаётся, `fv` и `sd` остаются.
- **Прокрутка:** учитывается вертикальная прокрутка самой читалки. Текст, помещающийся на экран, даёт `sd=fit`; признак сбрасывается, если текст позже стал длиннее. Загрузка и «не найдено» чтением не считаются.
- **`feature_use`:** подключено **13 из 27** id (только id, без значений): `theme_change`, `text_scale_change`, `font_family_change`, `keep_screen_on_toggle`, `psalmody_layout_change`, `favorite_add`, `favorite_remove`, `chords_toggle`, `bible_language_change`, `bible_chapter_nav`, `mass_language_change`, `share_use`, `back_to_top`. Не подключены: `search_*` (нет отдельного действия «отправить поиск» без строки), `date_pick`, `picker_open`, `hour_switch`, `hour_option_select`, `text_settings_open`, `copy_use`, `chord_transpose`, `chord_layout_change`, `mass_section_nav`, `ordo_diocese_change`, `offline_update_apply`, `install_prompt_open` (веб-специфична).
- Исправления, найденные только на устройстве: экраны, открытые через `context.push`, не распознавались (адрес брался со страницы под ними); открытый визит терялся при убийстве приложения в фоне (теперь снимок включает открытый визит); Библия из вкладки считалась каталогом.

## 2. Проверки

| Проверка | Результат |
|---|---|
| `flutter analyze`, **Flutter 3.41.4** | No issues found |
| `flutter test`, Flutter 3.41.4 | 1349 пройдено, 1 пропущен, 0 упало |
| Фикстуры v2 и инвентарь | совпадают с веб-версией |
| Реальная сборка `lib/main.dart`, release APK (подпись debug) | без флага в `libapp.so` **нет** строк аналитики (`analytics_local_v1`, `catalog_open`, `reading:day`, ID инвентаря); с флагом есть |
| Размер APK | без флага 80 236 038 Б; с флагом 80 514 566 Б (**+278 528 Б, +0,35 %**); три сборки подряд дали идентичные размеры (сборка детерминирована по размеру) |
| Эмулятор Android (клон AVD, debug, флаг включён, контент из бандла приложения) | получены агрегаты ниже; признаков user/device/uuid/session/install в сохранённых данных нет; размер буфера Hive-снимка 2 759 Б (лимит 64 КиБ) |

Агрегаты с эмулятора (один прогон, один день, `region=UNKNOWN`, `platform=android`): `screen_view today`; `hours: hour:laudes, hour:invitatorium` — `fv`, `sd`, `er`; `readings: reading:day` — `fv`, `sd`, `er`; `mass: mass:order` — `fv`, `sd`, `er`; `songs: song:holysongs-…` — `fv`, `sd`, `er`; `compendium: comp:p1` — `fv`, `sd=fit`, `er`; `catalog_open`: `prayers_home`, `songs`, `compendium_home`, `bible_books`.

## 3. Матрица: экран × событие × `fv` × `sd` × `er` × `feature_use`

Столбец «Проверено»: **E** = наблюдалось на эмуляторе Android; **T** = покрыто тестом маппера/коллектора; **—** = не проверялось на устройстве.

| Экран / маршрут | section · content_id | `screen_view` | `fv` | `sd` | `er` | Проверено |
|---|---|:-:|:-:|:-:|:-:|:-:|
| «Сегодня» `/hours` | `today` | да | нет | нет | нет | E, T |
| Час `/hours/ora/…/laudes` и др. | `hours · hour:<id>` (`vespers`→`vesper`) | да | да | да | да | E (laudes, invitatorium), T; vesper/прочие часы T |
| Чтения `/readings`, `/readings/reading/…` | `readings · reading:day` (без даты) | да | да | да | да | E, T |
| Молитва `/prayers/prayer/:id` | `prayers · prayer:<id>` (только публичные ID из инвентаря) | да | да | да | да | T; на устройстве **—** |
| Месса (молитва порядка Мессы) | `mass · mass:order` | да | да | да | да | E, T |
| Песня `/prayers/songs/:id` | `songs · song:<id>` | да | да | да | да | E, T |
| Компендиум, часть `/prayers/compendium/part/pN` | `compendium · comp:pN` | да | да | да (`fit` наблюдался) | да | E, T |
| Компендиум, узел `/node/:id` | `compendium · comp:<id>` | да | да | да | да | T; узлы на устройстве **—** |
| Библия, глава `/bible?version&book&chapter` | `bible · bible:<bel|ru>:<book>` | да | да | да | да | T; на устройстве **—**, `ru` не подтверждена |
| Каталоги: молитвы, все, избранное, песни, компендиум, Библия-книги, список часов | `catalog_open{catalog_id}` | нет (отдельное событие) | нет | нет | нет | E (4 из них), T |
| Настройки, О приложении, Ordo, выбор даты | `settings`, `about`, `ordo`, `picker` | да | нет | нет | нет | T; на устройстве **—** |
| Список, поиск, личные и священнические молитвы, неизвестные маршруты | не измеряются | нет | нет | нет | нет | T |

`feature_use` (подключено, только id): `theme_change`, `text_scale_change`, `font_family_change`, `keep_screen_on_toggle`, `psalmody_layout_change` (настройки); `favorite_add`, `favorite_remove` (молитвы и песни); `chords_toggle` (песни); `bible_language_change`, `bible_chapter_nav` (Библия); `mass_language_change` (Месса); `share_use` (чтения); `back_to_top` (читалка). Проверено на устройстве: **—** (только юнит и виджет-тесты); счёт «успешного использования», а не каждого касания, обеспечен проверкой смены значения перед вызовом.

## 4. Не проверено (`NOT TESTED`), без фиктивных «OK»

- **iOS: NOT TESTED** (ни симулятор, ни TestFlight). Инструкция ручной проверки: собрать `flutter build ios --dart-define=ANALYTICS_LOCAL=true` на macOS, пройти экраны из §3, прочитать `[analytics-local]` в консоли Xcode; убедиться, что без флага строк аналитики в бинарнике нет (`strings Runner | grep analytics_local_v1`).
- **Физическое Android-устройство: NOT TESTED.**
- **Производительность (кадры/jank при прокрутке, время запуска, память, I/O): NOT MEASURED.** Скрипт замеров есть в scratchpad, но запуск на устройстве не одобрен владельцем, цифр нет и «процентов» не приводится. Известен только размер APK (+0,35 %) и +65 КБ у AOT-библиотеки arm64 `libapp.so` (из ранней сборки).
- Вложенные списки и `ScrollablePositionedList` на реальных экранах: на устройстве не проверялись; корректность `fit` и привязки скролла к видимому тексту подтверждена только тестами.
- Несколько панелей часов (одновременно в дереве): **не проверялось**.
- Параметр `version = ru` у Библии; главы компендиума вида `node/:id` из инвентаря на реальных данных.
- Отсутствие сетевых запросов при `ANALYTICS_LOCAL=false/true` проверено стражем (запрещённые импорты) и отсутствием транспорта в коде; перехват трафика на устройстве **не делался**.
- Тест очистки/выключения Hive-буфера есть среди юнит-тестов; на устройстве не проверялся.

## 5. Что нельзя без владельца

Сеть, настоящий отправитель, экран согласия, публичные релизы с флагом, Data safety / App Privacy, Firebase Analytics/GA4, Firestore статистики, Crashlytics, рекламные SDK, админка. Всё не добавлялось (см. `docs/analytics-backend-decision.md`).
