import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';

class PriestAccessSettingsSection extends ConsumerStatefulWidget {
  const PriestAccessSettingsSection({super.key});
  @override
  ConsumerState<PriestAccessSettingsSection> createState() =>
      _PriestAccessSettingsSectionState();
}

class _PriestAccessSettingsSectionState
    extends ConsumerState<PriestAccessSettingsSection> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(priestAccessProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Доступ для святароў',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (access.registered) ...[
          const Text('Доступ актываваны'),
          const Text('Паўторна ўводзіць код не трэба.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: access.busy
                ? null
                : () async {
                    final controller = ref.read(priestAccessProvider.notifier);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Выключыць доступ?'),
                        content: const Text(
                          'Для паўторнай актывацыі спатрэбіцца код.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Скасаваць'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Выключыць'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      await controller.disable();
                    }
                  },
            child: const Text('Выключыць доступ'),
          ),
        ] else ...[
          const Text(
            'Увядзіце код адзін раз, каб атрымаць доступ да малітваў і абрадаў для святароў.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('priest-code'),
            controller: _code,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Код актывацыі'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('priest-device-name'),
            controller: _name,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Назва прылады / імя'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: access.busy
                ? null
                : () async {
                    FocusScope.of(context).unfocus();
                    final submittedCode = _code.text;
                    final controller = ref.read(priestAccessProvider.notifier);
                    await controller.activate(submittedCode, _name.text);
                    if (mounted &&
                        ref.read(priestAccessProvider).registered &&
                        _code.text == submittedCode) {
                      _code.clear();
                    }
                  },
            child: const Text('Адкрыць доступ'),
          ),
          if (access.helpText.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Дзе атрымаць код?'),
            SelectableText(access.helpText),
          ],
        ],
        if (access.busy) const LinearProgressIndicator(),
        if (access.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              access.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Малітвы для святароў даступныя пры злучэнні з інтэрнэтам.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
