import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final _parishWebsite = Uri.parse('https://www.mic-minsk.by');

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);

    return Stack(
      children: [
        AmbientWash(
          seasonColor: seasonColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
              final availableHeight =
                  constraints.maxHeight - 28 - bottomPadding;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 28 + bottomPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: availableHeight < 0 ? 0 : availableHeight,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: GlassSurface(
                        seasonColor: seasonColor,
                        borderRadius: BorderRadius.circular(28),
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                        child: const _AboutContent(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Image.asset(
            'assets/mary.png',
            width: 300,
            height: 300,
            fit: BoxFit.contain,
            semanticLabel: 'Герб з выявай Найсвяцейшай Панны Марыі',
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Парафія Беззаганнага Зачацця\n'
          'Найсвяцейшай Панны Марыі,\n'
          'г. Мінск, Айцы марыяне',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 6),
        Semantics(
          link: true,
          label: 'Адкрыць сайт парафіі www.mic-minsk.by',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openParishWebsite(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'www.mic-minsk.by',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Распрацоўшчык @davin_dev',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 38),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) => Text(
            'Версія: ${snapshot.data?.version ?? '—'}',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openParishWebsite(BuildContext context) async {
    final opened = await launchUrl(
      _parishWebsite,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не ўдалося адкрыць сайт')));
    }
  }
}
