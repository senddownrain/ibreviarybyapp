/// Dynamic feast dates for a liturgical year (feast code → date).
typedef DynamicDates = Map<String, DateTime>;

class YearOptions {
  final int year;
  final Map<String, dynamic> data;

  const YearOptions({required this.year, required this.data});

  factory YearOptions.fromMap(Map<String, dynamic> data) {
    return YearOptions(
      year: data['year'] as int? ?? 0,
      data: data,
    );
  }

  Map<String, dynamic> toMap() => {'year': year, ...data};
}
