# hyphenation_lab — белорусские переносы во Flutter (изолированный стенд)

Не часть приложения: свой `pubspec.yaml`, **без Firebase, без сети, без google_fonts**.
Шрифты — копии из `assets/google_fonts/` (OFL), паттерны — `assets/patterns/hyph-be.tex` (MIT).
Полный отчёт: [REPORT.md](REPORT.md). Скриншоты и метрики: `out/`.

```bash
cd tool/hyphenation_lab
flutter pub get
flutter test                       # 230 тестов, перегенерирует out/*.png и out/metrics.json
python3 summarize_metrics.py       # сводка метрик
flutter run -d chrome              # интерактивный стенд (режимы A/B1/B2/C/D, шрифт, масштаб, ширина, тема)
./compare_sdk.sh 3.41.4            # изолированная проверка U+00AD на другой версии Flutter
```
