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

  factory LiturgicalDay.fromMap(Map<String, dynamic> data) {
    return LiturgicalDay(
      id: data['id']?.toString() ?? data['_id']?.toString() ?? '',
      title: _asString(data['title']),
      feastName: _asString(data['feastName']) ?? _asString(data['_feastName']),
      feastComment: _asString(data['feastComment']),
      periodType: _asString(data['_periodType']),
      periodWeekNumber: _asInt(data['_periodWeekNumber']),
      dayOfWeek: _asInt(data['_dayOfWeek']),
      feast: _asString(data['_feast']),
      date: _asString(data['_date']),
      rank: _asString(data['rank']) ?? _asString(data['_rank']),
      raw: data,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        if (title != null) 'title': title,
        if (feastName != null) 'feastName': feastName,
        if (feastComment != null) 'feastComment': feastComment,
        if (periodType != null) '_periodType': periodType,
        if (periodWeekNumber != null) '_periodWeekNumber': periodWeekNumber,
        if (dayOfWeek != null) '_dayOfWeek': dayOfWeek,
        if (feast != null) '_feast': feast,
        if (date != null) '_date': date,
        if (rank != null) 'rank': rank,
      };

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
