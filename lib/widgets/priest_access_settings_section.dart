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
  bool _addingCode = false;
  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(priestAccessProvider);
    final nativeOffline = ref.watch(protectedCatalogStorageProvider) != null;
    final showForm =
        !access.pendingDisable &&
        (!access.registered || (access.canAddCode && _addingCode));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Асаблівы доступ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Для святароў і кансэкраваных асобаў',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (access.pendingDisable)
          const Text('Чакаем пацвярджэння выключэння доступу.'),
        if (access.registered) ...[
          const Text('Доступ актываваны'),
          const Text('Паўторна ўводзіць код не трэба.'),
          if (nativeOffline && access.catalogLoading) ...[
            const SizedBox(height: 8),
            const Text('Спампоўваем малітвы…'),
            const LinearProgressIndicator(),
          ] else if (access.offlineReady)
            const Text('Малітвы даступныя афлайн'),
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
          if (access.canAddCode && !_addingCode)
            TextButton(
              onPressed: access.busy
                  ? null
                  : () => setState(() => _addingCode = true),
              child: const Text('Увесці яшчэ адзін код'),
            ),
        ],
        if (showForm) ...[
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
            onPressed: access.busy || access.quotaBlocked
                ? null
                : () async {
                    FocusScope.of(context).unfocus();
                    final submittedCode = _code.text;
                    _code.clear();
                    final controller = ref.read(priestAccessProvider.notifier);
                    await controller.activate(submittedCode, _name.text);
                    if (mounted &&
                        ref.read(priestAccessProvider).registered &&
                        ref.read(priestAccessProvider).error == null) {
                      setState(() => _addingCode = false);
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
        if (access.quotaBlocked)
          TextButton(
            onPressed: ref.read(priestAccessProvider.notifier).retryAfterQuota,
            child: const Text('Паўтарыць праверку доступу'),
          ),
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
          nativeOffline
              ? 'Пасля спампоўвання малітвы даступныя без інтэрнэту.'
              : 'Дадатковыя малітвы даступныя пры злучэнні з інтэрнэтам.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
