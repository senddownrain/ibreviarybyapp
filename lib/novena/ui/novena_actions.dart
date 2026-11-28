import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_session.dart';
import 'package:mybrev_flutter/novena/ui/novena_routes.dart';

/// Runs a change of the local progress; a storage failure is said, not hidden.
/// The error itself is not logged: it could name a session.
Future<T?> runNovenaChange<T>(
  BuildContext context,
  Future<T> Function() change,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    return await change();
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Не ўдалося захаваць. Паспрабуйце яшчэ.')),
    );
    return null;
  }
}

/// The day page of a session. Ids travel in `extra`, never in the address.
void openNovenaDay(BuildContext context, NovenaSession session, int day) =>
    context.push(
      novenaDayLocation,
      extra: <String, Object>{'session': session.sessionId, 'day': day},
    );

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасаваць'),
          ),
          FilledButton(
            key: const Key('novena-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

/// «Спыніць» and «Распачаць нанова», both after a confirmation.
class NovenaSessionMenu extends ConsumerWidget {
  const NovenaSessionMenu({super.key, required this.session});

  final NovenaSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(supportedNovenaProvider(session.novenaId));
    return PopupMenuButton<String>(
      key: const Key('novena-session-menu'),
      tooltip: 'Дзеянні з навэннай',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) async {
        final restart = value == 'restart';
        final confirmed = await _confirm(
          context,
          title: restart ? 'Распачаць нанова?' : 'Спыніць навэнну?',
          message: restart
              ? 'Адзнакі гэтага разу не пяройдуць у новы.'
              : 'Навэнна знікне з актыўных. Яе можна распачаць зноў.',
          action: restart ? 'Распачаць нанова' : 'Спыніць',
        );
        if (!confirmed || !context.mounted) return;
        final controller = ref.read(novenaProvider.notifier);
        await runNovenaChange(context, () async {
          await controller.stop(session.sessionId);
          if (restart && supported != null) {
            await controller.start(supported.definition, supported.days);
          }
        });
      },
      itemBuilder: (context) => [
        if (supported != null)
          const PopupMenuItem(
            value: 'restart',
            child: Text('Распачаць нанова'),
          ),
        const PopupMenuItem(value: 'stop', child: Text('Спыніць навэнну')),
      ],
    );
  }
}
