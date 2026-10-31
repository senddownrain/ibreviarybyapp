import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/ui/inline_hint_presenter.dart';

/// Place right below an existing control. Renders nothing unless the engine
/// has chosen a hint for one of [anchorIds]; [onShow] must be the very same
/// callback the anchor control runs when tapped.
class DiscoveryHintSlot extends ConsumerStatefulWidget {
  const DiscoveryHintSlot({super.key, required this.anchorIds, this.onShow});

  final List<String> anchorIds;
  final VoidCallback? onShow;

  @override
  ConsumerState<DiscoveryHintSlot> createState() => _DiscoveryHintSlotState();
}

class _DiscoveryHintSlotState extends ConsumerState<DiscoveryHintSlot> {
  InlineHintPresenter? _presenter;

  @override
  void initState() {
    super.initState();
    final presenter = ref.read(hintPresenterProvider);
    if (presenter is InlineHintPresenter) {
      _presenter = presenter..registerSlot(widget.anchorIds);
      presenter.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _presenter
      ?..removeListener(_changed)
      ..unregisterSlot(widget.anchorIds);
    super.dispose();
  }

  Future<void> _respond(HintDefinition hint, HintResponse response) async {
    final coordinator = await ref.read(discoveryCoordinatorProvider.future);
    await coordinator.respond(hint.id, response);
  }

  @override
  Widget build(BuildContext context) {
    final presenter = _presenter;
    final hint = presenter?.shown;
    if (hint == null || !widget.anchorIds.contains(hint.anchorId)) {
      return const SizedBox.shrink();
    }
    final coordinator = ref.read(discoveryCoordinatorProvider).asData?.value;
    final canSnooze =
        hint.allowSnooze &&
        coordinator != null &&
        coordinator.policy.canSnooze(
          hint,
          coordinator.repository.state.record(hint.id),
        );
    return DiscoveryHintCard(
      hint: hint,
      onAction: hint.actionLabelBe == null
          ? null
          : () {
              _respond(hint, HintResponse.acted);
              widget.onShow?.call();
            },
      onAcknowledge: hint.actionLabelBe == null
          ? () => _respond(hint, HintResponse.acknowledged)
          : null,
      onLater: canSnooze ? () => _respond(hint, HintResponse.later) : null,
      onNever: () => _respond(hint, HintResponse.never),
    );
  }
}

/// The small card itself: text and at most three plain buttons.
class DiscoveryHintCard extends StatelessWidget {
  const DiscoveryHintCard({
    super.key,
    required this.hint,
    this.onAction,
    this.onAcknowledge,
    this.onLater,
    required this.onNever,
  });

  final HintDefinition hint;
  final VoidCallback? onAction;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onLater;
  final VoidCallback onNever;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface);
    return Semantics(
      container: true,
      label: 'Падказка. ${hint.copyBe}',
      child: Container(
        key: Key('discovery-card-${hint.id}'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Text(hint.copyBe, style: textStyle)),
            const SizedBox(height: 2),
            Wrap(
              children: [
                if (onAction != null)
                  TextButton(
                    key: const Key('discovery-hint-show'),
                    onPressed: onAction,
                    child: Text(hint.actionLabelBe!),
                  ),
                if (onAcknowledge != null)
                  TextButton(
                    key: const Key('discovery-hint-ack'),
                    onPressed: onAcknowledge,
                    child: const Text('Зразумела'),
                  ),
                if (onLater != null)
                  TextButton(
                    key: const Key('discovery-hint-later'),
                    onPressed: onLater,
                    child: const Text('Пазней'),
                  ),
                TextButton(
                  key: const Key('discovery-hint-never'),
                  onPressed: onNever,
                  child: const Text('Не паказваць'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
