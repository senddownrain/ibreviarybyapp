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

  /// Dynamic field access for liturgical hour content (e.g. 'laudesHymn', 'invitatorium').
  String? field(String name) => _raw[name] as String?;

  factory LiturgicalDay.fromMap(Map<String, dynamic> data) {
    return LiturgicalDay(
      id: data['id'] as String? ?? data['_id'] as String? ?? '',
      title: data['title'] as String?,
      feastName: data['feastName'] as String? ?? data['_feastName'] as String?,
      feastComment: data['feastComment'] as String?,
      periodType: data['_periodType'] as String?,
      periodWeekNumber: data['_periodWeekNumber'] as int?,
      dayOfWeek: data['_dayOfWeek'] as int?,
      feast: data['_feast'] as String?,
      date: data['_date'] as String?,
      rank: data['rank'] as String?,
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
}
