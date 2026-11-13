import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/review/app_review_controller.dart';

/// «Ацаніць дадатак» (manual, always opens the store page) and the switch that
/// stops only the rare automatic request. Sits right under «Зваротная сувязь».
class AppReviewSettingsSection extends ConsumerStatefulWidget {
  const AppReviewSettingsSection({super.key});

  @override
  ConsumerState<AppReviewSettingsSection> createState() =>
      _AppReviewSettingsSectionState();
}

class _AppReviewSettingsSectionState
    extends ConsumerState<AppReviewSettingsSection> {
  @override
  void initState() {
    super.initState();
    ref.read(appReviewControllerProvider).load();
  }

  // Inline, not a SnackBar: on this pushed page a SnackBar from the root
  // messenger renders behind the page and the person would see nothing.
  bool _storeFailed = false;

  Future<void> _openStore() async {
    final opened = await ref.read(appReviewControllerProvider).openStore();
    if (!mounted) return;
    setState(() => _storeFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appReviewControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          ListTile(
            key: const Key('settings-rate-app'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.star_outline_rounded),
            title: const Text('Ацаніць дадатак'),
            subtitle: _storeFailed
                ? Text(
                    'Не атрымалася адкрыць краму',
                    key: const Key('settings-rate-app-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : const Text('Адкрыць старонку праграмы ў краме'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openStore,
          ),
          SwitchListTile(
            key: const Key('settings-review-optout'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Не прапаноўваць ацэнку'),
            subtitle: const Text(
              'Адключае рэдкія аўтаматычныя прапановы. Спасылка вышэй застаецца.',
            ),
            value: controller.autoPromptDisabled,
            onChanged: controller.setAutoPromptDisabled,
          ),
        ],
      ),
    );
  }
}
