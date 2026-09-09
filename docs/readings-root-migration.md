# Readings root migration — Stage 4

Дата: 2026-09-09. Статус: реализовано в `feature/mobile-ux-migration`.

## Новый flow

Корень branch `Чытанні` теперь является длинным reader: дата и название
выбранного набора идут компактным контекстом, после чего сразу начинается
семантически разобранный текст (чтение, псалом, второе чтение, аккламация и
Евангелие). Промежуточного экрана или card вокруг документа и каждого раздела
нет.

Дата открывает тот же двухступенчатый flow, что Hours: быстрые Today/previous/
next, общий adaptive calendar и отдельный advanced Liturgical Picker. One-tap
`Сёння` появляется на root только для другой даты. Изменяется исключительно
`readingsBranchStateProvider`; год advanced picker в Readings mode также берётся
из Readings state, а не из Hours.

## Existing default resolver adapter

`resolveDefaultReadings` в `lib/utils/readings_selection.dart` централизует
существующее production-поведение без изменения его смысла:

- исходный порядок `ParsedReadingsService.fetchForDate(...,
  includeAlternatives: true)` сохраняется;
- linked `dayId` выбирает уже существующую связанную group;
- иначе остаётся первая group;
- применяются прежние `availableCyclesForGroup`, `normalizeReadingCycle` и
  `pickReadingForCycle`;
- сохраняются fallback на shared-cycle document, первый документ с content и
  первый документ.

Рядом оставлен TODO для отдельного normative resolver audit. Stage 4 не
утверждает новую литургическую precedence policy.

## Варыянты: group и cycle

`Варыянты` показывается только при нескольких celebration/reading groups или
нескольких реальных cycles текущей group. В adaptive sheet понятия разделены:

1. celebration / набор чтений;
2. применимый cycle текущего набора.

Sunday groups показывают только реально имеющиеся A/B/C, weekday groups —
только I/II. Один или неприменимый cycle не создаёт selector. Default — `Па
календары`; ручной выбор помечается `Цыкл … · зменены`, а automatic action
возвращает календарный выбор. Override живёт только вместе с текущим документом
и очищается при смене даты или group.

## Reader, navigation и context

Readings использует общий Stage 1 `ReaderScaffold`, `ReaderContentSurface`,
`ReaderTheme`, persisted `TextScaleControl`, safe areas и scroll controller.
Небольшое reusable-расширение ReaderScaffold позволяет root-reader передать
adaptive leading control и drawer; platform material остаётся внутри shared
chrome. Root начинается в Full, пользовательский scroll просит Compact, Focus
просит Hidden. Собственной нижней панели Readings нет.

PageStorage и живой branch сохраняют scroll при переключении tabs. Options
sheet не пересоздаёт документ. Новая дата, group или manual cycle сбрасывают
позицию в начало нового документа.

Contextual Ora → Readings продолжает использовать Stage 2 token и canonical
route с `date`/`dayId`. Back возвращает существующий Hours/Ora branch stack, не
пересоздавая Ora и не меняя его date, hour, option или scroll.

## Compatibility и legacy disposition

- `/readings`, `/readings/:dateStr`,
  `/readings/liturgical/:period/:week/:day`, `/reading/:readingId` и
  contextual Ora route сохранены и нормализуются в Readings branch.
- `ReadingDetailScreen`: **KEEP / MODIFY LATER**. Он остаётся target для direct
  links и cached single-document compatibility. Его перенос на общий reader
  возможен отдельным малым cleanup, но удаление не входит в Stage 4.
- Старые grouping/service/cache/offline paths: **KEEP**.
- Старые Readings app bar, inline celebration glass и global cycle tabs:
  **REMOVED FROM ROOT FLOW**.

Следующий рекомендуемый этап — отдельная Stage 5 миграция Prayerbook. Она не
начинается автоматически этим изменением.
