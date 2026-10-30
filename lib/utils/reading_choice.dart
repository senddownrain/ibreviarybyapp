/// Which of the legal readings of an Office field the user picked (D-1).
///
/// Same contract as web `readingChoice.js`: one entry per field, `{context, index}`. The context names the
/// day, the diocese and the Office option the reader is showing, so a choice never leaks into another
/// day, period, diocese or Proper/Common assembly: asking with a different context gives the default and
/// the next write replaces the entry. The memory lives for the app session only (never in Hive).
String readingChoiceContext(String date, String optionId, [String? diocese]) =>
    '$date|$optionId|${diocese ?? ''}';

class ReadingChoiceStore {
  final Map<String, ({String context, int index})> _entries = {};

  int get(String field, String context, [int count = 1 << 30]) {
    final entry = _entries[field];
    if (entry == null || entry.context != context) return 0;
    return entry.index >= 0 && entry.index < count ? entry.index : 0;
  }

  void set(String field, String context, int index) {
    if (field.isEmpty || index < 0) return;
    if (index == 0) {
      _entries.remove(field);
    } else {
      _entries[field] = (context: context, index: index);
    }
  }

  void clear() => _entries.clear();

  /// The store of the running app.
  static final ReadingChoiceStore session = ReadingChoiceStore();
}

/// The place of one field in the store: what [AlternativeText] reads and writes for it.
class ReadingChoiceSlot {
  const ReadingChoiceSlot({
    required this.field,
    required this.context,
    ReadingChoiceStore? store,
  }) : _store = store;

  final String field;
  final String context;
  final ReadingChoiceStore? _store;

  ReadingChoiceStore get _target => _store ?? ReadingChoiceStore.session;

  int read(int count) => _target.get(field, context, count);

  void write(int index) => _target.set(field, context, index);

  @override
  bool operator ==(Object other) =>
      other is ReadingChoiceSlot &&
      other.field == field &&
      other.context == context &&
      other._store == _store;

  @override
  int get hashCode => Object.hash(field, context, _store);
}
