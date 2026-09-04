import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/platform_app_bar.dart';

class PrayerFormScreen extends ConsumerStatefulWidget {
  /// null = add mode; non-null = edit mode.
  final String? prayerId;

  const PrayerFormScreen({super.key, this.prayerId});

  @override
  ConsumerState<PrayerFormScreen> createState() => _PrayerFormScreenState();
}

class _PrayerFormScreenState extends ConsumerState<PrayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;

  bool _saving = false;
  bool _deleting = false;

  Prayer? _original;

  @override
  void initState() {
    super.initState();
    final id = widget.prayerId;
    if (id != null) {
      _original = ref.read(localPrayersProvider).where((p) => p.id == id).firstOrNull;
    }
    _title = TextEditingController(text: _original?.displayTitle ?? '');
    _body = TextEditingController(text: _original?.body ?? '');
    _tags = TextEditingController(text: _original?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.prayerId != null;

  List<String> _parseTags(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(localPrayersProvider.notifier);
      final title = _title.text.trim();
      final body = _body.text.trim();
      final tags = _parseTags(_tags.text);

      if (_isEdit && _original != null) {
        await notifier.update(
          _original!.copyWith(title: title, body: body.isEmpty ? null : body, tags: tags),
        );
      } else {
        await notifier.create(
          title: title,
          body: body.isEmpty ? null : body,
          tags: tags,
        );
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_deleting || _original == null) return;
    setState(() => _deleting = true);
    try {
      await ref.read(localPrayersProvider.notifier).delete(_original!.id);
      if (mounted) {
        // Pop both the form and the detail screen if we came from there.
        context.go('/my-prayers');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PlatformAppBar(
        title: Text(_isEdit ? 'Рэдагаваць малітву' : 'Новая малітва'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Выдаліць малітву',
              icon: _deleting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const PhosphorIcon(PhosphorIconsRegular.trash, size: 20),
              onPressed: _deleting ? null : _delete,
            ),
          IconButton(
            tooltip: 'Захаваць',
            icon: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const PhosphorIcon(PhosphorIconsRegular.floppyDisk, size: 22),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: AmbientWash(
        seasonColor: seasonColor,
        height: 220,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, topPad + kToolbarHeight + 12, 12, 40),
            children: [
              GlassSurface(
                style: GlassStyle.card,
                seasonColor: seasonColor,
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Назва *',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Увядзіце назву малітвы' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _body,
                      decoration: const InputDecoration(
                        labelText: 'Тэкст',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 12,
                      minLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tags,
                      decoration: InputDecoration(
                        labelText: 'Тэгі',
                        hintText: 'ранішняя, вечар, пакаяне',
                        border: const OutlineInputBorder(),
                        helperText: 'Праз коску',
                        helperStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const PhosphorIcon(PhosphorIconsRegular.floppyDisk, size: 20),
                label: Text(_isEdit ? 'Захаваць змены' : 'Дадаць малітву'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
