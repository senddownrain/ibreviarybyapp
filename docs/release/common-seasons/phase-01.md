# ФАЗА 01 — WEB: сезонные Common (автоматическая часть) — отчёт исполнителя

**Дата и час (UTC):** 2026-10-30  
**Исполнитель/тестировщик:** Claude Code (сессия sc-phase-0-2)  
**Web HEAD:** `08b12838fcc7a737149dccd4225a043b6efcaec3` (worktree `sc-web`, чистый, `claude/sc-phase-0-2-web` без собственных коммитов)  
**Flutter HEAD:** `d17578cd196fed3a6cf5330e9667217583a9317c`  
**Branch / PR / CI:** изменений в Web нет, Web‑PR не создавался  
**Тестируемый build/package/version:** Node v24.2.0, WEB `package.json` 4.5.2

## 1. Содержание изменений

- Изменено: **ничего в Web**.
- Осознанно НЕ затронуто: экранные проверки W1–W5 и D1‑W1…W5 (ведёт параллельная сессия `sc-web-screens`, локальный эмулятор), одобренные тексты, Proper/ранги.
- Защита параллельной работы: свой worktree от `origin/main`, экранные тесты Web не запускались и не менялись.

## 2. Автоматические тесты

| Команда | Итог PASS/FAIL | Счётчик/exit code | CI/лог |
|---|---|---|---|
| `npm ci` | PASS | 802 packages, exit 0 | — |
| `npm run test:common-seasons` | PASS | 114 tests, 114 pass, 0 fail, exit 0 | локально |
| `npm run liturgy:common-seasons:check` | PASS | exit 0 (13 сезонных Common; цитаты по Common — apostles 60, blessed-virgin-mary 113, pastors 82, … ) | локально |
| `npm test` | PASS | 1059 tests: 1048 pass, 0 fail, 11 skipped, exit 0 | локально; Web main CI = success |
| `npx eslint .` | PASS | exit 0, без вывода | — |
| `npm run build` | PASS (с оговоркой) | Без `VITE_FIREBASE_*` сборка **намеренно** падает (`Missing Firebase web build configuration`); с локальными заглушками `VITE_FIREBASE_*` (без сети) — exit 0, PWA precache 151 entries | локально |

11 пропущенных тестов — существующие `SKIP` (в т.ч. layout 360–430 px), не ослаблялись мной.

### Автоматическое покрытие сценариев W1–W5 (без экрана)

Это **не** замена экранной проверки, а то, что уже ловят тесты `test:common-seasons`:

| Сценарий | Тест (проходит) |
|---|---|
| W1 Гродно 04.12.2026 | «04.12.2026 Grodno: the loaded Firestore shape yields Rev 21, 9-27 on the Office card», «other dioceses on 04.12.2026 do not get the Grodno celebration», «cause classification: … production-like data (no `_seasonalVariants`) shows 1 Pet 2» |
| W2/W3 базовый и Пост | «negative control: the Common in Ordinary Time (Volume III) is not the seasonal reading», «golden: church-dedication / lent», «boundaries: Christmas→Ordinary, Ash Wednesday, Palm Sunday, Triduum…» |
| W4 Мария в субботу | «calendar: the Saturday memorial is offered on free Saturdays of Ordinary Time only…», «assembly: a Marian celebration of Ordinary Time shows the main section only», «NR-012» |
| W5 Proper vs Common | «memorial: «З дня» stays the weekday, the Common choice takes the seasonal texts», «fixture assembly cases: own Proper wins; current-day keeps the weekday; Common uses festive hours», «religious and works-of-mercy: the whole first reading…» |
| Гимны пастырей | «a verse that merely begins with the word «Гімн» is text, not a reference to a hymn (the pastors hymn was cut after four lines)» |

## 3. Реальные UI проверки (обязательны для соответствующих фаз)

| ID | На чём / URL | Что нажато | Что увидел (ФАКТ) | Ожидалось | PASS/FAIL/BLOCKED | PNG/MP4 |
|---|---|---|---|---|---|---|
| W1–W5 | — | — | **Не выполнялись в этой сессии**: ведёт параллельная сессия `sc-web-screens` | см. план | **NOT TESTED (здесь)** — результаты у сессии экранов | — |

## 4. Найденные ошибки → исправления → повторная проверка

Ошибок Web‑кода не найдено. Замечание по окружению: `npm run build` без `VITE_FIREBASE_*` падает по дизайну — это не дефект, но CI‑окружение должно их задавать.

## 5. Production/магазинные операции

- Совершались? **НЕТ**. Тесты работают на fixtures/offline.

## 6. Результат и следующий шаг

**Вердикт:** автоматическая часть — **PASS**; экранные W1–W5 — **NOT TESTED в этой сессии** (в работе у `sc-web-screens`).  
**Что осталось и кто продолжает:** W1–W5 и D1‑W1…W5 — сессия `sc-web-screens`.  
**Запрос от release manager (не QA):** отсутствует.  
**Следующая фаза:** 2.
