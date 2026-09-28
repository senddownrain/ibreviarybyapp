# Executive verdict

Реальный iPhone Simulator walkthrough выполнен в нескольких сессиях; последние пробелы закрыты 2026-09-28. Сохранить content-first reader и floating navigation. Результат для подтверждённой сборки **270f0d4: P1 — 0, P2 — 3, P3 — 1**. В последней сессии один P2 (нижний gap поиска) не воспроизвёлся; её SHA пока не подтверждён. Не считать это аудитом актуального main или доказательством исправления в том же commit. Production code и Android Layout Lab не менялись.

# Environment

- Подтверждённый пользователем audited commit: **270f0d4416faefd35fd7fcd4e4d8a09fd0ebfbbe**. Основная часть evidence относится к нему.
- Последняя успешная сессия: [Codemagic](https://codemagic.io/s/preview/Pd-XT8Vsr1kTJsAl), embed `ir7momuthjyndewmixad2geag4`, 2026-09-28. SHA этой сессии не отображается в Preview; запрошен отдельно.
- **iPhone 14 Pro / iOS 16.2**, по маркировке Codemagic; реальный Appetize simulator stream. Light и Dark включались в настройках приложения.
- Logical viewport не измерен. Evidence — масштабированный поток; размеры PNG не являются viewport или pt-замерами.
- Конфигурация 270f0d4: Flutter 3.38.9, `flutter build ios --simulator --debug`, без явных dart-defines. Build logs не предоставлены.
- Актуальный `origin/main` после fetch: `c2b31962fbc3aa7dd695fd09497a981bd5305944`. Принадлежность Preview этому commit не установлена.

| Раздел | Реально пройдено |
|---|---|
| Hours | Light root/alternatives/bottom; Dark root и Full dock |
| Ora | Light начало/середина/конец и text-size; Dark body, Psalm choir; Full/Compact/Hidden и восстановление |
| Readings | Light default A, variants/manual B, selection; Dark root/body, применённый жёлтый highlight, Hidden/Full; в последней сессии cycle II, Dark variants sheet и абсолютный конец текста |
| Prayerbook | Light root/categories/all/Favorites/Holy Mass; Dark root и Full dock |
| Search | Light keyboard open/closed, результаты `ace`, dismiss/очистка; последняя сессия Dark keyboard/results `ave` и dismiss |
| Prayer detail | Light длинная молитва, bold/numbered Markdown, середина/конец/text-size; последняя сессия Dark ссылки/длинный body/прокрутка/text-size sheet |
| Bible | Light глава/picker/БЕЛ-РУС/verse selection/palette/конец; Dark конец и Full/Compact dock |
| Sheets | Light liturgical/Bible/text-size/variants; Dark settings, text-size, variants |

Compact device не проверен: быстрого переключателя устройства не было. Cycle C не просмотрен; persistence highlight после перезапуска не проверялась. Evidence: **15 PNG** в [audit-evidence/ios-visual](../audit-evidence/ios-visual/). Снимки 05 и 09 обновлены последней сессией с неподтверждённым SHA; остальные — предыдущие проходы.

# KEEP — do not regress

1. Иерархия Hours: крупный serif title, дата и спокойный литургический контекст ([01](../audit-evidence/ios-visual/01-hours-dock-light.png)).
2. Приглушённый зелёный акцент работает в Light/Dark без яркой панели ([12](../audit-evidence/ios-visual/12-hours-dock-dark.png)).
3. Родственные serif body, рубрики и paragraph rhythm Ora/Readings/prayer/Bible; typography system не менять.
4. Compact dock освобождает пространство; Full раскрывается, Hidden убирает controls и восстанавливается.
5. Text-size sheet короткий и понятный в обеих темах, с явным dismiss ([09](../audit-evidence/ios-visual/09-prayer-detail.png)).
6. Prayerbook: спокойные списки, Favorites отражают выбор; Holy Mass имеет полезные переходы к разделам.
7. Концы Ora/prayer/Bible/Readings доступны над dock; последняя строка Readings не обрезана ([05](../audit-evidence/ios-visual/05-readings-dark-bottom.png)).
8. Psalm choir различает партии приглушением строф без нового chrome ([15](../audit-evidence/ios-visual/15-ora-dark-hidden-choir.png)).

# P1

**0 подтверждённых.** Недоступных финальных строк, сломанной навигации или заблокированных действий не обнаружено. Это ограниченный визуальный pass, не accessibility certification.

# P2

**P2-1 — Недостаточная защита служебных краёв reader.** При прокрутке текст проходит под часами/Dynamic Island и floating controls, снизу виден около dock/palette/home indicator. Повторяется в Ora, Readings, prayer detail и Bible; Dark и Hidden не устраняют верхний конфликт. Это визуальная помеха, а не подтверждённая недоступность текста. Нужен общий мягкий edge/backdrop treatment. Evidence: [04](../audit-evidence/ios-visual/04-ora-reading-chrome.png), [11](../audit-evidence/ios-visual/11-bible-selection.png), [13](../audit-evidence/ios-visual/13-bible-dark-bottom.png), [15](../audit-evidence/ios-visual/15-ora-dark-hidden-choir.png).

**P2-2 — Cycle metadata выглядит как control и дублируется.** В manual B одновременно pill `Цыкл B`, текст `Цыкл B · зменены` и отдельное действие variants. Оставить одну текстовую metadata-строку; выбор сохранить в sheet ([06](../audit-evidence/ios-visual/06-readings-manual-cycle.png)).

**P2-3 — Нижний gap поиска в предыдущей Light-сессии.** После dismiss клавиатуры search bar почти касался home indicator, в отличие от dock/palettes ([14](../audit-evidence/ios-visual/14-search-home-indicator.png)). В последней Dark-сессии с запросом `ave` виден нормальный зазор. Причина различия не установлена: theme/state/build. Перед исправлением воспроизвести на одном SHA в обеих темах; не объявлять проблему актуальной для main. При клавиатуре поиск читаем и Search dismiss работает.

# P3

**P3-1 — Разное оформление alternatives.** Hours: тихая icon/text строка; Readings: outlined capsule. Согласовать secondary-action treatment, сохранив разные сценарии ([01](../audit-evidence/ios-visual/01-hours-dock-light.png), [06](../audit-evidence/ios-visual/06-readings-manual-cycle.png)).

# Global dock

**ADD SUBTLE SUPPORTING SURFACE.** Собственная glass-поверхность читаема; вокруг неё слишком заметен движущийся текст. Добавить мягкую подложку/градиент, сохраняя floating glass. Тяжёлая постоянная bottom bar не нужна.

Full/Compact не выглядят чрезмерно высокими или прижатыми к home indicator. Последние строки доступны, явного чрезмерного пустого хвоста не обнаружено. Hidden работает; верхний текстовый конфликт остаётся. Bible chapter capsule полезна. Двойная safe-area компенсация без измерений не утверждается.

# Readers

Body width, rubrics, references, bold и numbered lists ощущаются родственными. Основная помеха длительному чтению — текст в служебных краях. Sans-заголовки prayer detail отличаются от serif Hours/Readings, но это не выделено как дефект.

Cycle verdict: **TEXTUALIZE**. Просмотрены A/manual B, а в последней сессии II и выбор I/II в sheet.

# Overlays / sheets

Liturgical picker, Bible picker, variants и text-size имеют подходящую задачам высоту; унифицировать их detents не требуется. Dark text-size и variants сохраняют читаемый title, разделение surface/backdrop и понятный dismiss.

Readings/Bible palettes принадлежат одной glass-семье. Выделение Readings жёлтым применилось и осталось видно после закрытия palette; перезапуск не проверялся. Search с клавиатурой и без неё работал в обеих темах; различие нижнего gap требует проверки одного SHA.

# Visual paradigm mismatches

Три кандидата: cycle pill как control-like metadata; outlined alternatives capsule вместо тихого текстового входа Hours; красный счётчик `50` в Bible picker как notification badge (низкоприоритетный кандидат, не отдельный finding). Не приписывать Material-реализацию по одному виду.

# Recommended Sol batch

1. Общий iOS reader edge/backdrop treatment сверху и около dock/palette/home indicator. Проверить Light/Dark, Full/Compact/Hidden и последние строки.
2. Воспроизвести search gap на одном актуальном SHA в Light/Dark и keyboard open/closed; если расхождение сохраняется — общий нижний spacing rule с keyboard inset. Android geometry не переносить.
3. Заменить cycle pill/дубль одной textual metadata-строкой, сохранив variants sheet.
4. Согласовать secondary alternatives actions Hours/Readings без новой IA или постоянных controls.

Реализацию не начинали. Перед Sol batch сверить findings с актуальной сборкой main. [Resume notes](ios-ux-visual-audit-resume.md) фиксируют завершённое покрытие и ограничение SHA.
