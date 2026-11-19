import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mybrev_flutter/discovery/tour/tour_steps.dart';

/// The quiet invitation: a small card above the dock, nothing dimmed, no
/// barrier. Ignoring it costs nothing.
class TourInvitation extends StatelessWidget {
  const TourInvitation({
    super.key,
    required this.dockTop,
    required this.onAccept,
    required this.onDecline,
  });

  /// Top edge of the dock in screen coordinates, if one is visible.
  final double? dockTop;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final bottom = dockTop != null
        ? math.max(8.0, height - dockTop! + 8)
        : media.padding.bottom + 96;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: math.max(160, height * 0.45),
          ),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: Material(
              key: const Key('tour-invitation'),
              color: scheme.surfaceContainerHigh,
              elevation: 6,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Паказаць, як карыстацца дадаткам?',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Некалькі кароткіх крокаў. '
                              'Можна прапусціць у любы момант.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        children: [
                          TextButton(
                            key: const Key('tour-invite-decline'),
                            onPressed: onDecline,
                            child: const Text('Не зараз'),
                          ),
                          FilledButton(
                            key: const Key('tour-invite-accept'),
                            onPressed: onAccept,
                            child: const Text('Паказаць'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A step of the running tour: light scrim with a ring around the real
/// control, and a card with the text and the buttons.
class TourLayer extends StatelessWidget {
  const TourLayer({
    super.key,
    required this.session,
    required this.anchor,
    required this.waiting,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TourSession session;

  /// Screen rectangle of the control; null while it is being looked for.
  final Rect? anchor;
  final bool waiting;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final rect = anchor;
    return Positioned.fill(
      child: BlockSemantics(
        child: Stack(
          key: const Key('tour-layer'),
          children: [
            // Swallows taps so nothing behind the tour is triggered.
            Positioned.fill(
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    painter: rect == null
                        ? null
                        : _SpotlightPainter(
                            rect.inflate(session.current.spotlightPadding),
                            Colors.black.withValues(alpha: 0.38),
                            Theme.of(context).colorScheme.primary,
                          ),
                  ),
                ),
              ),
            ),
            if (rect != null && !waiting)
              _StepCard(
                session: session,
                anchor: rect,
                onNext: onNext,
                onBack: onBack,
                onSkip: onSkip,
              ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole, this.scrim, this.ring);

  final Rect hole;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(14));
    final bounds = Offset.zero & size;
    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addRRect(rrect);
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawPath(scrimPath, Paint()..color = scrim);
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.scrim != scrim || old.ring != ring;
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.session,
    required this.anchor,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TourSession session;
  final Rect anchor;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final size = media.size;
    const gap = 14.0;
    final spaceAbove = anchor.top - media.padding.top - gap;
    final spaceBelow = size.height - anchor.bottom - media.padding.bottom - gap;
    final below = spaceBelow >= spaceAbove;
    final room = math.max(150.0, below ? spaceBelow : spaceAbove);
    final step = session.current;
    final width = math.min(400.0, size.width - 24);
    final left = (anchor.center.dx - width / 2)
        .clamp(12.0, math.max(12.0, size.width - width - 12))
        .toDouble();
    final card = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: room),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        scopesRoute: true,
        namesRoute: true,
        label: 'Тур па дадатку, крок ${session.progressBe}',
        child: Material(
          key: const Key('tour-card'),
          color: scheme.surfaceContainerHigh,
          elevation: 8,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: 'Крок ${session.progressBe}',
                          excludeSemantics: true,
                          child: Text(
                            session.progressBe,
                            key: const Key('tour-progress'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Semantics(
                          header: true,
                          child: Text(
                            step.titleBe,
                            key: const Key('tour-title'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.bodyBe,
                          key: const Key('tour-body'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        key: const Key('tour-skip'),
                        onPressed: onSkip,
                        child: const Text('Прапусціць'),
                      ),
                      if (!session.isFirst)
                        TextButton(
                          key: const Key('tour-back'),
                          onPressed: onBack,
                          child: const Text('Назад'),
                        ),
                      FilledButton(
                        key: const Key('tour-next'),
                        onPressed: onNext,
                        child: Text(session.isLast ? 'Гатова' : 'Далей'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Positioned(
      left: left,
      top: below ? anchor.bottom + gap : null,
      bottom: below ? null : size.height - anchor.top + gap,
      child: card,
    );
  }
}
