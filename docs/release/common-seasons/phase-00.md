# ФАЗА 00 — исходное состояние — отчёт исполнителя

**Дата и час (UTC):** 2026-10-30  
**Исполнитель/тестировщик:** Claude Code (сессия sc-phase-0-2), без доступа к production Firestore / Play Console / App Store Connect  
**Web HEAD (origin/main):** `08b12838fcc7a737149dccd4225a043b6efcaec3` (R06 final QA, #174)  
**Flutter HEAD (origin/main):** `d17578cd196fed3a6cf5330e9667217583a9317c` (R04 analytics transport, #40)  
**Branch / PR / CI:** `claude/sc-phase-0-2-flutter` (Draft PR — см. phase-02.md); Web main CI = success (08b1283)  
**Тестируемый build/package/version:** pubspec `1.0.0+6`; последняя магазинная сборка по CI — см. §1

## 1. Содержание изменений

Фаза только читает; в репозитории изменений нет.

### Таблица SHA и состояний

| Компонент | Значение | Источник / статус |
|---|---|---|
| WEB main | `08b1283` (2026-10-30 10:03 +03) | `git fetch`, CI на main = success |
| WEB Hosting (deployed) | **UNKNOWN (не проверено)** | Production не читался. В репозитории `CONTENT_REVISION = 2026-10-24T16:50:32Z`; по сообщению заказчика Hosting задеплоен с этим значением. |
| Flutter main | `d17578c` (2026-10-30 10:04 +03) | `git fetch` |
| Последний `MyBrev Android Beta Release` | run `39379866530`, success, 2026-10-20 06:21Z, SHA `04f6610`, track `alpha`, pubspec `1.0.0+6` | `gh run view`. **SHA `04f6610` — предок #22 (`d35f74c`): сборка НЕ содержит сезонность/Common (#22) и гимны (#27).** Новее релизов нет. |
| Google Play alpha (versionCode / установимость) | **BLOCKED STORE ACCESS** | нет доступа к Play Console |
| TestFlight build | **BLOCKED STORE ACCESS** | нет доступа к App Store Connect/fastlane credentials |
| Bundled manifest digest | `contentVersion 1792491714388` (2026-10-20T10:21:54Z) | `assets/content/manifest.json`, см. §«Bundle» |
| Опубликованный `contentManifest/current` | **UNKNOWN (production не читался)** | — |

Вывод: «merged + CI зелёный» ≠ «в магазине». Доказательств, что в Play/TestFlight лежит сборка с #22/#27, нет; по CI — наоборот, последняя alpha-сборка старше #22/#27.

### 0.1 Web PR

| PR | State | mergedAt | merge SHA |
|---|---|---|---|
| mybrev #132 | MERGED | 2026-10-17 | `a4c1df1` |
| #139 | MERGED | 2026-10-18 | `05356c7` |
| #141 | MERGED | 2026-10-19 | `79ac1c7` |
| #145 | MERGED | 2026-10-20 | `0612d53` |
| #148 | MERGED | 2026-10-22 | `96991b3` |
| (после пакета) #164/#165/#166 | слиты | 2026-10-24 | в main |

Открытые Web PR: #158 (Sentry B, draft), #150 (docs, draft), #149 (diagnostics, draft), #140 (**только prompt D‑1**, open).

### 0.2 Flutter PR

| PR | State | merge SHA |
|---|---|---|
| ibreviarybyapp #22 | MERGED 2026-10-21 | `d35f74c` |
| #27 | MERGED 2026-10-22 | `a8cc5ff` |
| (после пакета) #33, #38 | MERGED 2026-10-24 | `9da3ccb`, `bb3afd3` |

Открытые Flutter PR: #28, #23, #21 (все draft, docs/prep).

### 0.4 Flutter bundle (декодирован `assets/content/*.json.gz`)

| Ожидалось | Факт |
|---|---|
| 16 Common | **16** `liturgicalTemplates` (digest `fd4b4f8eac9c9902`) |
| 13 сезонных | **13** с `_seasonalVariants` (advent/christmas/lent/easter): apostles, blessed-virgin-mary, church-dedication, doctors-of-church, educators, holy-men, holy-women, martyr-one, martyrs-many, pastors, religious, virgins, works-of-mercy. Без сезонности: complementary-psalmody, office-for-dead, sunday-week-1 |
| 291 Proper | **291** (digest `16c87c1e79df5370`); 27 документов с `_commonBase` (29 привязок), 185 с `_fieldRules` |
| ревизии 3 и 4 | `liturgicalCalendarMeta/current`: `templatesRevision=3`, `properTextsRevision=4` |

**Отличие от Web main (реальный drift данных, не кода):** Web main содержит больше, чем bundle (подробно в phase-02.md): (1) `holy-women` (#165, D‑1 набор законных чтений, `templatesRevision` 4 в Firestore); (2) `22-10-sv-john-paul-ii` (#152, `officeOfReadingsR2`, `officeOfReadingsPr`). Генерируемые Web‑источники дают Proper digest `e38afe1c97a7ba34` и Common digest `316b5f1487846faf`, bundle — `16c87c1e…` / `fd4b4f8e…`.

## 2. Автоматические тесты

Фаза не запускает тесты (они в фазах 1–2).

## 3. Реальные UI проверки

| ID | На чём / URL | Что нажато | Что увидел (ФАКТ) | Ожидалось | PASS/FAIL/BLOCKED | PNG/MP4 |
|---|---|---|---|---|---|---|
| 0.1 | `gh pr view` (CLI вместо веб‑страниц GitHub) | PR #132/#139/#141/#145/#148 | Все `MERGED`, SHA в таблице | Merged | PASS (через `gh`, не через браузер) | — |
| 0.2 | `gh pr view` | PR #22/#27 | `MERGED`, SHA в таблице | Merged | PASS (через `gh`) | — |
| 0.3 | `gh run view 39379866530` | — | success, SHA `04f6610` (до #22) | свежий run с #22/#27 | **FAIL (устаревший run)**; Play/TestFlight — **BLOCKED STORE ACCESS** | — |
| 0.4 | локальный bundle | декодирован Node (`app-content.mjs`) | 16/13/291, ревизии 3/4 | 16/13/291 | PASS | — |

## 4. Найденные ошибки → исправления → повторная проверка

| Ошибка | Корень проблемы | PR/commit fix | Какие тесты повторены | Результат |
|---|---|---|---|---|
| Последняя alpha‑сборка не содержит #22/#27 | релиз не запускали после слияния | не код: нужен новый release run (фаза 6, отдельный approval) | — | открыто |
| Bundle отстаёт от Web main (holy-women, JP II) | не обновлялся после #152/#165 | см. phase-02.md | — | открыто (решение release manager) |

## 5. Production/магазинные операции

- Совершались? **НЕТ**. Production Firestore, Hosting, Play, TestFlight не читались и не изменялись.

## 6. Результат и следующий шаг

**Вердикт:** PASS для git/PR/CI/bundle; **BLOCKED STORE ACCESS** для Play/TestFlight; Web Hosting SHA UNKNOWN.

**Что осталось и кто продолжает:** проверка Play alpha / TestFlight — уполномоченный Play/App Store Connect владелец.  
**Запрос от release manager (не QA):** доступ только на чтение к Play Console (Closed testing → alpha) и App Store Connect (TestFlight → Builds), либо скриншот/номер билдов.  
**Следующая фаза:** 1 (автоматическая часть), затем 2.
