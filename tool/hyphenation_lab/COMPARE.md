# Сравнение для визуального выбора

Все листы — реальные чтения из `assets/content`, один текст/тема/ширина/шрифт во всех колонках. Колонки: **A** сейчас | **AD** адаптивное (уже в `main`, #149) | **B2** justify + переносы | **D** left + переносы. Метрики и оговорки — в [REPORT.md](REPORT.md).

## Смотреть в таком порядке
| Что | Файл |
|---|---|
| Узкий экран + крупный шрифт (320 dp, 180 %) — жалоба пользователя | [out/real/epistle_Literata_180_320_light.png](out/real/epistle_Literata_180_320_light.png) |
| Типичный телефон, обычный шрифт (360 dp, 100 %) — где B2 выигрывает | [out/real/epistle_Literata_100_360_light.png](out/real/epistle_Literata_100_360_light.png) |
| Телефон, 150 % | [out/real/epistle_Literata_150_360_light.png](out/real/epistle_Literata_150_360_light.png) |
| Другие шрифты | [SourceSerif4](out/real/epistle_SourceSerif4_150_360_light.png), [OldStandardTT](out/real/epistle_OldStandardTT_150_360_light.png), [Kurale](out/real/epistle_Kurale_150_360_light.png) |
| Тёмная тема | [Literata 320/180](out/real/epistle_Literata_180_320_dark.png), [SourceSerif4 390/150](out/real/epistle_SourceSerif4_150_390_dark.png) |
| HTML-чтение | [out/real/html_real_Literata_150_360_light.png](out/real/html_real_Literata_150_360_light.png) |
| Выделение предложений (фикстура) | [светлая](out/highlight_Literata_150_360_light.png), [тёмная](out/highlight_Literata_180_320_dark.png) |
| Контроль: U+00AD не рисует дефис | [out/web_chrome_B1_softhyphen_no_hyphen.jpg](out/web_chrome_B1_softhyphen_no_hyphen.jpg) |

## Итоги по реальным чтениям (доля плохих строк, ниже — лучше)
| | 100 % | 150 % | 180 % |
|---|---|---|---|
| A (было) | 23 % | 43 % | 53 % |
| AD (в `main`) | 16 % | 13 % | 20 % |
| B2 (justify + переносы) | 6 % | 23 % | 32 % |
| D (left + переносы) | 1 % | 9 % | 14 % |

Строки оцениваются по реально применённому выравниванию; сравнивать можно внутри семейства (justify: A, B2; left: D).

## Что решить
1. **Оставить AD** (уже сделано) — ничего больше не делать.
2. **Добавить D** для режима «Па левым краі» (и для узких колонок вместо AD-left): лучший результат; нужен собственный рендерер и интеграция (выделение/копирование в нём реализованы и проверены в стенде; сенсорные ручки на устройстве не проверены).
3. **Добавить B2** для «Па шырыні» при ≥36 знаков в строке (заметно лучше A/AD при 100 % шрифта); те же затраты, что у D.
4. Любой из 2–3 — только после визуальной приёмки листов выше и отдельного PR с native smoke.

Рендерер в приложение **не интегрирован**; этот PR остаётся исследовательским стендом.
