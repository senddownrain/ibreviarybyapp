import 'package:flutter/material.dart';

class SettingsReaderRow extends StatelessWidget {
  const SettingsReaderRow({
    super.key,
    required this.label,
    required this.controlWidth,
    required this.inlineWidth,
    required this.control,
  });

  final String label;
  final double controlWidth;
  final double inlineWidth;
  final Widget control;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Text(label, style: Theme.of(context).textTheme.titleSmall);
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final requiredWidth = controlWidth + (inlineWidth - controlWidth) * scale;
      if (constraints.maxWidth < requiredWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(width: controlWidth, child: control),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 8),
          SizedBox(width: controlWidth, child: control),
        ],
      );
    },
  );
}

class SettingsReaderPreview extends StatelessWidget {
  const SettingsReaderPreview({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}
