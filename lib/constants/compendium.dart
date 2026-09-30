// Compendium of the Catechism of the Catholic Church: an independent,
// read-only content domain (not a prayer). Mirrors MyBrev
// `src/constants/compendium.js`; see docs/compendium.md.

const kCompendiumTitle = 'Кампендый Катэхізіса';
const kCompendiumFullTitle = 'Кампендый Катэхізіса Каталіцкага Касцёла';
const kCompendiumSourceUrl =
    'https://catholic.by/3/lib/documents/kasciol/3963-kampendyj-katekhizisa-katalitskaga-kastsjola';
const kCompendiumSourceHost = 'Catholic.by';

String compendiumLocation() => '/prayers/compendium';

String compendiumPartLocation(String partId) =>
    Uri(pathSegments: ['', 'prayers', 'compendium', 'part', partId]).toString();

/// A section or subsection screen (`CompendiumNodeScreen`); [nodeId] is the
/// dataset id (`p1-s1`, `p1-s1-ch1`).
String compendiumNodeLocation(String nodeId) =>
    Uri(pathSegments: ['', 'prayers', 'compendium', 'node', nodeId]).toString();

String compendiumTopicLocation(String topicId) => Uri(
  pathSegments: ['', 'prayers', 'compendium', 'topic', topicId],
).toString();

String compendiumQuestionLocation(int number) =>
    '/prayers/compendium/question/$number';
