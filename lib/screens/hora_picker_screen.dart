import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

/// Metadata for one liturgical hour.
class _HoraItem {
  final String type;
  final String label;
  final String subtitle;
  final PhosphorIconData icon;
  final List<String> checkFields;

  const _HoraItem({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.checkFields,
  });
}

const _horas = [
  _HoraItem(
    type: 'morning',
    label: 'Агульная гадзіна',
    subtitle: 'Заклік + Гадзіна чытанняў + Ютрань',
    icon: PhosphorIconsLight.cloudSun,
    checkFields: ['invitatoriumAnt', 'laudesHymn', 'officeOfReadingsHymn'],
  ),
  _HoraItem(
    type: 'invitatorium',
    label: 'Заклік',
    subtitle: 'Invitatorium',
    icon: PhosphorIconsRegular.sunHorizon,
    checkFields: ['invitatoriumAnt', 'invitatoriumPs1'],
  ),
  _HoraItem(
    type: 'laudes',
    label: 'Ютрань',
    subtitle: 'Laudes',
    icon: PhosphorIconsRegular.sun,
    checkFields: ['laudesHymn', 'laudesAnt1'],
  ),
  _HoraItem(
    type: 'lectionis',
    label: 'Гадзіна чытанняў',
    subtitle: 'Office of Readings',
    icon: PhosphorIconsRegular.bookOpenText,
    checkFields: ['officeOfReadingsHymn', 'officeOfReadingsAnt1'],
  ),
  _HoraItem(
    type: 'terz',
    label: 'Малітва перад поўднем',
    subtitle: 'Terz',
    icon: PhosphorIconsRegular.clock,
    checkFields: ['sext1Hymn', 'sext1Ant1'],
  ),
  _HoraItem(
    type: 'sext',
    label: 'Малітва апоўдні',
    subtitle: 'Sext',
    icon: PhosphorIconsRegular.sun,
    checkFields: ['sext2Hymn', 'sext2R'],
  ),
  _HoraItem(
    type: 'non',
    label: 'Малітва пасля поўдня',
    subtitle: 'Non',
    icon: PhosphorIconsRegular.cloudSun,
    checkFields: ['sext3Hymn', 'sext3Ant1'],
  ),
  _HoraItem(
    type: 'vespers',
    label: 'Нешпары',
    subtitle: 'Vespers',
    icon: PhosphorIconsRegular.moon,
    checkFields: ['vesperHymn', 'vesperAnt1'],
  ),
  _HoraItem(
    type: 'completorium',
    label: 'Камплета',
    subtitle: 'Completorium',
    icon: PhosphorIconsRegular.moonStars,
    checkFields: ['compHymn', 'compAnt1'],
  ),
];

/// Screen showing list of available liturgical hours for a day.
class HoraPickerScreen extends StatelessWidget {
  final String dayId;

  const HoraPickerScreen({
    super.key,
    required this.dayId,
  });

  bool _isAvailable(_HoraItem hora, LiturgicalDay day) {
    return hora.checkFields.any((k) {
      final v = day.field(k);
      return v != null && v.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final raw = HiveService.daysBox.get(dayId);
    if (raw == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Літургія гадзін')),
        body: const Center(child: Text('Дзень не знойдзены')),
      );
    }
    final day = LiturgicalDay.fromMap(Map<String, dynamic>.from(raw));
    final dayTitle = day.feastName ?? day.title ?? '';

    final available = _horas.where((h) => _isAvailable(h, day)).toList();
    final unavailable = _horas.where((h) => !_isAvailable(h, day)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Літургія гадзін'),
            if (dayTitle.isNotEmpty)
              Text(
                dayTitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .appBarTheme
                          .foregroundColor
                          ?.withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
      ),
      body: ListView(
        children: [
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Змест гадзін не знойдзены для гэтага дня',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (final hora in available)
            ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: PhosphorIcon(
                  hora.icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              title: Text(hora.label),
              subtitle: Text(hora.subtitle),
              trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
              onTap: () => context.push('/ora/$dayId/${hora.type}'),
            ),
          if (unavailable.isNotEmpty && available.isNotEmpty) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Не запоўнена ў базе',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
            for (final hora in unavailable)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: PhosphorIcon(
                    hora.icon,
                    color: Theme.of(context).colorScheme.outline,
                    size: 20,
                  ),
                ),
                title: Text(
                  hora.label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline),
                ),
                subtitle: Text(hora.subtitle),
                enabled: false,
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
