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
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Scaffold(
      body: AmbientBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Small phones: the icon moves beside the name and the spacing
              // tightens, so that the button is visible without scrolling.
              final small = constraints.maxHeight < 620;
              final medium = !small && constraints.maxHeight < 740;
              final gap = small
                  ? 8.0
                  : medium
                  ? 14.0
                  : 20.0;
              // Narrow screen with large text: drop the decorative icons so
              // that words are not broken in the middle.
              final icons = constraints.maxWidth / textScale >= 250;
              final mark = Image.asset(
                'assets/brand_mark.png',
                width: small
                    ? 48
                    : medium
                    ? 64
                    : 88,
                height: small
                    ? 48
                    : medium
                    ? 64
                    : 88,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              );
              final name = Semantics(
                header: true,
                // One word: shrink rather than break it.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Малітоўнік',
                    style:
                        (small
                                ? theme.textTheme.headlineSmall
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              );
              final tagline = Text(
                'Малітва і Божае слова на кожны дзень',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              );
              return SingleChildScrollView(
                key: const Key('welcome-scroll'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: small ? 16 : 20,
                          vertical: small ? 6 : 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (small && textScale <= 1.3) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  mark,
                                  const SizedBox(width: 12),
                                  Flexible(child: name),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ] else ...[
                              Center(child: mark),
                              const SizedBox(height: 8),
                              name,
                              const SizedBox(height: 4),
                            ],
                            tagline,
                            SizedBox(height: gap),
                            Text(
                              'З чаго жадаеце пачынаць?',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium,
                            ),
                            SizedBox(height: small ? 6 : 12),
                            for (final section in kWelcomeSections)
                              Padding(
                                padding: EdgeInsets.only(bottom: small ? 6 : 8),
                                child: SelectionOptionCard(
                                  key: Key('welcome-option-${section.id}'),
                                  title: section.title,
                                  subtitle: section.description,
                                  titleFontSize: 18,
                                  subtitleFontSize: 14,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: small ? 12 : 16,
                                    vertical: small
                                        ? 6
                                        : medium
                                        ? 9
                                        : 14,
                                  ),
                                  leading: icons ? Icon(section.icon) : null,
                                  selected: _selected == section.id,
                                  onTap: () =>
                                      setState(() => _selected = section.id),
                                ),
                              ),
                            SizedBox(height: small ? 0 : gap - 8),
                            FilledButton(
                              key: const Key('welcome-start'),
                              style: FilledButton.styleFrom(
                                minimumSize: Size.fromHeight(small ? 48 : 52),
                                textStyle: theme.textTheme.titleMedium,
                              ),
                              onPressed: _selected == null || _saving
                                  ? null
                                  : _start,
                              child: const Text('Пачаць'),
                            ),
                            SizedBox(height: small ? 6 : 10),
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
