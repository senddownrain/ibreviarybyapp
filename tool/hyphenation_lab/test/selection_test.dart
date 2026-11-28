import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What copy/selection/accessibility do with U+00AD on the Flutter under test.
void main() {
  testWidgets(
    'B1 control: copying a SelectableText with soft hyphens yields U+00AD',
    (t) async {
      const text = 'Дабраслаў­лённы удзяч­насць';
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String?;
          return null;
        },
      );
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: SelectableText(text))),
      );
      final state = t.state<EditableTextState>(find.byType(EditableText));
      state.selectAll(SelectionChangedCause.toolbar);
      state.copySelection(SelectionChangedCause.toolbar);
      await t.pump();
      expect(copied, isNotNull);
      // ignore: avoid_print
      print(
        'COPIED contains U+00AD: ${copied!.contains('­')}  (${copied!.replaceAll('­', '<SHY>')})',
      );
      expect(
        copied,
        text,
        reason: 'copy returns the polluted string, not the clean quote',
      );
      expect(copied!.contains('­'), isTrue);
      // Accessibility: the screen reader label carries the invisible characters too.
      final sem = t.getSemantics(find.byType(EditableText));
      expect(sem.value.contains('­') || sem.label.contains('­'), isTrue);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    },
  );
}
