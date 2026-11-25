import 'package:flutter/widgets.dart';

import 'be_hyphenator.dart';
import 'lab_core.dart';
import 'lab_scene.dart';

/// Interactive stand. Fully offline: no Firebase, no network, no Google Fonts.
///   flutter run -d chrome        (or -d macos)
void main() => runApp(const LabApp());

class LabApp extends StatefulWidget {
  const LabApp({super.key});
  @override
  State<LabApp> createState() => _LabAppState();
}

class _LabAppState extends State<LabApp> {
  BelarusianHyphenator? hyph;
  Mode mode = Mode.b2;
  Scenario scenario = Scenario.plain;
  String family = 'Literata';
  double scale = 1.8;
  double width = 360;
  bool dark = false;

  @override
  void initState() {
    super.initState();
    BelarusianHyphenator.loadAsset().then((h) => setState(() => hyph = h));
  }

  Widget chips<T>(
    String label,
    List<T> values,
    T current,
    String Function(T) name,
    void Function(T) set,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontFamily: 'Literata',
            fontSize: 13,
            color: Color(0xFF222222),
          ),
        ),
        for (final v in values)
          GestureDetector(
            onTap: () => setState(() => set(v)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: v == current
                  ? const Color(0xFF2F5F7E)
                  : const Color(0xFFDDDDDD),
              child: Text(
                name(v),
                style: TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 13,
                  color: v == current
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF222222),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = dark ? LabPalette.darkTheme : LabPalette.light;
    return WidgetsApp(
      color: p.bg,
      debugShowCheckedModeBanner: false,
      builder: (context, _) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFFEFEFEF),
          child: hyph == null
              ? const SizedBox()
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        chips<Mode>(
                          'Mode',
                          Mode.values,
                          mode,
                          (m) => '${m.tag} ${m.label}',
                          (v) => mode = v,
                        ),
                        const SizedBox(height: 6),
                        chips<Scenario>(
                          'Text',
                          Scenario.values,
                          scenario,
                          (s) => s.name,
                          (v) => scenario = v,
                        ),
                        const SizedBox(height: 6),
                        chips<String>(
                          'Font',
                          readerFonts,
                          family,
                          (s) => s,
                          (v) => family = v,
                        ),
                        const SizedBox(height: 6),
                        chips<double>(
                          'Scale',
                          const [1.0, 1.5, 1.8],
                          scale,
                          (s) => '${(s * 100).round()}%',
                          (v) => scale = v,
                        ),
                        const SizedBox(height: 6),
                        chips<double>(
                          'Width',
                          const [320, 360, 390, 430],
                          width,
                          (s) => '${s.round()}dp',
                          (v) => width = v,
                        ),
                        const SizedBox(height: 6),
                        chips<bool>(
                          'Theme',
                          const [false, true],
                          dark,
                          (b) => b ? 'dark' : 'light',
                          (v) => dark = v,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: width,
                          child: LabReading(
                            mode: mode,
                            scenario: scenario,
                            family: family,
                            scale: scale,
                            palette: p,
                            hyphenator: hyph!,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
