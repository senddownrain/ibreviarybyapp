import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/utils/reading_alignment.dart';

/// Run with flutter run -d chrome -t tool/reading_alignment_smoke.dart.
/// Shows real readings from the bundled `assets/content/readings.json.gz`
/// under the adaptive prose alignment. Read-only; never connects to Firebase,
/// never writes data, no network (fonts come from assets/google_fonts).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final readings = decodeContentCollection(
    (await rootBundle.load(
      'assets/content/readings.json.gz',
    )).buffer.asUint8List(),
  );
  final items = <(String, String)>[];
  final ids = readings.docs.keys.toList()..sort();
  for (final id in ids) {
    for (final field in ['reading1', 'reading2', 'gospel']) {
      final part = readings.docs[id]![field];
      final text = part is Map ? part['text'] : null;
      if (text is String && text.length > 250 && !text.contains('<')) {
        items.add(('$id · $field', text));
      }
    }
  }
  runApp(_Smoke(items: items));
}

class _Smoke extends StatefulWidget {
  const _Smoke({required this.items});
  final List<(String, String)> items;
  @override
  State<_Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<_Smoke> {
  int index = 0;
  double width = 360;
  double scale = 1.0;
  TextAlign saved = TextAlign.justify;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.literata(
      fontSize: 16 * scale,
      height: 1.68,
      color: const Color(0xFF20211F),
    );
    final (label, raw) = widget.items[index];
    final text = raw.replaceAll(RegExp(r'\r?\n[ \t]*\r?\n+'), '\n');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<int>(
                      key: const Key('reading'),
                      value: index,
                      items: [
                        for (var i = 0; i < widget.items.length; i += 1)
                          DropdownMenuItem(
                            value: i,
                            child: Text(widget.items[i].$1),
                          ),
                      ],
                      onChanged: (v) => setState(() => index = v!),
                    ),
                    SegmentedButton<double>(
                      key: const Key('width'),
                      segments: [
                        for (final w in [320.0, 360.0, 390.0, 430.0])
                          ButtonSegment(value: w, label: Text('${w.round()}')),
                      ],
                      selected: {width},
                      onSelectionChanged: (v) => setState(() => width = v.first),
                    ),
                    SegmentedButton<double>(
                      key: const Key('scale'),
                      segments: [
                        for (final s in [1.0, 1.5, 1.8])
                          ButtonSegment(value: s, label: Text('${(s * 100).round()}%')),
                      ],
                      selected: {scale},
                      onSelectionChanged: (v) => setState(() => scale = v.first),
                    ),
                    SegmentedButton<TextAlign>(
                      key: const Key('saved'),
                      segments: const [
                        ButtonSegment(value: TextAlign.justify, label: Text('Па шырыні')),
                        ButtonSegment(value: TextAlign.left, label: Text('Па левым краі')),
                      ],
                      selected: {saved},
                      onSelectionChanged: (v) => setState(() => saved = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: width,
                  child: AdaptiveProseAlignment(
                    selected: saved,
                    style: style,
                    builder: (context, alignment) {
                      final cpl = charsPerLine(
                        maxWidth: width,
                        style: style,
                        textScaler: MediaQuery.textScalerOf(context),
                      );
                      return Container(
                        color: const Color(0xFFFDFCF9),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '$label\nsaved: ${saved.name} → shown: ${alignment.name} '
                              '(${cpl.toStringAsFixed(1)} знакаў/радок)',
                              key: const Key('status'),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9B302A)),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              text,
                              key: const Key('text'),
                              style: style,
                              textAlign: alignment,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
