import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_search_host.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

/// Compatibility for links created by the former hierarchy navigation.
class CompendiumNodeScreen extends StatelessWidget {
  const CompendiumNodeScreen({super.key, required this.nodeId});
  const CompendiumNodeScreen.part({super.key, required String partId})
    : nodeId = partId;
  final String nodeId;

  @override
  Widget build(BuildContext context) => CompendiumLegacyScreen(id: nodeId);
}

class CompendiumLegacyScreen extends ConsumerStatefulWidget {
  const CompendiumLegacyScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CompendiumLegacyScreen> createState() =>
      _CompendiumLegacyScreenState();
}

class _CompendiumLegacyScreenState
    extends ConsumerState<CompendiumLegacyScreen> {
  String? _scheduled;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compendiumIndexProvider);
    final index = state.valueOrNull;
    String? location;
    if (index != null) {
      final node = index.getNode(widget.id);
      if (node != null) {
        var part = node;
        while (part.parent != null) {
          part = part.parent!;
        }
        location = compendiumPartLocation(
          part.id,
          target: node.id == part.id ? null : node.id,
        );
      } else {
        final group = index.getGroup(widget.id);
        if (group != null) {
          location = compendiumPartLocation(
            group.unit.partId,
            target: group.questions.first.id,
          );
        } else {
          final unit = index.units
              .where((candidate) => candidate.id == widget.id)
              .firstOrNull;
          if (unit != null) {
            location = compendiumPartLocation(
              unit.partId,
              target: index.getQuestion(unit.firstQuestion)!.id,
            );
          }
        }
      }
    }
    if (location != null && _scheduled != location) {
      _scheduled = location;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement(location!);
      });
    }
    return CompendiumSearchHost(
      child: Scaffold(
        body: Center(
          child: state.isLoading || location != null
              ? const AppProgressLine(key: Key('compendium-loading'))
              : CompendiumMessage(
                  key: const Key('compendium-node-not-found'),
                  icon: PhosphorIconsLight.bookOpenText,
                  title: 'Раздзел не знойдзены',
                  message: 'Вярніцеся да зместу Кампендыя.',
                  action: TextButton(
                    onPressed: () => context.go(compendiumLocation()),
                    child: const Text('Да зместу'),
                  ),
                ),
        ),
      ),
    );
  }
}
