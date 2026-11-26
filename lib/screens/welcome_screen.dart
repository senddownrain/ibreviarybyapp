import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/selection_option_card.dart';

/// The four start pages, with the same ids as the «startSection» setting and
/// the same icons as the navigation dock.
const kWelcomeSections =
    <({String id, String title, String description, PhosphorIconData icon})>[
      (
        id: 'hours',
        title: 'Літургія гадзінаў',
        description: 'Асабліва для святароў і кансэкраваных асоб',
        icon: PhosphorIconsRegular.sunHorizon,
      ),
      (
        id: 'readings',
        title: 'Чытанні дня',
        description: 'Божае слова ў штодзённай літургіі',
        icon: PhosphorIconsRegular.bookOpenText,
      ),
      (
        id: 'prayerbook',
        title: 'Малітоўнік',
        description: 'Малітвы і набажэнствы',
        icon: PhosphorIconsRegular.handsPraying,
      ),
      (
        id: 'bible',
        title: 'Біблія',
        description: 'Чытанне Святога Пісання',
        icon: PhosphorIconsRegular.bookOpen,
      ),
    ];

/// First-launch choice of the start page. Presentation only: [onStart] stores
/// the choice and leaves the screen; if it throws, the person stays here.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final Future<void> Function(String section) onStart;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _selected;
  bool _saving = false;

  Future<void> _start() async {
    final section = _selected;
    if (section == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onStart(section);
    } catch (error) {
      debugPrint('[Welcome] choice not saved: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не ўдалося захаваць выбар. Паспрабуйце яшчэ раз.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      body: AmbientBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final short = constraints.maxHeight < 700;
              final gap = short ? 12.0 : 20.0;
              // Narrow screen with large text: drop the decorative icons so
              // that words are not broken in the middle.
              final icons =
                  constraints.maxWidth /
                      (MediaQuery.textScalerOf(context).scale(10) / 10) >=
                  250;
              return SingleChildScrollView(
                key: const Key('welcome-scroll'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: short ? 12 : 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/brand_mark.png',
                                width: short ? 64 : 96,
                                height: short ? 64 : 96,
                                filterQuality: FilterQuality.medium,
                                excludeFromSemantics: true,
                              ),
                            ),
                            SizedBox(height: short ? 8 : 12),
                            Semantics(
                              header: true,
                              // One word: shrink rather than break it.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Малітоўнік',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Малітва і Божае слова на кожны дзень',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                            SizedBox(height: gap),
                            Text(
                              'З чаго жадаеце пачынаць?',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            for (final section in kWelcomeSections)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SelectionOptionCard(
                                  key: Key('welcome-option-${section.id}'),
                                  title: section.title,
                                  subtitle: section.description,
                                  titleFontSize: 18,
                                  subtitleFontSize: 14,
                                  dense: short,
                                  leading: icons ? Icon(section.icon) : null,
                                  selected: _selected == section.id,
                                  onTap: () =>
                                      setState(() => _selected = section.id),
                                ),
                              ),
                            SizedBox(height: gap - 8),
                            FilledButton(
                              key: const Key('welcome-start'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                textStyle: theme.textTheme.titleMedium,
                              ),
                              onPressed: _selected == null || _saving
                                  ? null
                                  : _start,
                              child: const Text('Пачаць'),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Пачатковую старонку можна змяніць у наладах.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
