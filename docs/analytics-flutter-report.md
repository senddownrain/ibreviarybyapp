# Отчёт: Flutter, локальная аналитика по контракту v1 (2026-10-15)

Статус: **локальный счёт только в тестовых сборках, сеть выключена и не реализована.** Ветка
`feature/analytics-local` от `origin/main` (`b40ae12`). Источники правды: репозиторий `mybrev`,
ветка `feature/analytics-contract`, `docs/analytics-contract.md`, `docs/analytics-privacy.md`
(решение **D-10 = B**: локально только в internal testing и TestFlight, региона нет, всё `UNKNOWN`).

## 1. Что сделано

| Файл | Назначение |
|---|---|
| `lib/analytics/contract.dart` | Порт контракта v1: константы, бакеты, оценка чтения, `validateCell/validatePacket/validateContentId` |
| `lib/analytics/collector.dart` | Порт коллектора: визиты (§7), три метрики, ошибки измерения, лимиты, `importPackets`, `pruneOlderThan` |
| `lib/analytics/route_mapper.dart` | Адрес go_router → `section`/`content_id`; `vespers` → `vesper`; списки, поиск, личные молитвы не измеряются |
| `lib/analytics/public_inventory.dart` | Сгенерированный инвентарь публичных ID (745), генератор `tool/generate_analytics_inventory.dart` |
| `lib/analytics/transport.dart` | `NoopTransport`, `RecordingTransport` (реальной сети нет) |
| `lib/analytics/local_analytics.dart` | Подключение: жизненный цикл, маршруты, метрики прокрутки, Hive-box `analytics_local_v1` |
| `lib/main.dart` | Две строки под флагом `kAnalyticsLocal` |
| `test/analytics/*`, `test/fixtures/analytics/*` | Тесты и копии веб-фикстур (побайтно совпадают с веб-версией) |

Включение: только `--dart-define=ANALYTICS_LOCAL=true`. Без флага код сбора не запускается.

## 2. Как это работает

- Время считается монотонными часами (`Stopwatch`), день пакета — UTC.
- Жизненный цикл: `resumed` — идёт время на экране; `inactive/hidden/paused` — пауза; фон ≥ 5 мин
  закрывает визит. Сохранение в Hive на `paused`/`detached` (≤ 64 КиБ, ≤ 14 суток, лишнее — самые
  старые дни, с ошибкой `queue_overflow`). Таймеров и записи на scroll нет.
- Прокрутка: один `NotificationListener` над приложением (`AnalyticsScrollListener`) принимает
  метрики вертикальных верхнеуровневых прокруток (`depth == 0`, вьюпорт ≥ 200 px), без `setState`
  и ребилдов; текст, помещающийся на экран, даёт `fit`.
- Материал, на котором не появилось ни одной прокручиваемой области (загрузка, «не найдено»),
  не засчитывается (`discardView`). Это эвристика, не проверенная на реальных экранах.
- `er` (оценка чтения) требует длину текста: экраны её пока **не сообщают**
  (`LocalAnalytics.reportTextLength` не вызывается), поэтому сейчас пишутся `screen_view`, `fv`, `sd`.
- Кнопки (`feature_use`) не подключены (по handoff — отдельным шагом после ревью).

## 3. Проверки

| Проверка | Результат |
|---|---|
| 38 тестов чистой логики (контракт, коллектор, маппер, инвентарь, mock transport, страж) | 38/38 пройдено на обычном Dart SDK 3.10.8 через временную обвязку; обвязка проверена: заведомо неверные ожидания падают |
| Виджет-тест обвязки (`GoRouter` + прокрутка + Hive + PackageInfo) | пройден с `--dart-define=ANALYTICS_LOCAL=true` и пропускается без флага; запускался в отдельном временном Flutter-пакете на Flutter 3.38.9 |
| `dart analyze` файлов `lib/analytics` (кроме `local_analytics.dart`), генератора | без замечаний; `local_analytics.dart` — `flutter analyze`: без замечаний |
| Release-сборка тестового приложения, повторяющего подключение из `main.dart` | без флага строки аналитики (`analytics_local_v1`, `scroll_unmeasurable`, ID из инвентаря) в `main.dart.js` **отсутствуют**; с флагом — присутствуют |
| Полный `flutter analyze` репозитория, **Flutter 3.41.4** (целевой SDK, родной `pubspec.lock`) | No issues found |
| Полный `flutter test` репозитория, **Flutter 3.41.4** | 1344 пройдено, 1 пропущен, 0 упало (включая новые тесты аналитики; виджет-тест обвязки пропускается без флага) |
| Предварительный прогон на Flutter 3.38.9 (копия с ослабленным SDK) | 3 теста ordo падали и на чистом `origin/main`; на 3.41.4 они проходят, то есть это была разница SDK |
| Фикстуры | `analytics-contract-v1.json` и `public-inventory.json` совпадают побайтно с веб-версией |

## 4. НЕ ПРОВЕРЕНО (честно)

- **Реальное приложение не собиралось и не запускалось** (ни Android, ни iOS, ни симулятор).
  Отсутствие аналитики в обычной сборке проверено на пробном приложении с тем же подключением, а не
  на `lib/main.dart`.
- Реальные экраны: срабатывание эвристики «нет прокручиваемой области», корректность `fit` на
  `ScrollablePositionedList`, привязка глубины прокрутки к экранам часов с несколькими списками.
- Параметр `version` Библии (`bel`/`ru`) взят из `BibleRepository` (`bel` подтверждён кодом, `ru` — нет).
- Идентификаторы глав компендиума (`/prayers/compendium/node/:nodeId`) и их совпадение с инвентарём.
- Влияние на производительность на устройстве.
- Тест-страж проверяет запрещённые импорты регулярными выражениями, а не зависимости транзитивно.

## 5. Что нельзя без владельца

Сеть, реальный отправитель, экран согласия, публичные релизы с флагом `ANALYTICS_LOCAL`,
обновление Data safety / App Privacy (D-01…D-09, `docs/analytics-privacy.md`). Firestore, ID
устройства и установки, Firebase Analytics/Crashlytics, рекламные SDK не добавлялись.

## 6. Следующие шаги

1. Запустить `flutter test` и `flutter analyze` на Flutter 3.41.4 (CI) и исправить расхождения.
2. Собрать тестовую сборку с флагом (internal testing / TestFlight / debug) и пройти экраны:
   молитва, песня, час, Библия, Мэса; прочитать `debugPrint('[analytics-local] …')` на паузе.
3. Подключить длину текста (`reportTextLength`) на экранах текстов для метрики `er`, затем `feature_use`.

## 7. Метрика `sd` (глубина прокрутки) — P01

- `sd=fit`: весь текст виден без прокрутки. Читалка оставляет под текстом пустой резерв
  (`ReaderContentSurface.bottomSpacing` 42 + нижний системный/dock-отступ), из-за которого
  экран может прокручиваться на несколько пунктов, хотя текст виден целиком. Такая прокрутка
  внутри резерва считается `fit` (`maxScrollExtent <= 1 + trailingBlank`, где `trailingBlank`
  передаёт `ReaderScaffold` через `AnalyticsReaderScroll`).
- Если прокрутка больше резерва, часть текста скрыта: `sd` растёт от `p25_50`… до `p100`.
- Резерв не убирается и не меняется; контракт v2 и значения бакетов не менялись.
- Тесты: `test/analytics/fit_detection_test.dart` (нужен `--dart-define=ANALYTICS_LOCAL=true`).
