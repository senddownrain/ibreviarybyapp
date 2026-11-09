import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/source_documents.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/constants/legal_links.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/data_settings_section.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final _parishWebsite = Uri.parse('https://www.mic-minsk.by');

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        AmbientWash(
          seasonColor: GlassTokens.of(context).ambientBase,
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
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(28, 36, 28, 28),
                          child: _AboutContent(),
                        ),
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
        Text(
          'у супрацоўніцтве з ККББ',
          key: const Key('about-cooperation-subtitle'),
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 18),
        TextButton(
          key: const Key('about-sources-link'),
          onPressed: () => context.push(sourcesRoute),
          child: const Text('Крыніцы і аўтарскія правы'),
        ),
        TextButton.icon(
          key: const Key('about-privacy-policy-link'),
          onPressed: () => _openPrivacyPolicy(context),
          icon: const Icon(Icons.privacy_tip_outlined, size: 20),
          label: const Text('Палітыка прыватнасці'),
        ),
        const SizedBox(height: 20),
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
        if (contentDate() case final date?) ...[
          const SizedBox(height: 4),
          Text(
            'Версія тэкстаў: ${formatContentVersion(date)}',
            key: const Key('about-content-version'),
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(kPrivacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не ўдалося адкрыць палітыку прыватнасці'),
        ),
      );
    }
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
