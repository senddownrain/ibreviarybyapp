import 'dart:math';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:mybrev_flutter/feedback/feedback_models.dart';
import 'package:mybrev_flutter/feedback/feedback_service.dart';

String _newRequestId() {
  final r = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
}

/// «Зваротная сувязь»: no login, no pop-ups; the typed text survives any failure and is re-sent only by the user.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.context, this.service});

  /// Safe automatic context (removable by the user).
  final FeedbackContext? context;

  /// Injectable for tests.
  final FeedbackService? service;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _body = TextEditingController();
  final _email = TextEditingController();
  FeedbackService? _service;
  FeedbackCategory _category = FeedbackCategory.textError;
  FeedbackContext? _context;
  String? _bodyError;
  String? _emailError;
  String? _error;
  String? _sentId;
  bool _sending = false;
  final String _requestId =
      _newRequestId(); // one id per composed message => no duplicates

  @override
  void initState() {
    super.initState();
    _context = widget.context;
    _service = widget.service;
    if (_service == null) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted)
          setState(() => _service = FeedbackService(appVersion: info.version));
      });
    }
  }

  @override
  void dispose() {
    _body.dispose();
    _email.dispose();
    super.dispose();
  }

  String _message(FeedbackFailure f) => switch (f) {
    FeedbackFailure.network =>
      'Няма сеткі. Тэкст захаваны — націсніце «Адправіць», калі злучэнне вернецца.',
    FeedbackFailure.rateLimited =>
      'Занадта шмат спроб. Пачакайце хвіліну і націсніце «Адправіць» яшчэ раз.',
    FeedbackFailure.unavailable =>
      'Сервіс часова недаступны. Тэкст захаваны — паспрабуйце пазней.',
    FeedbackFailure.notConfigured => 'Адпраўка пакуль не падключана.',
    FeedbackFailure.rejected =>
      'Не атрымалася адправіць. Праверце тэкст і паспрабуйце яшчэ раз.',
  };

  Future<void> _send() async {
    if (_sending) return;
    final bodyError = validateFeedbackBody(_body.text);
    final emailError = validateFeedbackEmail(_email.text);
    setState(() {
      _bodyError = bodyError;
      _emailError = emailError;
      _error = null;
    });
    if (bodyError != null || emailError != null) return;
    final service = _service;
    if (service == null) return;
    setState(() => _sending = true);
    try {
      final id = await service.submit(
        category: _category,
        body: _body.text,
        email: _email.text,
        context: _context,
        requestId: _requestId,
      );
      if (!mounted) return;
      setState(() {
        _sentId = id;
        _body.clear();
      });
    } on FeedbackException catch (e) {
      if (mounted) setState(() => _error = _message(e.failure));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = _service?.configured ?? kFeedbackApiUrl.isNotEmpty;
    if (_sentId != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('feedback-success'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Дзякуй! Паведамленне прынята.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText('Нумар звароту: $_sentId'),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Напішыце нам — уваход не патрэбны. Мы чытаем кожнае паведамленне.',
          style: theme.textTheme.bodyLarge,
        ),
        if (!configured) ...[
          const SizedBox(height: 12),
          Text(
            'Адпраўка пакуль не падключана.',
            key: const Key('feedback-not-configured'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 16),
        Text('Што вы хочаце паведаміць?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            key: const Key('feedback-categories'),
            scrollDirection: Axis.horizontal,
            itemCount: FeedbackCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = FeedbackCategory.values[i];
              return Center(
                child: ChoiceChip(
                  key: Key('feedback-category-${c.code}'),
                  label: Text(c.label),
                  selected: _category == c,
                  showCheckmark: false,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _category = c),
                ),
              );
            },
          ),
        ),
        if (_context != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('feedback-context'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Кантэкст: ${_context!.summary}')),
                TextButton(
                  key: const Key('feedback-context-remove'),
                  onPressed: () => setState(() => _context = null),
                  child: const Text('Прыбраць'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('feedback-body'),
          controller: _body,
          minLines: 5,
          maxLines: 10,
          maxLength: kFeedbackMaxLength,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: 'Ваша паведамленне',
            errorText: _bodyError,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _bodyError = null),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('feedback-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'Email для адказу (неабавязкова)',
            errorText: _emailError,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _emailError = null),
        ),
        const SizedBox(height: 8),
        Text(
          'Не ўказвайце асабістыя даныя, якія не патрэбныя для звароту. Email бачыць толькі галоўны адміністратар.',
          style: theme.textTheme.bodySmall,
        ),
        ExpansionTile(
          key: const Key('feedback-privacy'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Якія даныя адпраўляюцца'),
          children: const [
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Адпраўляюцца: тып звароту, тэкст паведамлення, платформа і версія праграмы, бачны вам кантэкст матэрыялу (калі не прыбралі) і email, калі вы яго ўказалі. Не адпраўляюцца: IP-адрас, гісторыя чытання, налады, ідэнтыфікатары прылады. Звароты захоўваюцца, пакуль апрацоўваюцца, і выдаляюцца праз 180 дзён пасля закрыцця. Каб выдаліць свой зварот раней, напішыце з тым жа email.',
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            key: const Key('feedback-error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('feedback-submit'),
          onPressed: _sending || !configured ? null : _send,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Адправіць'),
        ),
      ],
    );
  }
}
