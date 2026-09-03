import 'package:phosphor_flutter/phosphor_flutter.dart';

class HoraItem {
  final String type;
  final String label;
  final String subtitle;
  final PhosphorIconData icon;
  final List<String> checkFields;

  const HoraItem({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.checkFields,
  });
}

const kHoraItems = [
  HoraItem(
    type: 'invitatorium',
    label: 'Заклік',
    subtitle: 'Invitatorium',
    icon: PhosphorIconsRegular.sunHorizon,
    checkFields: ['invitatoriumAnt', 'invitatoriumPs1'],
  ),
  HoraItem(
    type: 'morning',
    label: 'Агульная гадзіна',
    subtitle: 'Invitatorium · Officium lectionis · Laudes',
    icon: PhosphorIconsLight.cloudSun,
    checkFields: ['invitatoriumAnt', 'laudesHymn', 'officeOfReadingsHymn'],
  ),
  HoraItem(
    type: 'lectionis',
    label: 'Гадзіна чытанняў',
    subtitle: 'Officium lectionis',
    icon: PhosphorIconsRegular.bookOpenText,
    checkFields: ['officeOfReadingsHymn', 'officeOfReadingsAnt1'],
  ),
  HoraItem(
    type: 'laudes',
    label: 'Ютрань',
    subtitle: 'Laudes matutinae',
    icon: PhosphorIconsRegular.sun,
    checkFields: ['laudesHymn', 'laudesAnt1'],
  ),
  HoraItem(
    type: 'terz',
    label: 'Малітва перад поўднем',
    subtitle: 'Tertia',
    icon: PhosphorIconsRegular.clock,
    checkFields: ['sext1Hymn', 'sext1Ant1'],
  ),
  HoraItem(
    type: 'sext',
    label: 'Малітва апоўдні',
    subtitle: 'Sexta',
    icon: PhosphorIconsRegular.sun,
    checkFields: ['sext2Hymn', 'sext2R'],
  ),
  HoraItem(
    type: 'non',
    label: 'Малітва пасля поўдня',
    subtitle: 'Nona',
    icon: PhosphorIconsRegular.cloudSun,
    checkFields: ['sext3Hymn', 'sext3Ant1'],
  ),
  HoraItem(
    type: 'vespers',
    label: 'Нешпары',
    subtitle: 'Vesperae',
    icon: PhosphorIconsRegular.moon,
    checkFields: ['vesperHymn', 'vesperAnt1'],
  ),
  HoraItem(
    type: 'completorium',
    label: 'Камплета',
    subtitle: 'Completorium',
    icon: PhosphorIconsRegular.moonStars,
    checkFields: ['compHymn', 'compAnt1'],
  ),
];
