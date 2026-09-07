class Prayer {
  final String id;
  final String title;
  final String? titleBe;
  final String? body;
  final String? textFormat;
  final List<String> tags;
  final bool isLocal;

  const Prayer({
    required this.id,
    required this.title,
    this.titleBe,
    this.body,
    this.textFormat,
    this.tags = const [],
    this.isLocal = false,
  });

  String get displayTitle {
    if (titleBe != null && titleBe!.trim().isNotEmpty) return titleBe!;
    if (title.trim().isNotEmpty) return title;
    return '';
  }

  /// Canonical prayer source: Markdown or legacy HTML (web parity).
  String get displayText => body ?? '';

  bool get isMarkdown =>
      textFormat == 'mybrev-markdown' ||
      (displayText.isNotEmpty &&
          !displayText.contains('<') &&
          (displayText.contains('**') ||
              displayText.contains(':::rubric') ||
              RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(displayText)));

  factory Prayer.fromMap(Map<String, dynamic> data, String id) {
    return Prayer(
      id: id,
      title: _resolveTitle(data),
      titleBe: _asString(data['titleBe']),
      body: _resolveBody(data),
      textFormat: _asString(data['textFormat']),
      tags: _resolveTags(data['tags']),
      isLocal: data['isLocal'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    if (titleBe != null) 'titleBe': titleBe,
    // Persist under Firestore-canonical `text` so re-sync/round-trip matches web.
    if (body != null) 'text': body,
    if (textFormat != null) 'textFormat': textFormat,
    'tags': tags,
    'isLocal': isLocal,
  };

  Prayer copyWith({
    String? id,
    String? title,
    String? titleBe,
    String? body,
    String? textFormat,
    List<String>? tags,
    bool? isLocal,
  }) => Prayer(
    id: id ?? this.id,
    title: title ?? this.title,
    titleBe: titleBe ?? this.titleBe,
    body: body ?? this.body,
    textFormat: textFormat ?? this.textFormat,
    tags: tags ?? this.tags,
    isLocal: isLocal ?? this.isLocal,
  );

  static String _resolveTitle(Map<String, dynamic> data) {
    final title = _asString(data['title']);
    if (title != null && title.trim().isNotEmpty) return title;

    final versions = data['titleVersions'];
    if (versions is Map) {
      final be = _asString(versions['be']);
      if (be != null && be.trim().isNotEmpty) return be;
      final ru = _asString(versions['ru']);
      if (ru != null && ru.trim().isNotEmpty) return ru;
      for (final value in versions.values) {
        final s = _asString(value);
        if (s != null && s.trim().isNotEmpty) return s;
      }
    }
    return '';
  }

  /// Web stores content in `text` / `textVersions`; older mobile used `body`.
  static String? _resolveBody(Map<String, dynamic> data) {
    final text = _asString(data['text']);
    if (text != null && text.trim().isNotEmpty) return text;

    final body = _asString(data['body']);
    if (body != null && body.trim().isNotEmpty) return body;

    final versions = data['textVersions'];
    if (versions is Map) {
      final be = _asString(versions['be']);
      if (be != null && be.trim().isNotEmpty) return be;
      final ru = _asString(versions['ru']);
      if (ru != null && ru.trim().isNotEmpty) return ru;
      for (final value in versions.values) {
        final s = _asString(value);
        if (s != null && s.trim().isNotEmpty) return s;
      }
    }
    return null;
  }

  static List<String> _resolveTags(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }
}
