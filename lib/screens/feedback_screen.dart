import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Same message => same id (a retry never duplicates); an edited message => a new id.
  final _attempt = FeedbackAttempt(_newRequestId);
  bool _offline = false;
  bool _copied = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  @override
  void initState() {
    super.initState();
    _context = widget.context;
    _category = widget.context == null
        ? FeedbackCategory.other
        : FeedbackCategory.textError;
    _service = widget.service;
    _watchConnectivity();
    if (_service == null) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted)
          setState(() => _service = FeedbackService(appVersion: info.version));
      });
    }
  }

  /// Offline is announced up front; typing stays possible and nothing is lost.
  Future<void> _watchConnectivity() async {
    try {
      final connectivity = Connectivity();
      bool off(List<ConnectivityResult> r) =>
          r.isNotEmpty && r.every((e) => e == ConnectivityResult.none);
      final first = await connectivity.checkConnectivity();
      if (mounted) setState(() => _offline = off(first));
      _connectivity = connectivity.onConnectivityChanged.listen((r) {
        if (mounted) setState(() => _offline = off(r));
      });
    } catch (_) {
      // No plugin (tests, unsupported platform): a failed send reports the network state.
    }
  }

  @override
  void dispose() {
    _connectivity?.cancel();
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
    FeedbackFailure.rejected || FeedbackFailure.requestIdReused =>
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
    final payload = [
      _category.code,
      _body.text.trim(),
      _email.text.trim(),
      _context?.toJson(),
    ];
    Future<String> submit() => service.submit(
      category: _category,
      body: _body.text,
      email: _email.text,
      context: _context,
      requestId: _attempt.idFor(payload),
    );
    try {
      String id;
      try {
        id = await submit();
      } on FeedbackException catch (e) {
        if (e.failure != FeedbackFailure.requestIdReused) rethrow;
        _attempt
            .reset(); // the Worker saw this id with other text: one fresh id
        id = await submit();
      }
      if (!mounted) return;
      _attempt.reset();
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
          Container(
            key: const Key('feedback-success'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Дзякуй! Паведамленне прынята.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text('Нумар звароту', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                SelectableText(
                  _sentId!,
                  key: const Key('feedback-id'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('feedback-copy'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _sentId!));
                    if (mounted) setState(() => _copied = true);
                  },
                  child: Text(_copied ? 'Скапіявана' : 'Скапіяваць нумар'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('feedback-return'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Вярнуцца да чытання'),
                ),
                TextButton(
                  key: const Key('feedback-again'),
                  onPressed: () => setState(() {
                    _sentId = null;
                    _copied = false;
                    _context = null;
                    _category = FeedbackCategory.other;
                  }),
                  child: const Text('Напісаць яшчэ'),
                ),
              ],
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
        if (_offline) ...[
          const SizedBox(height: 12),
          Text(
            'Няма сеткі. Можна напісаць цяпер — адправіце, калі злучэнне вернецца.',
            key: const Key('feedback-offline'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
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
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              key: const Key('feedback-context'),
              avatar: const Icon(Icons.flag_outlined, size: 16),
              label: Text(
                _context!.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              deleteIcon: const Icon(
                Icons.close_rounded,
                key: Key('feedback-context-remove'),
                size: 18,
              ),
              deleteButtonTooltipMessage: 'Прыбраць кантэкст',
              onDeleted: () => setState(() => _context = null),
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
              : Text(_error != null ? 'Паспрабаваць яшчэ раз' : 'Адправіць'),
        ),
      ],
    );
  }
}
