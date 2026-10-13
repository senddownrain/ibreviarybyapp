/// Readings of memorials (port of mybrev `src/utils/ordo/memorialReadings.js`):
/// ONE rule for the web and the app.
///
/// * default: the weekday readings (GIRM 357; OLM 83);
/// * proper-prescribed: the Lectionary assigns PROPER readings to the memorial
///   and they replace the weekday readings. The list is closed;
/// * the memorial's own readings and the Common stay legal alternatives.
library;

/// One memorial whose own readings the Lectionary prescribes.
class PrescribedMemorial {
  const PrescribedMemorial({
    required this.date,
    required this.parts,
    required this.rank,
    this.dioceses,
  });

  final String date;
  final List<String> parts;
  final String rank;

  /// The entry applies only in these dioceses (null: everywhere).
  final List<String>? dioceses;
}

const kPrescribedProperMemorials = <String, PrescribedMemorial>{
  'holy-name-of-jesus': PrescribedMemorial(
    date: '03.01',
    parts: ['reading1', 'gospel'],
    rank: 'optional-memorial',
  ),
  'sv-timothy-titus': PrescribedMemorial(
    date: '26.01',
    parts: ['reading1'],
    rank: 'memorial',
  ),
  'sv-joseph-worker': PrescribedMemorial(
    date: '01.05',
    parts: ['gospel'],
    rank: 'optional-memorial',
  ),
  'sv-barnabas': PrescribedMemorial(
    date: '11.06',
    parts: ['reading1'],
    rank: 'memorial',
  ),
  'sv-martha': PrescribedMemorial(
    date: '29.07',
    parts: ['gospel'],
    rank: 'memorial',
  ),
  'beheading-john-baptist': PrescribedMemorial(
    date: '29.08',
    parts: ['gospel'],
    rank: 'memorial',
  ),
  'our-lady-sorrows': PrescribedMemorial(
    date: '15.09',
    parts: ['gospel', 'sequence'],
    rank: 'memorial',
  ),
  'holy-guardian-angels': PrescribedMemorial(
    date: '02.10',
    parts: ['gospel'],
    rank: 'memorial',
  ),
  'dedication-basilicas-peter-paul': PrescribedMemorial(
    date: '18.11',
    parts: ['reading1', 'gospel'],
    rank: 'optional-memorial',
  ),
  'mary-mother-church': PrescribedMemorial(
    date: 'Monday after Pentecost',
    parts: ['reading1', 'gospel'],
    rank: 'memorial',
  ),
  // Pinsk diocesan calendar: 2 July is a memorial with the readings of vol. VI.
  'our-lady-budslav': PrescribedMemorial(
    date: '02.07',
    parts: ['reading1', 'reading2', 'gospel'],
    rank: 'memorial',
    dioceses: ['pinsk'],
  ),
  'immaculate-heart': PrescribedMemorial(
    date: 'Saturday after the 2nd Sunday after Pentecost',
    parts: ['gospel'],
    rank: 'optional-memorial',
  ),
};

const kMemorialKinds = ['memorial', 'optional-memorial'];

/// How the readings of a memorial option are chosen.
class MemorialReadingsRule {
  const MemorialReadingsRule(this.mode, this.defaultPurpose, this.parts);

  /// `proper-prescribed` or `weekday-default`.
  final String mode;

  /// `proper` or `weekday`.
  final String defaultPurpose;
  final List<String> parts;

  bool get prescribed => mode == 'proper-prescribed';
}

/// The rule of a memorial option; null for any other celebration.
MemorialReadingsRule? memorialReadingsRule(
  String optionId,
  String officeKind, [
  String diocese = '',
]) {
  if (!kMemorialKinds.contains(officeKind)) return null;
  final entry = kPrescribedProperMemorials[optionId];
  final prescribed =
      entry != null &&
      (entry.dioceses == null || entry.dioceses!.contains(diocese));
  return prescribed
      ? MemorialReadingsRule('proper-prescribed', 'proper', entry.parts)
      : const MemorialReadingsRule('weekday-default', 'weekday', []);
}
