import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/admin_songbook_access_provider.dart';

/// This is distinct from anonymous priest-device activation.
class AdminSongbookLoginSection extends ConsumerWidget {
  const AdminSongbookLoginSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminSongbookAccessProvider).valueOrNull == true;
    return ListTile(
      key: const Key('settings-admin-login'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Адміністрацыйны доступ'),
      subtitle: Text(admin ? 'Вы ўвайшлі як адміністратар' : 'Уваход па email і паролі'),
      trailing: Icon(admin ? Icons.logout : Icons.login),
      onTap: admin
          ? () async {
              await FirebaseAuth.instance.signOut();
            }
          : () => showDialog<void>(
              context: context,
              builder: (_) => const _AdminLoginDialog(),
            ),
    );
  }
}

class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final credentials = await auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final uid = credentials.user?.uid;
      if (uid == null) throw StateError('No authenticated user');
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (!isAdminRecord(uid, doc.data())) {
        await auth.signOut();
        if (mounted) {
          setState(() => _error = 'Гэты ўліковы запіс не мае правоў адміністратара.');
        }
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException {
      if (mounted) setState(() => _error = 'Не атрымалася ўвайсці. Праверце email і пароль.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Не атрымалася праверыць доступ. Праверце злучэнне.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Уваход адміністратара'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('admin-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              key: const Key('admin-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Пароль'),
              onSubmitted: (_) => _signIn(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Скасаваць'),
      ),
      FilledButton(
        onPressed: _busy ? null : _signIn,
        child: const Text('Увайсці'),
      ),
    ],
  );
}
