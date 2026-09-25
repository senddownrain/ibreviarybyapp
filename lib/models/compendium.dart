/// Immutable models for «Кампендый Катэхізіса Каталіцкага Касцёла».
///
/// The Compendium is its own read-only content domain: it is not a prayer
/// and never uses prayer collections, categories or filters. Field names
/// match the canonical MyBrev export (`docs/compendium.md`, schema v1).
library;

List<String> _strings(Object? value) => value is List
    ? [for (final item in value) item.toString()]
    : const <String>[];

int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

String _string(Object? value) => value is String ? value : '';

String? _stringOrNull(Object? value) => value is String ? value : null;

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ]
    : const <Map<String, dynamic>>[];

/// A quotation box printed before a group or after an answer.
class CompendiumCitation {
  const CompendiumCitation({required this.text, this.cccRefs = const []});

  factory CompendiumCitation.fromJson(Map<String, dynamic> json) =>
      CompendiumCitation(
        text: _string(json['text']),
        cccRefs: _strings(json['cccRefs']),
      );

  final String text;
  final List<String> cccRefs;
}

enum CompendiumEmphasisStyle { italic, bold }

/// Styled range inside an answer (`start`/`end` are UTF-16 offsets, the same
/// unit JavaScript uses, so offsets from the export apply unchanged).
class CompendiumEmphasis {
  const CompendiumEmphasis({
    required this.start,
    required this.end,
    required this.style,
  });

  factory CompendiumEmphasis.fromJson(Map<String, dynamic> json) =>
      CompendiumEmphasis(
        start: _int(json['start']),
        end: _int(json['end']),
        style: json['style'] == 'bold'
            ? CompendiumEmphasisStyle.bold
            : CompendiumEmphasisStyle.italic,
      );

  final int start;
  final int end;
  final CompendiumEmphasisStyle style;
}

/// One numbered question with its answer and the context of its unit.
class CompendiumQuestion {
  const CompendiumQuestion({
    required this.id,
    required this.number,
    required this.order,
    required this.question,
    required this.answer,
    required this.unitId,
    required this.partId,
    required this.partNumber,
    required this.partLabel,
    required this.partTitle,
    required this.sectionTitle,
    this.cccRefs = const [],
    this.topicId,
    this.topicTitle,
    this.subtopicTitle,
    this.chapterTitle,
    this.answerEmphasis = const [],
    this.citations = const [],
  });

  factory CompendiumQuestion.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> unit,
  ) => CompendiumQuestion(
    id: _string(json['id']),
    number: _int(json['number']),
    order: _int(json['order']),
    question: _string(json['question']),
    answer: _string(json['answer']),
    cccRefs: _strings(json['cccRefs']),
    topicId: _stringOrNull(json['topicId']),
    topicTitle: _stringOrNull(json['topicTitle']),
    subtopicTitle: _stringOrNull(json['subtopicTitle']),
    answerEmphasis: [
      for (final range in _maps(json['answerEmphasis']))
        CompendiumEmphasis.fromJson(range),
    ],
    citations: [
      for (final citation in _maps(json['citations']))
        CompendiumCitation.fromJson(citation),
    ],
    unitId: _string(unit['id']),
    partId: _string(unit['partId']),
    partNumber: _int(unit['partNumber']),
    partLabel: _string(unit['partLabel']),
    partTitle: _string(unit['partTitle']),
    sectionTitle: _string(unit['sectionTitle']),
    chapterTitle: _stringOrNull(unit['chapterTitle']),
  );

  final String id;
  final int number;
  final int order;
  final String question;

  /// `\n` is a line break and `\n\n` a paragraph break.
  final String answer;

  /// Paragraphs of the full Catechism: `"50-53"` is a range.
  final List<String> cccRefs;
  final String? topicId;
  final String? topicTitle;
  final String? subtopicTitle;
  final List<CompendiumEmphasis> answerEmphasis;
  final List<CompendiumCitation> citations;

  // Context copied from the owning unit (MyBrev `indexCompendium`).
  final String unitId;
  final String partId;
  final int partNumber;
  final String partLabel;
  final String partTitle;
  final String sectionTitle;
  final String? chapterTitle;

  /// Reading group: the topic, or the unit's untitled lead-in.
  String get groupId => topicId ?? unitId;
}

class CompendiumTopic {
  const CompendiumTopic({
    required this.id,
    required this.order,
    required this.title,
    required this.firstQuestion,
    required this.lastQuestion,
    this.parentTitle,
    this.leadCitations = const [],
  });

  factory CompendiumTopic.fromJson(Map<String, dynamic> json) =>
      CompendiumTopic(
        id: _string(json['id']),
        order: _int(json['order']),
        title: _string(json['title']),
        parentTitle: _stringOrNull(json['parentTitle']),
        firstQuestion: _int(json['firstQuestion']),
        lastQuestion: _int(json['lastQuestion']),
        leadCitations: [
          for (final citation in _maps(json['leadCitations']))
            CompendiumCitation.fromJson(citation),
        ],
      );

  final String id;
  final int order;
  final String title;
  final String? parentTitle;
  final int firstQuestion;
  final int lastQuestion;
  final List<CompendiumCitation> leadCitations;
}

/// A chapter-like document (`compendium/{unitId}` in Firestore).
class CompendiumUnit {
  const CompendiumUnit({
    required this.id,
    required this.order,
    required this.partId,
    required this.partNumber,
    required this.partLabel,
    required this.partTitle,
    required this.sectionNumber,
    required this.sectionLabel,
    required this.sectionTitle,
    required this.title,
    required this.firstQuestion,
    required this.lastQuestion,
    required this.topics,
    required this.questions,
    this.chapterNumber,
    this.chapterLabel,
    this.chapterTitle,
    this.leadCitations = const [],
  });

  factory CompendiumUnit.fromJson(Map<String, dynamic> json) => CompendiumUnit(
    id: _string(json['id']),
    order: _int(json['order']),
    partId: _string(json['partId']),
    partNumber: _int(json['partNumber']),
    partLabel: _string(json['partLabel']),
    partTitle: _string(json['partTitle']),
    sectionNumber: _int(json['sectionNumber']),
    sectionLabel: _string(json['sectionLabel']),
    sectionTitle: _string(json['sectionTitle']),
    chapterNumber: _intOrNull(json['chapterNumber']),
    chapterLabel: _stringOrNull(json['chapterLabel']),
    chapterTitle: _stringOrNull(json['chapterTitle']),
    title: _string(json['title']),
    firstQuestion: _int(json['firstQuestion']),
    lastQuestion: _int(json['lastQuestion']),
    leadCitations: [
      for (final citation in _maps(json['leadCitations']))
        CompendiumCitation.fromJson(citation),
    ],
    topics: [
      for (final topic in _maps(json['topics']))
        CompendiumTopic.fromJson(topic),
    ],
    questions: [
      for (final question in _maps(json['questions']))
        CompendiumQuestion.fromJson(question, json),
    ],
  );

  final String id;
  final int order;
  final String partId;
  final int partNumber;
  final String partLabel;
  final String partTitle;
  final int sectionNumber;
  final String sectionLabel;
  final String sectionTitle;
  final int? chapterNumber;
  final String? chapterLabel;
  final String? chapterTitle;
  final String title;
  final int firstQuestion;
  final int lastQuestion;
  final List<CompendiumCitation> leadCitations;
  final List<CompendiumTopic> topics;
  final List<CompendiumQuestion> questions;
}

class CompendiumChapterInfo {
  const CompendiumChapterInfo({
    required this.id,
    required this.number,
    required this.label,
    required this.title,
  });

  factory CompendiumChapterInfo.fromJson(Map<String, dynamic> json) =>
      CompendiumChapterInfo(
        id: _string(json['id']),
        number: _int(json['number']),
        label: _string(json['label']),
        title: _string(json['title']),
      );

  final String id;
  final int number;
  final String label;
  final String title;
}

class CompendiumSectionInfo {
  const CompendiumSectionInfo({
    required this.id,
    required this.number,
    required this.label,
    required this.title,
    this.chapters = const [],
  });

  factory CompendiumSectionInfo.fromJson(Map<String, dynamic> json) =>
      CompendiumSectionInfo(
        id: _string(json['id']),
        number: _int(json['number']),
        label: _string(json['label']),
        title: _string(json['title']),
        chapters: [
          for (final chapter in _maps(json['chapters']))
            CompendiumChapterInfo.fromJson(chapter),
        ],
      );

  final String id;
  final int number;
  final String label;
  final String title;
  final List<CompendiumChapterInfo> chapters;
}

class CompendiumPart {
  const CompendiumPart({
    required this.id,
    required this.number,
    required this.label,
    required this.title,
    this.sourceUrl,
    this.sections = const [],
  });

  factory CompendiumPart.fromJson(Map<String, dynamic> json) => CompendiumPart(
    id: _string(json['id']),
    number: _int(json['number']),
    label: _string(json['label']),
    title: _string(json['title']),
    sourceUrl: _stringOrNull(json['sourceUrl']),
    sections: [
      for (final section in _maps(json['sections']))
        CompendiumSectionInfo.fromJson(section),
    ],
  );

  final String id;
  final int number;
  final String label;
  final String title;
  final String? sourceUrl;
  final List<CompendiumSectionInfo> sections;
}

class CompendiumMeta {
  const CompendiumMeta({
    required this.id,
    required this.title,
    required this.language,
    required this.schemaVersion,
    required this.contentVersion,
    required this.questionCount,
    required this.unitCount,
    required this.unitIds,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.sourceHost,
    required this.checksum,
    this.sourcePages = const [],
    this.copyright = const [],
    this.updatedAt,
  });

  factory CompendiumMeta.fromJson(Map<String, dynamic> json) => CompendiumMeta(
    id: _string(json['id']),
    title: _string(json['title']),
    language: _string(json['language']),
    schemaVersion: _int(json['schemaVersion']),
    contentVersion: _int(json['contentVersion']),
    questionCount: _int(json['questionCount']),
    unitCount: _int(json['unitCount']),
    unitIds: _strings(json['unitIds']),
    sourceTitle: _string(json['sourceTitle']),
    sourceUrl: _string(json['sourceUrl']),
    sourceHost: _string(json['sourceHost']),
    sourcePages: _strings(json['sourcePages']),
    copyright: _strings(json['copyright']),
    checksum: _string(json['checksum']),
    updatedAt: _stringOrNull(json['updatedAt']),
  );

  final String id;
  final String title;
  final String language;
  final int schemaVersion;
  final int contentVersion;
  final int questionCount;
  final int unitCount;
  final List<String> unitIds;
  final String sourceTitle;
  final String sourceUrl;
  final String sourceHost;
  final List<String> sourcePages;
  final List<String> copyright;
  final String checksum;
  final String? updatedAt;
}

/// A complete, validated dataset (`{meta, parts, units}`).
class CompendiumDataset {
  const CompendiumDataset({
    required this.meta,
    required this.parts,
    required this.units,
  });

  /// Parses an already validated canonical map
  /// (see `validateCompendiumDataset`).
  factory CompendiumDataset.fromJson(
    Map<String, dynamic> json,
  ) => CompendiumDataset(
    meta: CompendiumMeta.fromJson(
      Map<String, dynamic>.from(json['meta'] as Map),
    ),
    parts: [
      for (final part in _maps(json['parts'])) CompendiumPart.fromJson(part),
    ],
    units: [
      for (final unit in _maps(json['units'])) CompendiumUnit.fromJson(unit),
    ],
  );

  final CompendiumMeta meta;
  final List<CompendiumPart> parts;
  final List<CompendiumUnit> units;
}
