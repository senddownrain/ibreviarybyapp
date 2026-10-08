// Final-phase engine changes of the web Ordo (mybrev
// docs/ordo-final-phase-engine-changes.md), each pinned on the bundled
// calendar: memorial choices (§11.2–11.3), the All Souls Sunday Office/Mass
// split (§11.1), Christ the High Priest collisions (§11.4), transfers kept
// as Year Overrides (§12), books metadata (§13.1), `{source: 'proper'}`.
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/notes.dart';
import 'package:mybrev_flutter/ordo/year_plan.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';

import 'support/ordo_fixture.dart';

const _dioceses = ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk'];

/// An engine of the bundled calendar with changed / extra Year Overrides.
OrdoEngine _engineWith({
  Json Function(Json override)? edit,
  List<Json> extra = const [],
  bool ignoreTransferOverrides = false,
}) => OrdoEngine(
  OrdoDefinitions.fromDocuments(
    celebrations: bundledCollection('liturgicalCelebrations').values,
    dioceseOverrides: bundledCollection('liturgicalDioceseOverrides').values,
    yearOverrides: [
      for (final item in bundledCollection('liturgicalYearOverrides').values)
        edit == null ? item : edit(Json.of(item)),
      ...extra,
    ],
  ),
  ignoreTransferOverrides: ignoreTransferOverrides,
);

void main() {
  final engine = bundledOrdoEngine();

  group('memorial choices (§11.2–11.3)', () {
    test('13.06.2026: Immaculate Heart + St Anthony — two memorial choices, '
        'Marian first, no weekday, nothing demoted', () {
      for (final diocese in _dioceses) {
        final day = engine.resolve('2026-06-13', diocese: diocese);
        expect(day.primary.id, 'immaculate-heart', reason: diocese);
        expect(day.primary.rankKind, 'memorial');
        expect(day.alternatives.map((o) => o.id), ['sv-anthony-padua']);
        expect(day.alternatives.single.rankKind, 'memorial');
        expect(day.options.any((o) => o.demotedFrom != null), isFalse);
        expect(day.options.any((o) => o.isTemporal), isFalse);
        expect(
          day.suppressed.where((o) => o.isTemporal).map((o) => o.reason).single,
          'weekday-under-memorial',
        );
        expect(
          day.appliedRules.map((r) => r['rule']),
          containsAll([
            'concurrent-obligatory-memorials-legal-choice',
            'concurrent-obligatory-memorials-choice',
          ]),
        );
        expect(day.officeOptions.map((o) => o.id), [
          'immaculate-heart',
          'sv-anthony-padua',
        ]);
      }
    });

    test('the legacy value both-optional means legal-choice', () {
      final engine = OrdoEngine(
        OrdoDefinitions.fromDocuments(
          celebrations: [
            for (final item in bundledCollection(
              'liturgicalCelebrations',
            ).values)
              if (item['id'] == 'immaculate-heart')
                {
                  ...item,
                  'rules': {'concurrentObligatoryMemorials': 'both-optional'},
                }
              else
                item,
          ],
          dioceseOverrides: bundledCollection(
            'liturgicalDioceseOverrides',
          ).values,
          yearOverrides: bundledCollection('liturgicalYearOverrides').values,
        ),
      );
      final day = engine.resolve('2026-06-13');
      expect(day.primary.id, 'immaculate-heart');
      expect(day.alternatives.map((o) => o.id), ['sv-anthony-padua']);
    });
  });

  group('All Souls on a Sunday (§11.1)', () {
    test('2025-11-02: Mass of All Souls, Office of the Sunday', () {
      for (final diocese in _dioceses) {
        final day = engine.resolve('2025-11-02', diocese: diocese);
        expect(day.primary.id, 'all-faithful-departed');
        expect(day.color, 'violaceus');
        expect(day.isSplit, isTrue);
        final sources = day.sources;
        expect(sources.split, isTrue);
        expect(sources.mass.optionId, 'all-faithful-departed');
        expect(sources.mass.celebrationId, 'all-faithful-departed');
        expect(sources.mass.officeKind, 'all-souls');
        expect(sources.office.optionId, 'temporal:ordinary-w31-d1');
        expect(sources.office.celebrationId, isNull);
        expect(sources.office.officeKind, 'sunday');
        expect(day.officePrimary.officeOnly, isTrue);
        // The Sunday is the Office source, not a suppressed candidate.
        expect(day.suppressed.any((o) => o.isTemporal), isFalse);
        expect(day.options.map((o) => o.id), ['all-faithful-departed']);
        expect(day.officeOptions.map((o) => o.id), [
          'temporal:ordinary-w31-d1',
        ]);
        // Office descriptors exist only for the legal Office.
        expect(day.office('all-faithful-departed'), isNull);
        final office = day.office('temporal:ordinary-w31-d1')!;
        expect(office.teDeum, isTrue);
        expect(office.notes.single, contains('з нядзелі'));
        // Evening of the Sunday: II Vespers.
        expect(day.evening.vespersType, 'second');
        expect(day.evening.celebrationId, isNull);
        // Three Masses = three reading sets of the one celebration.
        expect(day.massVariants.map((v) => v.id), [
          'all-souls-mass-1',
          'all-souls-mass-2',
          'all-souls-mass-3',
        ]);
        expect(
          day.appliedRules.map((r) => r['rule']),
          contains('all-souls-sunday-split'),
        );
      }
    });

    test('on a weekday All Souls is both Office and Mass', () {
      final day = engine.resolve('2026-11-02');
      expect(day.isSplit, isFalse);
      expect(day.sources.office.optionId, 'all-faithful-departed');
      expect(day.sources.mass.optionId, 'all-faithful-departed');
      expect(day.officeOptions.map((o) => o.id), ['all-faithful-departed']);
      expect(day.massVariants, hasLength(3));
      expect(engine.resolve('2026-11-03').massVariants, isEmpty);
    });

    test('the Saturday before begins the Sunday with its I Vespers', () {
      final saturday = engine.resolve('2025-11-01');
      expect(saturday.primary.id, 'all-saints');
      // All Saints (solemnity) keeps its II Vespers against the Sunday.
      expect(saturday.evening.vespersType, 'second');
      expect(engine.resolve('2025-11-02').firstVespersCelebratedOnEve, isFalse);
    });
  });

  test('Christ the High Priest + another feast: both options, the '
      'alternative provisional (§11.4)', () {
    final engine = _engineWith(
      extra: [
        {
          'id': 'test-feast-2026',
          'year': 2026,
          'scope': 'belarus',
          'action': 'add',
          'to': '2026-05-28',
          'celebration': {
            'id': 'test-feast',
            'title': 'Тэставае свята',
            'rank': 'festum',
            'category': 'saint',
            'color': 'ruber',
          },
        },
      ],
    );
    final day = engine.resolve('2026-05-28');
    expect(day.primary.id, 'christ-the-high-priest');
    expect(day.primary.provisional, isFalse);
    expect(day.alternatives.map((o) => o.id), ['test-feast']);
    expect(day.alternatives.single.provisional, isTrue);
    expect(
      day.appliedRules.firstWhere(
        (r) => r['rule'] == 'christ-high-priest-collision-both-options',
      )['status'],
      'provisional',
    );
    expect(day.suppressed.any((o) => o.id == 'test-feast'), isFalse);
  });

  group('transfers and Year Overrides (§12)', () {
    test('legacy from/to and free-text source are normalized', () {
      final normalized = normalizeYearOverride({
        'year': 2026,
        'scope': 'diocese',
        'dioceseId': 'minsk-mohilev',
        'targetCelebrationId': 'sv-stanislaus-bishop-martyr',
        'action': 'move',
        'from': '2026-04-11',
        'to': '2026-04-16',
        'source': 'Annual calendar 2026',
      });
      expect(normalized['originalDate'], '2026-04-11');
      expect(normalized['effectiveDate'], '2026-04-16');
      expect(normalized['from'], '2026-04-11');
      expect(normalized['to'], '2026-04-16');
      expect(normalized['source'], 'manual');
      expect(normalized['sourceNote'], 'Annual calendar 2026');
      expect(normalized['status'], 'confirmed');
      expect(isTransferOverride(normalized), isFalse);
      expect(validateYearOverride(normalized), isEmpty);

      final auto = normalizeYearOverride({
        'year': 2027,
        'scope': 'belarus',
        'targetCelebrationId': 'annunciation-lord',
        'action': 'move',
        'originalDate': '2027-03-25',
        'computedDate': '2027-04-05',
        'effectiveDate': '2027-04-05',
        'source': 'auto-transfer',
      });
      expect(auto['status'], 'needs-review');
      expect(auto['from'], '2027-03-25');
      expect(auto['to'], '2027-04-05');
      expect(isTransferOverride(auto), isTrue);
      expect(
        validateYearOverride({...auto, 'action': 'suppress'}),
        contains('auto-transfer overrides must be moves'),
      );
    });

    test('a stored auto transfer keeps computedDate = effectiveDate', () {
      final day = engine.resolve('2027-04-05');
      expect(day.primary.id, 'annunciation-lord');
      expect(day.primary.transferredFrom, '2027-03-25');
      expect(day.primary.transferOverride, {
        'id': 'auto-transfer-2027-belarus-annunciation-lord',
        'source': 'auto-transfer',
        'status': 'needs-review',
        'computedDate': '2027-04-05',
      });
      final transfer = day.transfers.single;
      expect(transfer.toJson(), {
        'celebrationId': 'annunciation-lord',
        'from': '2027-03-25',
        'to': '2027-04-05',
        'rule': 'annunciation-after-easter-octave',
        'computedDate': '2027-04-05',
      });
      expect(transfer.override?['source'], 'auto-transfer');
      // Never applied as a plain move.
      expect(day.primary.movedFrom, isNull);
      // The pure algorithm gives the same date, without provenance.
      final pure = _engineWith(ignoreTransferOverrides: true);
      final algorithm = pure.resolve('2027-04-05').transfers.single;
      expect(algorithm.to, '2027-04-05');
      expect(algorithm.computedDate, '2027-04-05');
      expect(algorithm.override, isNull);
    });

    test(
      'a manual correction moves the effective date, keeps computedDate',
      () {
        final manual = _engineWith(
          edit: (item) =>
              item['id'] == 'auto-transfer-2027-belarus-annunciation-lord'
              ? {
                  ...item,
                  'effectiveDate': '2027-04-06',
                  'to': '2027-04-06',
                  'source': 'manual',
                  'status': 'confirmed',
                }
              : item,
        );
        expect(
          manual.resolve('2027-04-05').primary.id,
          isNot('annunciation-lord'),
        );
        final day = manual.resolve('2027-04-06');
        expect(day.primary.id, 'annunciation-lord');
        final transfer = day.transfers.single;
        expect(transfer.from, '2027-03-25');
        expect(transfer.to, '2027-04-06');
        expect(transfer.computedDate, '2027-04-05');
        expect(transfer.override, {
          'id': 'auto-transfer-2027-belarus-annunciation-lord',
          'source': 'manual',
          'status': 'confirmed',
        });
        expect(day.primary.transferOverride?['computedDate'], '2027-04-05');
      },
    );

    test('effectiveDate = originalDate: impeded without transfer', () {
      final kept = _engineWith(
        edit: (item) =>
            item['id'] == 'auto-transfer-2027-belarus-annunciation-lord'
            ? {...item, 'effectiveDate': '2027-03-25', 'to': '2027-03-25'}
            : item,
      );
      final day = kept.resolve('2027-03-25');
      expect(day.transfers, isEmpty);
      final annunciation = day.suppressed.firstWhere(
        (o) => o.id == 'annunciation-lord',
      );
      expect(annunciation.reason, 'impeded-without-transfer');
      expect(kept.resolve('2027-04-05').primary.id, isNot('annunciation-lord'));
    });

    test('unused transfer overrides: confirmed → move, pending → stale', () {
      final extra = <Json>[
        // The algorithm never transfers a memorial: a confirmed transfer
        // record is still the administrator's decision (a plain move).
        {
          'id': 'manual-transfer-anthony',
          'year': 2026,
          'scope': 'belarus',
          'targetCelebrationId': 'sv-anthony-padua',
          'action': 'move',
          'originalDate': '2026-06-13',
          'computedDate': '2026-06-15',
          'effectiveDate': '2026-06-15',
          'source': 'manual',
          'status': 'confirmed',
        },
        {
          'id': 'stale-auto',
          'year': 2026,
          'scope': 'belarus',
          'targetCelebrationId': 'sv-joseph',
          'action': 'move',
          'originalDate': '2026-03-19',
          'computedDate': '2026-03-20',
          'effectiveDate': '2026-03-20',
          'source': 'auto-transfer',
          'status': 'needs-review',
        },
      ];
      final engine = _engineWith(extra: extra);
      final plan = engine.plan(2026, 'minsk-mohilev');
      expect(plan.staleTransferOverrides.map((o) => o['id']), ['stale-auto']);
      expect(
        plan.appliedOverrides.map((o) => o['id']),
        contains('manual-transfer-anthony'),
      );
      final moved = engine.resolve('2026-06-15');
      expect(moved.primary.id, 'sv-anthony-padua');
      expect(moved.primary.movedFrom, '2026-06-13');
      expect(engine.resolve('2026-06-13').alternatives, isEmpty);
      // The stale auto record is never applied: St Joseph stays on 19.03.
      expect(engine.resolve('2026-03-19').primary.id, 'sv-joseph');
    });

    test('a diocesan solemnity is transferred only with rank evidence', () {
      expect(
        unconfirmedDiocesanSolemnity({
          'id': 'sv-andrei-bobola',
          'layer': 'diocese',
          'dioceseId': 'pinsk',
        }),
        isFalse,
      );
      expect(
        unconfirmedDiocesanSolemnity({
          'id': 'sv-dismas',
          'layer': 'diocese',
          'dioceseId': 'pinsk',
        }),
        isTrue,
      );
      expect(
        unconfirmedDiocesanSolemnity({'id': 'x', 'layer': 'belarus'}),
        isFalse,
      );
      // St Dismas raised to a solemnity on Good Friday 2027 (Pinsk): no
      // calendar confirms the rank, so it is impeded without transfer.
      final engine = _engineWith(
        extra: [
          {
            'id': 'test-dismas-rank',
            'year': 2027,
            'scope': 'diocese',
            'dioceseId': 'pinsk',
            'targetCelebrationId': 'sv-dismas',
            'action': 'changeRank',
            'rank': 'solemnitas',
          },
        ],
      );
      final day = engine.resolve('2027-03-26', diocese: 'pinsk');
      final dismas = day.suppressed.firstWhere((o) => o.id == 'sv-dismas');
      expect(dismas.reason, 'impeded-without-transfer');
      expect(dismas.transferBlocked, 'rank-not-source-confirmed');
      expect(
        engine.plan(2027, 'pinsk').transfers.map((t) => t.celebrationId),
        isNot(contains('sv-dismas')),
      );
      // Bobola (confirmed) is transferred in 2027 (16.05 = Pentecost).
      final bobola = engine
          .plan(2027, 'pinsk')
          .transfers
          .firstWhere((t) => t.celebrationId == 'sv-andrei-bobola');
      expect(bobola.to, '2027-05-18');
      expect(bobola.computedDate, '2027-05-18');
    });
  });

  group('books (§13.1)', () {
    test('volumes are day metadata, not notes', () {
      final day = engine.resolve('2025-11-02');
      final books = engine.booksOf(day)!;
      expect(books.lectionaryVolume, 'III');
      expect(books.hoursVolume, 'III');
      expect(books.label, 'Лекцыянарый т. III · Літургія гадзін т. III');
      expect(books.noteIds, isNotEmpty);
      final notes = engine.notesOf(day);
      expect(notes.any(isBooksNote), isFalse);
      expect(notes.map((n) => n['id']), isNot(anyElement(isIn(books.noteIds))));
    });

    test('the most specific selector wins per field', () {
      Json note(String id, String type, Map<String, String> books) => {
        'id': id,
        'category': 'books',
        'selector': {'type': type},
        'books': books,
      };
      final books = booksFromNotes([
        note('n1', 'period', {'lectionaryVolume': 'II', 'hoursVolume': 'II'}),
        note('n2', 'celebration', {'lectionaryVolume': 'VI'}),
        note('n3', 'period-phase', {'hoursVolume': 'III'}),
        {'id': 'n4', 'category': 'mass', 'text': 'not a volume'},
      ])!;
      expect(books.lectionaryVolume, 'VI');
      expect(books.hoursVolume, 'III');
      expect(books.noteIds, ['n2', 'n3']);
      expect(booksFromNotes([]), isNull);
    });
  });

  group("field rule {source: 'proper'}", () {
    final templates = {
      'apostles': <String, dynamic>{
        'laudesHymn': '',
        'vesperHymn': 'Common vespers hymn',
        '_fieldRules': {
          'laudesHymn': {'source': 'proper'},
        },
      },
    };
    const currentDay = {'laudesHymn': 'Weekday hymn', 'vesperHymn': 'W'};
    Map<String, dynamic> proper([Map<String, dynamic> own = const {}]) => {
      '_schema': 2,
      '_rank': 'festum',
      '_templates': ['apostles'],
      '_defaultTemplate': 'apostles',
      ...own,
    };

    test("the celebration's own text fills the field", () {
      final assembly = assembleOffice(
        proper: proper({'laudesHymn': 'Own hymn'}),
        currentDay: currentDay,
        templates: templates,
        isSunday: false,
      );
      expect(assembly.data['laudesHymn'], 'Own hymn');
      expect(assembly.integrity, isEmpty);
    });

    test('a Common deferring to a missing Proper text: empty + integrity '
        'error, never the weekday', () {
      final assembly = assembleOffice(
        proper: proper(),
        currentDay: currentDay,
        templates: templates,
        isSunday: false,
      );
      expect(assembly.data['laudesHymn'], '');
      expect(assembly.data['laudesHymn'], isNot(currentDay['laudesHymn']));
      expect(assembly.missing, contains('laudesHymn'));
      expect(assembly.integrity.map((e) => e.toJson()), [
        {
          'field': 'laudesHymn',
          'source': 'proper',
          'reason': 'proper-text-missing',
        },
      ]);
      expect(
        (assembly.data['_integrityErrors'] as List).single['reason'],
        'proper-text-missing',
      );
    });

    test('the assembler supports every kind the fixture relies on', () {
      expect(kFieldRuleKinds.toSet(), containsAll(ordoParityFieldRuleKinds()));
    });
  });
}
