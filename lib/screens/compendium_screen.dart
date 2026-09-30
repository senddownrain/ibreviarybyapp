import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/screens/compendium_node_screen.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_search_host.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/floating_top_actions.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

/// `/prayers/compendium`: the four parts and local search.
///
/// Follows the songbook/prayer catalog contract: the search dock replaces the
/// app dock through the contextual bottom slot ([CompendiumSearchHost], shared
/// by every Compendium screen), and the query and scroll position survive
/// Question → Back.
class CompendiumScreen extends ConsumerStatefulWidget {
  const CompendiumScreen({super.key});

  @override
  ConsumerState<CompendiumScreen> createState() => _CompendiumScreenState();
}

class _CompendiumScreenState extends ConsumerState<CompendiumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(compendiumRefreshProvider)();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const CompendiumSearchHost(inlineResults: true, child: _CompendiumRoot());
}

class _CompendiumRoot extends ConsumerWidget {
  const _CompendiumRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final index = ref.watch(compendiumIndexProvider);
    final searching =
        CompendiumSearchScope.maybeOf(context)?.showingResults ?? false;

    final header = <Widget>[
      Text(
        'Каталіцкі Касцёл',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: GlassTokens.of(context).accentOnSurface(cs.tertiary),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        kCompendiumTitle,
        key: const Key('compendium-title'),
        style: Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        index.valueOrNull == null
            ? 'Катэхізіс у пытаннях і адказах'
            : '${index.requireValue.questions.length} пытанняў і адказаў',
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 14),
    ];

    final List<Widget> body;
    if (index.hasError && !index.hasValue) {
      body = [
        CompendiumMessage(
          key: const Key('compendium-error'),
          icon: PhosphorIconsLight.cloudSlash,
          title: 'Не атрымалася адкрыць Кампендый',
          message:
              'Паспрабуйце яшчэ раз або сінхранізуйце Кампендый у наладах.',
          action: TextButton(
            onPressed: () => ref.invalidate(compendiumBundledProvider),
            child: const Text('Паўтарыць'),
          ),
        ),
      ];
    } else if (!index.hasValue) {
      body = const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: AppProgressLine(key: Key('compendium-loading')),
        ),
      ];
    } else if (searching) {
      body = compendiumSearchResultItems(context, ref);
    } else {
      final data = index.requireValue;
      body = [
        for (final part in data.parts)
          CompendiumListRow(
            key: ValueKey('compendium-part-${part.id}'),
            leading: CompendiumBadge(label: romanNumeral(part.number)),
            eyebrow: part.label,
            title: part.title,
            subtitle: switch (data.partRange(part.id)) {
              (final first, final last) => 'Пытанні $first–$last',
              null => null,
            },
            onTap: () => context.push(compendiumPartLocation(part.id)),
          ),
        const CompendiumSourceAttribution(),
      ];
    }

    final children = [...header, ...body];
    return Scaffold(
      body: Stack(
        children: [
          AmbientWash(
            seasonColor: cs.tertiary,
            child: ListView.builder(
              key: const PageStorageKey('compendium-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 90,
                20,
                104 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: children.length,
              itemBuilder: (context, index) => children[index],
            ),
          ),
          FloatingTopActions(showBack: true, seasonColor: cs.tertiary),
        ],
      ),
    );
  }
}

/// `/prayers/compendium/part/:partId`: the compact outline of a part, its
/// sections only. Questions and subsections are one level down, on the
/// section's own [CompendiumNodeScreen].
class CompendiumPartScreen extends StatelessWidget {
  const CompendiumPartScreen({super.key, required this.partId});

  final String partId;

  @override
  Widget build(BuildContext context) =>
      CompendiumNodeScreen.part(partId: partId);
}
