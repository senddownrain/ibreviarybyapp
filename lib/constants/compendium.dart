// Compendium of the Catechism of the Catholic Church: an independent,
// read-only content domain (not a prayer). Mirrors MyBrev
// `src/constants/compendium.js`; see docs/compendium.md.

const kCompendiumTitle = 'Кампендый Катэхізіса';
const kCompendiumFullTitle = 'Кампендый Катэхізіса Каталіцкага Касцёла';
const kCompendiumSourceUrl =
    'https://catholic.by/3/lib/documents/kasciol/3963-kampendyj-katekhizisa-katalitskaga-kastsjola';
const kCompendiumSourceHost = 'Catholic.by';

String compendiumLocation() => '/prayers/compendium';

String compendiumPartLocation(String partId, {String? target}) => Uri(
  pathSegments: ['', 'prayers', 'compendium', 'part', partId],
  queryParameters: target == null ? null : {'target': target},
).toString();

/// Legacy source-heading link; the route redirects into the owning Part.
String compendiumNodeLocation(String nodeId) =>
    Uri(pathSegments: ['', 'prayers', 'compendium', 'node', nodeId]).toString();

String compendiumTopicLocation(String topicId) => Uri(
  pathSegments: ['', 'prayers', 'compendium', 'topic', topicId],
).toString();

String compendiumQuestionLocation(int number) =>
    '/prayers/compendium/question/$number';
