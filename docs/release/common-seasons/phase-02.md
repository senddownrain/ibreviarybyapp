# ФАЗА 02 — FLUTTER: сезонные Common, паритет с Web (автоматическая часть) — отчёт исполнителя

**Дата (UTC):** 2026-10-30  
**Исполнитель:** Claude Code (сессия sc-phase-0-2)  
**Web HEAD (origin/main):** `08b12838fcc7a737149dccd4225a043b6efcaec3`  
**Flutter base (origin/main):** `d17578cd196fed3a6cf5330e9667217583a9317c`  
**Branch / PR:** `claude/sc-phase-0-2-flutter` (Draft PR); Web: `claude/sc-hymn-stanza-not-heading` (Draft PR)

## 1. Содержание изменений

- `lib/utils/pastors_hymn.dart` — гимн пастырей собирается из двух сохранённых раскладок (база с четырьмя `<hr>` и сезонные варианты без `<hr>`), как `pastorsHymn.js` в Web.
- `lib/utils/liturgical_alternatives.dart` — для `kind == 'hymn'` заголовок категории («Пра/За/Для … :») ищется только в первой строке абзаца. Строфа «Для адданых слугаў Божых / Хай гучыць хвала й падзяка:» больше не считается заголовком (раньше давала третий ложный вариант и обрезала гимн после четвёртой строфы в Common святых мужей на Вечерні и I Вечерні в Адвент, Різдво, Пост, Вялікдзень). Зеркало Web‑исправления (sc-web, коммит `5f37e94`).
- `scripts/refresh_common_bundle.mjs`, `scripts/build_common_parity.mjs`, `scripts/audit_common_delivery.mjs` — обновление бандла/фикстур; аудит доставки стал read‑only с обязательными `--approval` и `--max-reads` (production Firestore НЕ читался).
- `test/hours_parity_test.dart`, `test/fixtures/*`, `reports/*` — паритет‑отчёт теперь фиксирует heads Web/Flutter, снимок фикстур и `contentVersion` бандла.
- `test/liturgical_alternatives_test.dart` — новый тест на строфу «Для …» в гимне и на настоящий заголовок в первой строке.

## 2. Автоматические тесты

| Проверка | Итог | Примечание |
|---|---|---|
| Web `node --test tests/liturgical-alternatives.test.mjs` | PASS 13/13 (без исправления — 1 FAIL, т.е. тест ловит дефект) | локально |
| Паритет часов (`reports/flutter-hours-parity.json`, Web 08b1283 / Flutter d17578c) | 16068 дней, 37738 сборок, structureMismatches 0, officeTextMismatches 0 | значения из отчёта, записанного прогоном `hours_parity_test` |
| Новый Dart‑тест `liturgical_alternatives_test.dart` | **NOT RUN (здесь)** | локальный Flutter 3.38.9, проект требует ≥3.41.4 (`flutter test` и `dart run` отказывают). Нужен прогон в CI/на SDK 3.41.4 |
| Остальной `flutter test`, `flutter analyze` | **NOT RUN в продолжении сессии** | та же причина; результаты берутся из CI Draft PR |

## 3. Реальные UI проверки

Не выполнялись (эмулятор/устройство не использовались). Статус: **NOT TESTED**.

## 4. Production/магазинные операции

Не совершались. Play Console / App Store Connect / production Firestore — **BLOCKED ACCESS**, не читались.

## 5. Результат

**Вердикт:** код и Web‑тесты — готово; Flutter‑тесты — **ждут CI** на SDK 3.41.4; UI — NOT TESTED.  
**Следующий шаг:** дождаться CI обоих Draft PR, затем экранные проверки (`sc-web-screens`, устройство).
