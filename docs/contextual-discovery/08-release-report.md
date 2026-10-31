# Contextual Discovery — этап 7: интеграция и release QA

**Статус: PARTIAL.** Интеграция #51–#56 готова, автотесты зелёные, Android — реальный прогон; iOS — сокращённый прогон, часть пунктов NOT TESTED (см. таблицы). Не мёржить, не публиковать в сторы без решения владельца.

| | |
|---|---|
| Ветка | `claude/cd-stage7-integration` (Draft PR → `main`) |
| Состав | `origin/claude/cd-stage2-engine` (#51) + `cd-stage3-p0` (#52) + `cd-stage4-p1` (#53) + `cd-stage5-p2` (#55) + `cd-stage6-tour` (#56) + `cd-android-qa` (#54, только docs/evidence) |
| SHA `origin/main` | `24f8d94` |
| Flutter | 3.41.4 / Dart 3.11.1 (по `pubspec.yaml`; в системе стоял 3.38.9, использована отдельная копия, глобальная установка не тронута) |
| Android | AVD `MyBrev_Test_API34`, Android 14 (API 34), эмулятор `emulator-5554`, дата устройства 2026-10-31 |
| iOS | Simulator `cd-s7-iphone` (клон `cd-s6-iphone`, iPhone 16, iOS 18.6) — профиль клонирован, не чистый |

## 1. Интеграция (шаг A)

1. **Один презентер.** `hintPresenterProvider` создаёт `IntegratedHintPresenter` (за основу взят `cd-android`): подсказка идёт в inline-слот, если у якоря он есть, иначе — в coachmark. `discovery_hint_slot`, `discovery_visit`, `discovery_hint_host` используют `inlineOf/coachOf`. Хосты P2 (#55) и тур (#56) работают на том же провайдере.
2. **Бокс хранилища** открывается в `main.dart` до `runApp` (в QA-режиме `discovery_qa_v1`, иначе `discovery_v1`), поэтому хосты не молчат после холодного старта.
3. **Один QA-define.** Остался только `discoveryQaActive` (`DISCOVERY_QA` и `!kReleaseMode`, `lib/discovery/discovery_qa_mode.dart`). `kDiscoveryQa` и `discoveryPolicyForBuild` удалены; `dev/discovery_qa_flags.dart` — только сброс тестового профиля, завязан на `discoveryQaActive`. `qa_isolation_test` проходит.
4. `discoveryRouteOpenerProvider` (P2) подключён в `main.dart` поверх `discoveryAppOverrides()`.
5. В diff относительно `origin/main` нет файлов `ios/`, `android/`, `web/`, `Podfile.lock`. Автоправки `ios/*` от `flutter build ios` откатывались (`git checkout -- ios`).
6. **Найден и исправлен дефект этапа 7:** ручной тур («Як карыстацца дадаткам» в Налады) молча не стартовал, если на экране под настройками висела автоподсказка (`manualTourCanStart` требовал «спокойный» экран, включая «нет подсказки»; через 3 с попытки прекращались). Теперь ручной тур стартует поверх подсказки (старт сам её закрывает). Тест `a manual tour starts over an automatic hint`. Перепроверено на Android (`a24`, `a25`).

## 2. Автоматические проверки

| Проверка | Результат |
|---|---|
| `dart format` | PASS |
| `flutter analyze` | PASS по ошибкам/предупреждениям (0). 12 info — в `lib/utils/pastors_hymn.dart` и двух старых тестах; не относятся к этому PR |
| `flutter test` (полный) | **PASS: 1634 passed, 9 skipped, 0 failed** (после исправления тура); до исправления — 1633/9/0 |
| `qa_isolation_test` | PASS |
| Release APK (arm64) без QA | PASS: собран `flutter build apk --release`; в `libapp.so` нет `discovery_qa_v1`, `DISCOVERY_QA`, `[DiscoveryQA]`, harness/entrypoint; есть только путь библиотеки `dev/discovery_qa_flags.dart` (код за `const false`). iOS release не собирался |
| Web/PWA | PASS: diff не трогает `web/` и Web-код |

## 3. Android (AVD API 34, QA-сборка debug, `DISCOVERY_QA=true`, `ANALYTICS_LOCAL=true`)

Evidence: `docs/contextual-discovery/evidence/stage7/a*.png`.

| № | Сценарий | Результат | Evidence |
|---|---|---|---|
| A1 | Холодный старт на чистой установке: предложение тура | PASS | `a01-cold-start` |
| A2 | «Не зараз» → предложение закрыто | PASS | `a02-not-now` |
| A3 | Налады: «Паказваць падказкі», «Як карыстацца дадаткам», «Скінуць падказкі» | PASS | `a05b-settings-mid` |
| A4 | Тур: старт, шаги 1…6 (6 шагов, «Крок N з 6» в семантике), «Далей», «Назад», «Гатова» | PASS | `a06`–`a14` |
| A5 | P0 `readings.day_variants` на 2026-12-04 (Чытанні): капсула + «Паказаць» → лист «Іншыя варыянты», два варианта | PASS | `a19`, `a20` |
| A6 | Back/«Гатова» из листа: дата на экране осталась 4 снежня | PASS | `a21` |
| A7 | Не более одной автоподсказки на визит. QA-режим (без пауз) после закрытия листа показал вторую (`calendar.date_navigation`) через ~3 с — это новый визит; в QA паузы выключены. Production-политика (сборка без `DISCOVERY_QA`): после предложения тура на Чытанні 2026-12-04 подсказок нет (пауза 5 мин) | PASS (production), см. примечание | `a21`, `a30`, `a31`, `a32` |
| A8 | Приоритет P0>P1>P2 | PASS по юнит-тестам политики; на устройстве проверены только отдельные подсказки (P0) | — |
| A9 | Подсказки выключены → перезапуск: автоподсказок нет; ручной тур открывается | PASS | `a27`, `a28`, `a29` |
| A10 | Ручной тур стартует поверх висящей подсказки (исправление этого этапа) | PASS | `a24-hint-visible…`, `a25-manual-tour-over-hint` |
| A11 | Тёмная тема + системный шрифт 200% | PASS: карточка переносится, кнопки доступны, перекрытий нет (нижний док «Малітоўнік» переносит слово — не относится к подсказкам) | `a22` |
| A12 | Маленький экран 320 dp (960×1600 @480 dpi) | PASS (подсказка читается, кнопки в две строки) | `a23` |
| A13 | Offline (Wi-Fi и данные выключены, ping 8.8.8.8 недоступен) | PASS: приложение и подсказки работают, крашей нет | `a23`, `a24` |
| A14 | Reduced motion (`animator/transition/window_animation_scale=0`) | PASS: подсказка и тур показываются без зависаний; отдельный скриншот на обычной анимации не сравнивался | `a24`, `a25` |
| A15 | Локальная аналитика: дискавери-код не импортирует `analytics/` (проверяет `qa_isolation_test`), новых событий/SDK нет; сетевой отправки без `ANALYTICS_STAGING` нет | PASS (статически); сетевой трафик не перехватывался | — |
| A16 | «Скінуць падказкі» (подтверждённый сброс) | NOT TESTED на устройстве в этом прогоне (есть widget-тест) | — |
| A17 | Смена ориентации, фон/возврат, 20-секундный скролл молитвы, клавиатура, быстрые переходы дат (кроме 34 нажатий вперёд) | NOT TESTED | — |
| A18 | TalkBack (речь) | NOT TESTED; в дереве доступности есть «Падказка…», «Крок N з 6», подписи кнопок | — |
| A19 | Производительность (нативный профиль без подсказок) | NOT TESTED | — |

## 4. iOS Simulator (`cd-s7-iphone`, QA-сборка debug)

| № | Сценарий | Результат | Evidence |
|---|---|---|---|
| I1 | Холодный старт: предложение тура | PASS | `i01-cold-start` |
| I2 | P0 `readings.day_variants` на Чытанні (31.10.2026) | PASS (подсказка показана) | `i05-readings-day-variants-hint` |
| I3 | «Паказаць» открывает лист «Іншыя варыянты» | PASS, **но лист открылся на 20.10.2026, а экран показывал 31.10.2026; после «Гатова» экран перешёл на 20.10** | `i02`, `i06` |
| I4 | P2 `discover.songbook` на Малітоўніку (капсула над карточками, меню «⋯» открыто одновременно) | PASS (показана), капсула частично закрывает соседнюю карточку «Катэхізіс» | `i04-p2-songbook-hint-with-menu` |
| I5 | Тёмная тема + крупнейший Dynamic Type (AX3, больше 200%) | Верстка экрана Малітоўнік тянется, док переносит слова; подсказка на этом экране не показывалась → для подсказок NOT TESTED | `i03-dark-ax-text` |
| I6 | Тур (шаги, назад, пропустить), «Паказваць падказкі», перезапуск, offline, маленький экран, reduced motion, сброс | **NOT TESTED** в этом прогоне (тур на iOS проверялся в PR этапа 6 до интеграции: `07-tour-qa.md`) | — |
| I7 | VoiceOver (речь) | NOT TESTED | — |

**Открытый вопрос I3.** Дата листа берётся из `presentation.date` общего провайдера, а не из даты экрана Чытанні. На Android (дата менялась стрелками) совпадала; на iOS клон профиля мог хранить дату 20.10. Причина не подтверждена: нужен прогон на чистой установке iOS. Если воспроизведётся — это дефект, отдельный от Discovery (шире, чем подсказки), но `Паказаць` из `day_variants` делает его заметным.

## 5. Таблица hint_id

| hint_id | Приоритет | Статус | Проверено |
|---|---|---|---|
| `readings.day_variants` | P0 | IMPLEMENTED+TESTED | widget; Android A5/A6; iOS I2/I3 |
| `readings.other_year` | P0 | IMPLEMENTED+TESTED | widget; iOS показана после I3 (`i06`); Android — в `android-qa.md` (3.4) |
| `calendar.date_navigation` | P0 | IMPLEMENTED+TESTED | widget; Android показана после 34 нажатий (`a21`) |
| `calendar.more_periods` | P0 | IMPLEMENTED+TESTED | widget; Android — `android-qa.md` (3.8) |
| `ordo.calendar_variants` | P0 | IMPLEMENTED, на устройстве NOT TESTED | widget |
| `readings.allowed_alternatives` | P0 | DEFERRED | нет достоверного источника разрешённых альтернатив (этап 1) |
| `readings.other_date` | — | DEFERRED, не P0 | — |
| `display.font_scale` | P1 | IMPLEMENTED+TESTED | widget; Android — `android-qa.md` (4.1, 4.5) |
| `hours.psalm_layout` | P1 | IMPLEMENTED+TESTED | widget; Android — `android-qa.md` (4.3) |
| `hours.next_hour` | P1 | IMPLEMENTED+TESTED | widget; Android — `android-qa.md` (4.6) |
| `bible.navigation` | P1 | IMPLEMENTED+TESTED | widget; Android — `android-qa.md` (4.7) |
| `app.search` | P1 | IMPLEMENTED+TESTED | widget; Android — `android-qa.md` (4.8, 4.9) |
| `discover.songbook` | P2 | IMPLEMENTED+TESTED | widget; iOS I4 |
| `discover.catechism` | P2 | IMPLEMENTED, на устройстве NOT TESTED (этап 5: `06-p2-qa.md`, iOS) | widget |
| `discover.prayers` | P2 | IMPLEMENTED, на устройстве NOT TESTED в интеграции | widget |
| `discover.bible` | P2 | IMPLEMENTED, на устройстве NOT TESTED в интеграции | widget |

Строки со ссылкой на `android-qa.md` — результаты PR #54 на промежуточной склейке; на финальной ветке заново только перечисленное в разделах 3–4.

## 6. Baseline, риски, rollback, приватность

- **Baseline:** полный `flutter test` на `origin/main` отдельно не запускался; на интеграционной ветке 0 failed, 9 skipped (пропуски заданы в самих тестах, не этим PR).
- **Известные ограничения:** (1) нижняя капсула P1/P2 частично перекрывает плавающий док на Android и соседнюю карточку на iOS (текст Писания не закрыт); (2) оставшиеся NOT TESTED пункты выше; (3) вопрос I3; (4) спот-подсветка шага 1 тура на Android смещена относительно дока (косметика, `a06`).
- **Rollback:** подсказки отключаются в Налады («Паказваць падказкі»); на уровне сборки — не мёржить PR либо откатить merge-коммит. Хранилище подсказок отдельное (`discovery_v1`), данные литургии, избранное и молитвы не затрагиваются.
- **Приватность:** сети нет; аналитика только под существующим `ANALYTICS_LOCAL`, подсказки событий не пишут.
- **Запрещено без явного слова владельца:** merge в `main`, TestFlight/Play, production Firebase.

## ПРОВЕРКА ЗА 60 СЕКУНД (для владельца)

1. Откройте Android-эмулятор `MyBrev_Test_API34`, установите debug-сборку с `--dart-define=DISCOVERY_QA=true`, запустите приложение с чистой установки → внизу карточка «Паказаць, як карыстацца дадаткам?».
2. Нажмите «Паказаць» → пройдите шаги 1–6 кнопками «Далей»/«Назад» → «Гатова». Затем «Чытанні» → стрелка «следующий день» 34 раза до **4 снежня 2026** → под «Іншыя варыянты» появится «На гэтую дату ёсць іншыя варыянты літургічнага дня».
3. Нажмите «Паказаць» → откроется лист «Іншыя варыянты» с двумя вариантами (І тыдзень Адвэнту / Св. Яна Дамаскіна) → Back → дата остаётся 4 снежня.
4. Негативный случай: ⋯ → Налады → выключите «Паказваць падказкі» → перезапустите → на Чытанні (4 снежня) подсказок нет, а «Як карыстацца дадаткам» всё ещё запускает тур.
5. iOS: симулятор `cd-s7-iphone`, шаг 1–3 те же; **проверьте дату в листе — она должна совпасть с датой экрана** (в моём прогоне не совпала).

**Android:** PASS по A1–A15 (кроме перечисленных NOT TESTED). **iOS:** PARTIAL (I1–I4 PASS/с замечанием, остальное NOT TESTED). **Следующий этап разрешён: НЕТ, пока не закрыты I3 и iOS-прогон тура на чистом профиле.**
