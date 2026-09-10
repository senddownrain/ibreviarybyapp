# Stage 10 — Final Liturgical Reader + Product Finishing

Дата: 2026-09-10  
Ветка: `feature/mobile-ux-migration`  
Starting SHA: `c05b1181a69b3eceea56b2799ea7841c56da7387`

## Commits

- `30be83d` — `fix: restore liturgical renderer parity and Compline`
- `94575f7` — `refactor: adapt liturgical text presentation for mobile`
- `34f43ea` — `feat: finalize secondary navigation and Prayerbook shortcuts`
- `docs: finalize Stage 10 implementation` — этот отчёт и resolution Stage 9 matrix.

## PWA parity fixes

- Mixed red fragments больше не классифицируют весь paragraph как metadata.
- Cadence `*`/`†` поддерживает literal, named, decimal и hex entities; удаляется только непосредственный legacy `<br>`.
- Embedded antiphon удаляется только при совпадающем external antiphon.
- Legacy R1/R2 headings не дублируют structural heading.
- Structured psalm alternatives сохраняют internal antiphon/psalm/repeat package и полный option content.
- Intercession intro/refrain/petition/response/conclusion и dash marker сохраняют исходный текст.
- Inline Scripture reference размечается только в reading-heading context.
- Readings поддерживает `verse || text`, lone `altChorus` и HTML-safe closing detection.

## Compline

`completoriumRecordIdForDay` является общим availability adapter для Hours root, Hora picker и change-hour sheet. Он использует существующие `completoriumId`, `usesSundayCompletorium`, Holy Week → Lent alias, weekday/solemnity rules и отдельный `HiveService.completoriumsBox`. Ora продолжает загружать static collection до rendering; cached record открывается offline, missing record показывает спокойное sync state вместо пустого reader.

## Reader visual roles

ReaderTheme содержит небольшой vocabulary: major heading, block heading, metadata/reference, rubric block, inline rubric и body. Ora/Readings применяют единые readable minima, normal case для app-owned labels и text-based hierarchy. Antiphons, responsorial refrains и intercession refrain больше не являются UI cards. Source `em/strong` сохраняется, а conflicting legacy alignment, indent и font size нормализуются после role detection.

## Alternatives

Большой inline list заменён на компактный `Варыянт X з N` action и scrollable adaptive bottom sheet. Sheet показывает titles, selected state и порядковый контекст. Выбор меняет только текущий block; repeat antiphon использует shared controller без второго picker. Controller keys разделены по document section, включая независимые Office/Laudes blocks в Combined Morning. Покрыты 2 и 7 options, long Belarusian titles, width 320 и system text 200%.

## Ora and Readings

Ora использует спокойные headings, текстовые antiphons/refrains, native metadata и rubric roles; compact biography и fullscreen flow сохранены. Psalm packages не flatten, cadence/strophes и meaningful breaks сохраняются. Readings сохраняет собственную структуру: reading, muted reference, psalm, second reading, acclamation и Gospel; reference остаётся под heading. Closing formula выводится один раз.

## Secondary navigation, Settings, Holy Mass

Full Drawer убран из ordinary flow. Root menu содержит только `Налады`, `Сінхранізацыя`, `Інфармацыя`; Sync открывает существующую Settings section и не запускается автоматически. Nested screens сохраняют Back.

Settings сохраняет theme, text size, keep-awake, start/last section и sync. Cache counts/coverage перенесены в expandable `Дыягностыка`; полное about content остаётся в Information.

Prayerbook hierarchy: `Абраныя → Святая Імша → Катэгорыі → Усе малітвы`. Shortcut использует существующую prayer entity `eMmCtxwyJ75ogmL5rwye`, не создаёт branch/schema/favorite. Loading показывает progress; missing показывает `Тэкст пакуль недаступны` и путь к sync; cached entity открывает canonical prayer route.

## Verification

- `dart analyze` — PASS, 0 issues.
- `flutter analyze` — PASS, 0 issues.
- `flutter test` — PASS, 129 tests.
- `flutter build web --dart-define=IBREVIARY_PLATFORM=android` — PASS (`build/web`, 140.0 s).
- `flutter build web --no-wasm-dry-run --dart-define=IBREVIARY_PLATFORM=ios` — PASS (`build/web`, 96.3 s).
- `GeneratedPluginRegistrant.java` не включён в Stage 10 changes.

## Remaining native/device QA

- iOS/Android physical-device visual comparison in Light/Dark at widths 320/390.
- System text 100/150/200% and Aa 70/100/130/180% across all nine hour compositions.
- VoiceOver/TalkBack semantics, focus return from alternative sheet, safe areas and fullscreen restore hit target.
- Production-data spot checks for Compline/invitatorium collections and the full Stage 9 corpus.

Stage 10 implementation is **ready for final native/device QA and final diff review**. No merge to `main` was performed.
