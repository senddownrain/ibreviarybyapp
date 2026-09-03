/// Dynamic feast dates for a liturgical year (feast code → date).
typedef DynamicDates = Map<String, DateTime>;

class YearOptions {
  final int year;
  final Map<String, dynamic> data;

  const YearOptions({required this.year, required this.data});

  factory YearOptions.fromMap(Map<String, dynamic> data) {
    final rawYear = data['year'];
    return YearOptions(
      year: rawYear is num
          ? rawYear.toInt()
          : int.tryParse(rawYear?.toString() ?? '') ?? 0,
      data: data,
    );
  }

  Map<String, dynamic> toMap() => {'year': year, ...data};
}
