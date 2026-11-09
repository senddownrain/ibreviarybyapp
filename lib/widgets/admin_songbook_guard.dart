import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/admin_songbook_access_provider.dart';

/// The same gate is applied to the list and to individual song deep links.
class AdminSongbookGuard extends ConsumerWidget {
  const AdminSongbookGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminSongbookAccessProvider).valueOrNull == true;
    if (admin) return child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Раздзел недаступны'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/prayers'),
                child: const Text('Да малітоўніка'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
