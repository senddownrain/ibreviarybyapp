class Reading {
  final String id;
  final String? periodType;
  final int? periodWeekNumber;
  final int? dayOfWeek;
  final String? feast;
  final String? date;
  final String? cycle;
  final Map<String, dynamic> data;

  const Reading({
    required this.id,
    this.periodType,
    this.periodWeekNumber,
    this.dayOfWeek,
    this.feast,
    this.date,
    this.cycle,
    this.data = const {},
  });

  String? get title => data['title'] as String?;
  String get text => (data['text'] as String? ?? data['body'] as String?) ?? '';

  factory Reading.fromMap(Map<String, dynamic> data) {
    return Reading(
      id: data['id'] as String? ?? data['_id'] as String? ?? '',
      periodType: data['_periodType'] as String?,
      periodWeekNumber: data['_periodWeekNumber'] as int?,
      dayOfWeek: data['_dayOfWeek'] as int?,
      feast: data['_feast'] as String?,
      date: data['_date'] as String?,
      cycle: data['cycle'] as String?,
      data: data,
    );
  }
}
