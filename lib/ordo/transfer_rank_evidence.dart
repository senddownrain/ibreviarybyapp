/// Diocesan solemnities whose TRANSFERABLE rank (solemnity) is confirmed by
/// a published annual calendar (port of mybrev
/// `src/data/ordo/transfer-rank-evidence.js`, final phase §12 case A).
///
/// A diocesan / patronal celebration is not assumed to be a solemnity
/// because it is a «patron»: the engine transfers an impeded diocesan
/// solemnity only when it is listed here. An unlisted one is impeded
/// without transfer (`transferBlocked: 'rank-not-source-confirmed'`); an
/// administrator can still move it with a manual Year Override.
library;

const Map<String, Map<String, List<String>>> kDiocesanSolemnityRankEvidence = {
  'minsk-mohilev': {
    'our-lady-budslav': ['minsk-mohilev:2026-07-02:c0'],
  },
  'vitebsk': {
    'sv-josaphat': ['vitebsk:2026-11-12:c0'],
  },
  'pinsk': {
    'sv-andrei-bobola': ['pinsk:2026-05-16:c0'],
    'our-lady-lahishyn': ['pinsk:2026-08-22:c0'],
  },
  'grodno': {
    'our-lady-mother-mercy': ['grodno:2027-11-16:c0'],
  },
};

/// Evidence ids that confirm the solemnity rank of a diocesan celebration,
/// or [].
List<String> rankEvidenceOf(String? dioceseId, String celebrationId) => [
  ...?kDiocesanSolemnityRankEvidence[dioceseId]?[celebrationId],
];
