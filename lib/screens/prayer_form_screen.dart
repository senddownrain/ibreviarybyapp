import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';

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
  final FocusNode _bodyFocus = FocusNode();

  bool _saving = false;
  bool _deleting = false;
  bool _showPreview = false;

  Prayer? _original;

  @override
  void initState() {
    super.initState();
    final id = widget.prayerId;
    if (id != null) {
      _original = ref
          .read(localPrayersProvider)
          .where((p) => p.id == id)
          .firstOrNull;
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
    _bodyFocus.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.prayerId != null;

  List<String> _parseTags(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  bool get _hasLegacyHtml {
    final originalBody = _original?.body ?? '';
    return _original?.textFormat != localPrayerTextFormat &&
        RegExp(r'<[a-z][^>]*>', caseSensitive: false).hasMatch(originalBody);
  }

  void _wrapSelection(String before, String after, String placeholder) {
    final value = _body.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start;
    final end = selection.end;
    final selected = value.text.substring(start, end);
    final content = selected.isEmpty ? placeholder : selected;
    final replacement = '$before$content$after';
    final text = value.text.replaceRange(start, end, replacement);
    final nextSelection = selected.isEmpty
        ? TextSelection(
            baseOffset: start + before.length,
            extentOffset: start + before.length + placeholder.length,
          )
        : TextSelection.collapsed(offset: start + replacement.length);
    _body.value = value.copyWith(
      text: text,
      selection: nextSelection,
      composing: TextRange.empty,
    );
    _bodyFocus.requestFocus();
  }

  void _prefixSelectedLines(String prefix) {
    final value = _body.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final lineStart = selection.start == 0
        ? 0
        : value.text.lastIndexOf('\n', selection.start - 1) + 1;
    final nextBreak = value.text.indexOf('\n', selection.end);
    final lineEnd = nextBreak < 0 ? value.text.length : nextBreak;
    final selectedLines = value.text.substring(lineStart, lineEnd);
    final replacement = selectedLines
        .split('\n')
        .map((line) => line.startsWith(prefix) ? line : '$prefix$line')
        .join('\n');
    final addedBeforeCursor = selectedLines.startsWith(prefix)
        ? 0
        : prefix.length;
    _body.value = value.copyWith(
      text: value.text.replaceRange(lineStart, lineEnd, replacement),
      selection: selection.isCollapsed
          ? TextSelection.collapsed(
              offset: selection.extentOffset + addedBeforeCursor,
            )
          : TextSelection(
              baseOffset: lineStart,
              extentOffset: lineStart + replacement.length,
            ),
      composing: TextRange.empty,
    );
    _bodyFocus.requestFocus();
  }

  Future<void> _save() async {
    if (_isEdit && _original == null) return;
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
          _original!.copyWith(
            title: title,
            body: body.isEmpty ? null : body,
            textFormat: _hasLegacyHtml
                ? _original!.textFormat
                : localPrayerTextFormat,
            tags: tags,
          ),
        );
      } else {
        await notifier.create(
          title: title,
          body: body.isEmpty ? null : body,
          tags: tags,
          textFormat: localPrayerTextFormat,
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
        context.go('/prayers/my');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top;

    if (_isEdit && _original == null) {
      return Scaffold(
        appBar: AdaptiveAppBar.text('Мае малітвы'),
        body: const Center(child: Text('Асабістая малітва не знойдзена')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar(
        title: Text(_isEdit ? 'Рэдагаваць малітву' : 'Новая малітва'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Выдаліць малітву',
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const PhosphorIcon(PhosphorIconsRegular.trash, size: 20),
              onPressed: _deleting ? null : _delete,
            ),
          IconButton(
            tooltip: 'Захаваць',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const PhosphorIcon(PhosphorIconsRegular.floppyDisk, size: 22),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: AmbientWash(
        seasonColor: GlassTokens.of(context).ambientBase,
        height: 220,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              topPad + kFloatingAppBarContentInset,
              12,
              // Leave the save button above the floating app navigation dock,
              // with a small gap once the form is scrolled to its end.
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              GlassSurface(
                style: GlassStyle.card,
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Увядзіце назву малітвы'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Тэкст малітвы',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('prayer-markdown-preview-toggle'),
                          onPressed: () =>
                              setState(() => _showPreview = !_showPreview),
                          icon: Icon(
                            _showPreview
                                ? Icons.edit_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                          ),
                          label: Text(_showPreview ? 'Рэдактар' : 'Прагляд'),
                        ),
                      ],
                    ),
                    Text(
                      _hasLegacyHtml
                          ? 'Запіс захаваны ў старым фармаце HTML.'
                          : 'Можна вылучаць тэкст, дадаваць загалоўкі і спісы.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!_showPreview && !_hasLegacyHtml) ...[
                      _MarkdownToolbar(
                        onHeading: () => _prefixSelectedLines('## '),
                        onBold: () => _wrapSelection('**', '**', 'важны тэкст'),
                        onItalic: () => _wrapSelection('*', '*', 'акцэнт'),
                        onList: () => _prefixSelectedLines('- '),
                      ),
                      const SizedBox(height: 10),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _showPreview
                          ? _PrayerMarkdownPreview(
                              key: const Key('prayer-markdown-preview'),
                              source: _body.text,
                              legacyHtml: _hasLegacyHtml,
                            )
                          : TextFormField(
                              key: const Key('prayer-body-field'),
                              controller: _body,
                              focusNode: _bodyFocus,
                              decoration: const InputDecoration(
                                hintText: 'Напішыце тэкст малітвы…',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 14,
                              minLines: 8,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tags,
                      decoration: InputDecoration(
                        labelText: 'Тэгі',
                        hintText: 'ранішняя, вечар, пакаяне',
                        border: const OutlineInputBorder(),
                        helperText: 'Праз коску',
                        helperStyle: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const PhosphorIcon(
                              PhosphorIconsRegular.floppyDisk,
                              size: 20,
                            ),
                      label: Text(
                        _isEdit ? 'Захаваць змены' : 'Дадаць малітву',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.onHeading,
    required this.onBold,
    required this.onItalic,
    required this.onList,
  });

  final VoidCallback onHeading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Row(
          children: [
            _FormatButton(
              key: const Key('prayer-format-heading'),
              tooltip: 'Загаловак',
              icon: Icons.title_rounded,
              onPressed: onHeading,
            ),
            _FormatButton(
              key: const Key('prayer-format-bold'),
              tooltip: 'Тлусты тэкст',
              icon: Icons.format_bold_rounded,
              onPressed: onBold,
            ),
            _FormatButton(
              key: const Key('prayer-format-italic'),
              tooltip: 'Курсіў',
              icon: Icons.format_italic_rounded,
              onPressed: onItalic,
            ),
            _FormatButton(
              key: const Key('prayer-format-list'),
              tooltip: 'Спіс',
              icon: Icons.format_list_bulleted_rounded,
              onPressed: onList,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon, size: 21),
  );
}

class _PrayerMarkdownPreview extends StatelessWidget {
  const _PrayerMarkdownPreview({
    super.key,
    required this.source,
    required this.legacyHtml,
  });

  final String source;
  final bool legacyHtml;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (source.trim().isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 210),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          'Тут з’явіцца прагляд малітвы',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Html(
        data: legacyHtml ? source : prayerMarkdownToHtml(source),
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: cs.onSurface,
            lineHeight: LineHeight(1.55),
          ),
          'p': Style(margin: Margins.only(bottom: 8)),
          'h2': Style(
            margin: Margins.only(top: 12, bottom: 6),
            fontSize: FontSize(20),
            fontWeight: FontWeight.w700,
          ),
        },
      ),
    );
  }
}
