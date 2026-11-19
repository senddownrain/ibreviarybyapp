class LiturgicalDay {
  final String id;
  final String? title;
  final String? feastName;
  final String? feastComment;
  final String? periodType;
  final int? periodWeekNumber;
  final int? dayOfWeek;
  final String? feast;
  final String? date;
  final String? rank;

  // Raw map for dynamic field access (liturgical hour content)
  final Map<String, dynamic> _raw;

  const LiturgicalDay({
    required this.id,
    this.title,
    this.feastName,
    this.feastComment,
    this.periodType,
    this.periodWeekNumber,
    this.dayOfWeek,
    this.feast,
    this.date,
    this.rank,
    Map<String, dynamic> raw = const {},
  }) : _raw = raw;

  /// Dynamic field access for liturgical hour content (e.g. 'laudesHymn').
  /// Firestore/Hive may store ints for week/day — never hard-cast to String.
  String? field(String name) {
    final value = _raw[name];
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return value.toString();
  }

  /// Complete normalized document used by the day resolver and hour renderer.
  Map<String, dynamic> get data => Map.unmodifiable(_raw);

  factory LiturgicalDay.fromMap(Map<String, dynamic> data) {
    return LiturgicalDay(
      id: data['id']?.toString() ?? data['_id']?.toString() ?? '',
      title: _asString(data['title']) ?? _asString(data['_title']),
      feastName: _asString(data['feastName']) ?? _asString(data['_feastName']),
      feastComment: _asFeastComment(
        data['feastComment'] ?? data['comment'],
      ),
      periodType: _asString(data['_periodType']),
      periodWeekNumber: _asInt(data['_periodWeekNumber']),
      dayOfWeek: _asInt(data['_dayOfWeek']),
      feast: _asString(data['_feast']),
      date: _asString(data['_date']),
      rank: _asString(data['rank']) ?? _asString(data['_rank']),
      raw: data,
    );
  }

  Map<String, dynamic> toMap() => {..._raw, 'id': id};

  /// A rank label repeated in the comment field is calendar metadata, not
  /// an authored note. Keep substantive comments (even one-word comments).
  static String? _asFeastComment(dynamic value) {
    final text = _asString(value)?.trim();
    if (text == null || text.isEmpty) return null;

    final plainText = text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(
          RegExp(r'&(?:nbsp|#160|#x0*a0);', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[.!]+
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
), '')
        .trim()
        .toLowerCase();

    const rankOnlyComments = {
      'урачыстасць',
      'ўрачыстасць',
      'solemnitas',
      'solemnity',
      'свята',
      'festum',
      'feast',
      'успамін',
      'memoria',
      'неабавязковы ўспамін',
      'memoria ad libitum',
    };
    return rankOnlyComments.contains(plainText) ? null : text;
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
