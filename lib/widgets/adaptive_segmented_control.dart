import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/platform_design.dart';

class AdaptiveSegment<T extends Object> {
  final T value;
  final Widget label;
  final Widget? icon;

  const AdaptiveSegment({required this.value, required this.label, this.icon});
}

/// A compact choice control that follows the active platform design language.
class AdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
  final T value;
  final List<AdaptiveSegment<T>> segments;
  final ValueChanged<T> onChanged;
  final bool showSelectedIcon;

  const AdaptiveSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.showSelectedIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoGlass(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        children: {
          for (final segment in segments)
            segment.value: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (segment.icon != null) ...[
                    segment.icon!,
                    const SizedBox(width: 5),
                  ],
                  Flexible(child: segment.label),
                ],
              ),
            ),
        },
        onValueChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      );
    }

    return SegmentedButton<T>(
      showSelectedIcon: showSelectedIcon,
      segments: [
        for (final segment in segments)
          ButtonSegment<T>(
            value: segment.value,
            label: segment.label,
            icon: segment.icon,
          ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
