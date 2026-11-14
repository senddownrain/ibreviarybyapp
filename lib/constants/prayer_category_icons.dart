// ignore_for_file: prefer_interpolation_to_compose_strings
// The look-behind/ahead fragments are concatenated into the regexes on purpose.
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Prayer-category icon contract shared with the web app (`iconKey`).
///
/// Only the stable semantic key is stored (Hive, bundle content). The list of
/// 48 keys, labels and groups must equal `assets/category_icons/catalog.json`
/// (exported from the web repo); `test/category_icons_test.dart` checks that.
class CategoryIconGroup {
  const CategoryIconGroup(this.id, this.label);
  final String id;
  final String label;
}

class CategoryIconSpec {
  const CategoryIconSpec(this.key, this.label, this.group, {this.phosphor});
  final String key;
  final String label;
  final String group;

  /// Null for the 12 authored symbols, which are bundled SVG assets.
  final IconData? phosphor;

  String? get svgAsset =>
      phosphor == null ? 'assets/category_icons/$key.svg' : null;
}

const kCategoryIconGroups = <CategoryIconGroup>[
  CategoryIconGroup('prayer', 'Малітва і духоўнае жыццё'),
  CategoryIconGroup('church', 'Хрыстус, Касцёл і сакрамэнты'),
  CategoryIconGroup('daily', 'Штодзённае жыццё і набажэнствы'),
  CategoryIconGroup('symbols', 'Хрысціянскія сімвалы'),
];

const kCategoryIcons = <CategoryIconSpec>[
  CategoryIconSpec(
    'prayer',
    'Малітва',
    'prayer',
    phosphor: PhosphorIconsRegular.handsPraying,
  ),
  CategoryIconSpec(
    'adoration',
    'Адарацыя',
    'prayer',
    phosphor: PhosphorIconsRegular.sparkle,
  ),
  CategoryIconSpec(
    'praise',
    'Праслаўленне',
    'prayer',
    phosphor: PhosphorIconsRegular.musicNotes,
  ),
  CategoryIconSpec(
    'thanksgiving',
    'Падзяка',
    'prayer',
    phosphor: PhosphorIconsRegular.handHeart,
  ),
  CategoryIconSpec(
    'petitions',
    'Просьбы',
    'prayer',
    phosphor: PhosphorIconsRegular.chatCircleText,
  ),
  CategoryIconSpec(
    'trust',
    'Давер',
    'prayer',
    phosphor: PhosphorIconsRegular.heart,
  ),
  CategoryIconSpec(
    'meditation',
    'Разважанні',
    'prayer',
    phosphor: PhosphorIconsRegular.bookOpen,
  ),
  CategoryIconSpec(
    'novena',
    'Навэнны',
    'prayer',
    phosphor: PhosphorIconsRegular.calendarDots,
  ),
  CategoryIconSpec(
    'litany',
    'Літаніі',
    'prayer',
    phosphor: PhosphorIconsRegular.listDashes,
  ),
  CategoryIconSpec(
    'spiritual-reading',
    'Духоўнае чытанне',
    'prayer',
    phosphor: PhosphorIconsRegular.bookBookmark,
  ),
  CategoryIconSpec(
    'repentance',
    'Пакаянне',
    'prayer',
    phosphor: PhosphorIconsRegular.drop,
  ),
  CategoryIconSpec(
    'hope',
    'Надзея',
    'prayer',
    phosphor: PhosphorIconsRegular.anchor,
  ),
  CategoryIconSpec(
    'cross',
    'Крыж',
    'church',
    phosphor: PhosphorIconsRegular.cross,
  ),
  CategoryIconSpec(
    'church',
    'Касцёл',
    'church',
    phosphor: PhosphorIconsRegular.church,
  ),
  CategoryIconSpec(
    'gospel',
    'Евангелле',
    'church',
    phosphor: PhosphorIconsRegular.bookOpenText,
  ),
  CategoryIconSpec(
    'kingdom',
    'Валадарства',
    'church',
    phosphor: PhosphorIconsRegular.crown,
  ),
  CategoryIconSpec(
    'bread-of-life',
    'Хлеб жыцця',
    'church',
    phosphor: PhosphorIconsRegular.grains,
  ),
  CategoryIconSpec(
    'baptism',
    'Хрост',
    'church',
    phosphor: PhosphorIconsRegular.dropHalf,
  ),
  CategoryIconSpec(
    'scripture',
    'Святое Пісанне',
    'church',
    phosphor: PhosphorIconsRegular.scroll,
  ),
  CategoryIconSpec(
    'holy-spirit',
    'Святы Дух',
    'church',
    phosphor: PhosphorIconsRegular.flame,
  ),
  CategoryIconSpec(
    'faith',
    'Вера',
    'church',
    phosphor: PhosphorIconsRegular.shield,
  ),
  CategoryIconSpec(
    'apostles',
    'Апосталы',
    'church',
    phosphor: PhosphorIconsRegular.usersThree,
  ),
  CategoryIconSpec(
    'vocation',
    'Пакліканне',
    'church',
    phosphor: PhosphorIconsRegular.footprints,
  ),
  CategoryIconSpec(
    'bell',
    'Звон',
    'church',
    phosphor: PhosphorIconsRegular.bell,
  ),
  CategoryIconSpec(
    'morning',
    'Раніца',
    'daily',
    phosphor: PhosphorIconsRegular.sunHorizon,
  ),
  CategoryIconSpec(
    'evening',
    'Вечар',
    'daily',
    phosphor: PhosphorIconsRegular.moonStars,
  ),
  CategoryIconSpec(
    'family',
    'Сям\u2019я',
    'daily',
    phosphor: PhosphorIconsRegular.house,
  ),
  CategoryIconSpec(
    'children',
    'Дзеці',
    'daily',
    phosphor: PhosphorIconsRegular.baby,
  ),
  CategoryIconSpec(
    'saints',
    'Святыя',
    'daily',
    phosphor: PhosphorIconsRegular.star,
  ),
  CategoryIconSpec(
    'mary-flowers',
    'Кветкі Марыі',
    'daily',
    phosphor: PhosphorIconsRegular.flower,
  ),
  CategoryIconSpec(
    'gift',
    'Дар Божы',
    'daily',
    phosphor: PhosphorIconsRegular.gift,
  ),
  CategoryIconSpec(
    'peace',
    'Мір',
    'daily',
    phosphor: PhosphorIconsRegular.bird,
  ),
  CategoryIconSpec(
    'pilgrimage',
    'Паломніцтва',
    'daily',
    phosphor: PhosphorIconsRegular.path,
  ),
  CategoryIconSpec(
    'creation',
    'Стварэнне',
    'daily',
    phosphor: PhosphorIconsRegular.plant,
  ),
  CategoryIconSpec(
    'silence',
    'Цішыня',
    'daily',
    phosphor: PhosphorIconsRegular.mountains,
  ),
  CategoryIconSpec(
    'daily',
    'На кожны дзень',
    'daily',
    phosphor: PhosphorIconsRegular.sun,
  ),
  CategoryIconSpec('praying-hands', 'Складзеныя рукі', 'symbols'),
  CategoryIconSpec('rosary', 'Ружанец', 'symbols'),
  CategoryIconSpec('monstrance', 'Найсвяцейшы Сакрамэнт', 'symbols'),
  CategoryIconSpec('chalice-host', 'Келіх і Гостыя', 'symbols'),
  CategoryIconSpec('sacred-heart', 'Найсвяцейшае Сэрца Езуса', 'symbols'),
  CategoryIconSpec('immaculate-heart', 'Беззаганнае Сэрца Марыі', 'symbols'),
  CategoryIconSpec('virgin-mary', 'Маці Божая', 'symbols'),
  CategoryIconSpec('holy-spirit-dove', 'Дух Святы', 'symbols'),
  CategoryIconSpec('angel', 'Анёл', 'symbols'),
  CategoryIconSpec('saint-halo', 'Святы', 'symbols'),
  CategoryIconSpec('crucifix', 'Укрыжаванне', 'symbols'),
  CategoryIconSpec('candle', 'Свечка', 'symbols'),
];

const kDefaultCategoryIconKey = 'prayer';

/// Required values for the three built-in categories.
const kSeedCategoryIconKeys = <String, String>{
  'mary': 'virgin-mary',
  'litanies': 'litany',
  'novenas': 'novena',
};

final Map<String, CategoryIconSpec> _byKey = {
  for (final icon in kCategoryIcons) icon.key: icon,
};

CategoryIconSpec? categoryIconSpec(String? key) => _byKey[key];

bool isValidCategoryIconKey(Object? value) =>
    value is String && _byKey.containsKey(value);

/// Allowlist normaliser for values about to be stored: a valid key or null.
String? normalizeCategoryIconKey(Object? value) =>
    isValidCategoryIconKey(value) ? value as String : null;

const _neutralKeys = <String>[
  'prayer',
  'spiritual-reading',
  'meditation',
  'daily',
  'cross',
  'faith',
  'hope',
  'trust',
];

const _l = '(?<![а-яёіў])';
const _r = '(?![а-яёіў])';
// Keep in step with RULES in the web app (`prayerCategoryIcons.js`).
final List<(RegExp, String)> _rules = [
  (RegExp('непарочн|беззаган|непорочн'), 'immaculate-heart'),
  (
    RegExp('сэрц\\S* (езус|ісус)|сердц\\S* иисус|найсвяцейшае сэрца'),
    'sacred-heart',
  ),
  (RegExp('ружан|розари'), 'rosary'),
  (RegExp('адарацы|адорац|манстранц|найсвяцейшы сакрамэнт'), 'monstrance'),
  (RegExp('эўхарыст|евхарист|прычасц|причаст'), 'chalice-host'),
  (
    RegExp('крыжов\\S* шлях|крестн\\S* путь|страсц|страст|укрыжав|распят'),
    'crucifix',
  ),
  (RegExp('дух святы|святы дух|святого духа|святой дух'), 'holy-spirit-dove'),
  (RegExp('памерл|умерш|чыстц|вернічаў'), 'candle'),
  (
    RegExp(
      (_l +
          'свяціц|' +
          _l +
          'святы(я|х|м)' +
          _r +
          '|' +
          _l +
          'святых|' +
          _l +
          'святой' +
          _r +
          '|' +
          _l +
          'святы' +
          _r),
    ),
    'saint-halo',
  ),
  (RegExp('марыйн|багародзіц|богородиц|маці божая'), 'virgin-mary'),
  (
    RegExp(
      (_l + 'марыя' + _r + '|' + _l + 'марыі' + _r + '|' + _l + 'марыю' + _r),
    ),
    'virgin-mary',
  ),
  (RegExp('анёл|ангел'), 'angel'),
  (RegExp('літані|литани'), 'litany'),
  (RegExp('навэн|новен'), 'novena'),
  (RegExp('раніц|утренн|утро'), 'morning'),
  (RegExp('вечар|вечерн|вечер'), 'evening'),
  (RegExp("сям'я|семь[яи]|сем[ьъ]"), 'family'),
  (RegExp('дзеці|дзяцей|дети|детск'), 'children'),
  (RegExp((_l + 'мір' + _r + '|' + _l + 'мир' + _r)), 'peace'),
  (RegExp('паломн|пилигрим'), 'pilgrimage'),
  (RegExp('просьб|прашэнн'), 'petitions'),
  (RegExp('пакаян|покаян'), 'repentance'),
  (RegExp('падзяк|благодар'), 'thanksgiving'),
  (RegExp('хвал|праслаў'), 'praise'),
  (RegExp('надзе|надеж'), 'hope'),
  (RegExp('давер'), 'trust'),
  (RegExp('разважан|медитац'), 'meditation'),
  (RegExp('кветк|цвет'), 'mary-flowers'),
  (RegExp('евангел|эвангел'), 'gospel'),
  (RegExp('пісанн|писани'), 'scripture'),
  (RegExp('духоўн\\S* чытан|духовн\\S* чтен'), 'spiritual-reading'),
  (RegExp('кансэкрав|призван'), 'vocation'),
  (RegExp('хрост|крещен'), 'baptism'),
  (RegExp('касцёл|царкв|костел|церков'), 'church'),
  (RegExp('цішын|тишин'), 'silence'),
  (RegExp('стварэнн|творен'), 'creation'),
  (RegExp('звон'), 'bell'),
  (RegExp((_l + 'крыж|' + _l + 'крест')), 'cross'),
];

String _normalizeText(String? value) => (value ?? '')
    .toLowerCase()
    .replaceAll('\u0301', '')
    .replaceAll('\u2019', "'");

/// FNV-1a over UTF-16 code units; identical to the web implementation.
int stableCategoryHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// A meaningful icon for a category that has none yet. Deterministic: keyword
/// rules over name + tags, then a stable hash over neutral icons. Used once
/// (migration / creation default); never to override a stored choice.
String suggestCategoryIconKey({
  String id = '',
  String name = '',
  List<String> tags = const [],
}) {
  final nameText = _normalizeText(name);
  final tagText = _normalizeText(tags.join(' '));
  for (final text in [nameText, '$nameText $tagText']) {
    for (final (pattern, key) in _rules) {
      if (pattern.hasMatch(text)) return key;
    }
  }
  final seed = _normalizeText(id).isNotEmpty ? _normalizeText(id) : nameText;
  return _neutralKeys[stableCategoryHash(seed) % _neutralKeys.length];
}

/// What to draw: a stored key (unknown ones fall back inside the renderer),
/// else a suggestion.
String displayCategoryIconKey({
  String? iconKey,
  String id = '',
  String name = '',
  List<String> tags = const [],
}) {
  if (iconKey != null && iconKey.trim().isNotEmpty) return iconKey;
  return suggestCategoryIconKey(id: id, name: name, tags: tags);
}
