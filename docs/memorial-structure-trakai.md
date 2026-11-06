# Воспоминания без праздничной структуры; Богородица Тракельская 05.07 (memoria)

Решения владельца (ноябрь 2026), порт Web PR senddownrain/mybrev#194.

## 1. Te Deum и сборка воспоминаний (IGLH 68, 234–239)

`lib/utils/office_assembly.dart`: удалена «праздничная сборка» выбранного Common у
`memorial` / `optional-memorial`. Выбор Common больше не даёт Te Deum, не подменяет
первое библейское чтение (с респонсорием) и псалмодию дня и не создаёт I Нешпары.
Common даёт только элементы слотов воспоминания (`memorialHours`: гимн, краткое чтение,
респонсорий, антифона евангельской песни, прошения; второе чтение и молитва — после
собственных текстов). `_commonBase` по-прежнему заполняет пробелы этих элементов; при
пробеле в Common воспоминание берёт текст дня (пробел остаётся в `_integrityErrors`).
`lib/utils/liturgical_office.dart`: `shouldShowTeDeum` больше не читает `festiveCommon`.
Праздники и торжества не затронуты.

## 2. Тракели: 05.07, `memoria`

Данные едут в bundle (`assets/content`), не в коде:

| Коллекция | Документ | Изменение |
| --- | --- | --- |
| `liturgicalDioceseOverrides` | `grodno--our-lady-trakai` | `rank` festum→memoria; `dateRule` 07-10→07-05; `daysRef`: `_rank` memoria, `dayIds` только `05-07-our-lady-trakai-grodno`; `source` |
| `liturgicalProperTexts` | `05-07-our-lady-trakai-grodno-memoria-ad-libitum` | `_obsolete: true`, `_obsoleteReason`, `_supersededBy` (тексты не менялись) |

Bundle пересобран точечно из существующего bundle (две коллекции + `manifest.json`);
остальные 14 коллекций при повторном кодировании побайтно идентичны. Значения документов
взяты из Web (`calendar-definitions.json`, `patchs/db-feasts`), ничего не писалось руками.

**Порядок выпуска:** сначала владелец публикует эти два документа и манифест (Web PR), затем
релиз приложения с этим bundle (`content:app-release --compare-live` должен показать
`bundle = published`). До публикации bundle ≠ published.

## 3. Детерминированный выбор документа

`LiturgicalContentService._selectFixedDocuments`: среди нескольких sparse-документов
одной службы решает календарный ранг опции (`memoria` против устаревшего
`memoria-ad-libitum`); документы одного ранга — эквивалентные копии (по одной на
епархию) и берутся в стабильном порядке id, а не в порядке bundle. Вывод PR #39
(«наименьший id») сохранён только как tie-break между эквивалентными кандидатами; конфликт
рангов им не скрывается.

## 4. Фикстуры и тесты

- Перегенерированы штатным `scripts/build_common_parity.mjs --web <mybrev> --allow-unmerged-web --full`:
  `common_office_parity.json`, `office_assembly_parity.json`, `ordo_parity.json.gz`.
- Записи `christ-the-high-priest` в `ordo_parity.json.gz` оставлены как были (44 хэша): Web main
  с c55c69e собирает их иначе, чем bundle без контент-патча #63; это не связано с данной работой.
- `test/memorial_structure_trakai_test.dart` — независимые проверки по реальному bundle
  (Павел Креста 19.10.2026, Тереза 01.10.2026, Латеранская базилика 09.11.2026, все
  воспоминания 2026–2027 × 4 епархии, Тракели 2025–2035).
- `common_office_test`, `office_assembly_test`, `memorial_readings_rule_test` обновлены с
  рубричным обоснованием (57-е воспоминание с собственными чтениями — Тракели).
