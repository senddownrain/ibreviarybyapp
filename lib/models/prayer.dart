class Prayer {
  final String id;
  final String title;
  final String? titleBe;
  final String? body;
  final List<String> tags;
  final bool isLocal;

  const Prayer({
    required this.id,
    required this.title,
    this.titleBe,
    this.body,
    this.tags = const [],
    this.isLocal = false,
  });

  String get displayTitle => (titleBe?.isNotEmpty == true) ? titleBe! : title;
  String get displayText => body ?? '';

  factory Prayer.fromMap(Map<String, dynamic> data, String id) {
    return Prayer(
      id: id,
      title: data['title'] as String? ?? '',
      titleBe: data['titleBe'] as String?,
      body: data['body'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      isLocal: data['isLocal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (titleBe != null) 'titleBe': titleBe,
        if (body != null) 'body': body,
        'tags': tags,
        'isLocal': isLocal,
      };

  Prayer copyWith({
    String? id,
    String? title,
    String? titleBe,
    String? body,
    List<String>? tags,
    bool? isLocal,
  }) =>
      Prayer(
        id: id ?? this.id,
        title: title ?? this.title,
        titleBe: titleBe ?? this.titleBe,
        body: body ?? this.body,
        tags: tags ?? this.tags,
        isLocal: isLocal ?? this.isLocal,
      );
}
