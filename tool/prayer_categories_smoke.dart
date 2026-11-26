import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/dev/prayer_categories_harness.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';

// Synthetic only. flutter run -d chrome -t tool/prayer_categories_smoke.dart --web-port 5237
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final content = PrayerAccessContent(
    {
      'tagged': {
        'title': 'Ранішняя малітва',
        'tags': ['root-tag'],
        'text': 'Сінтэтычны тэкст для праверкі інтэрфейсу.',
      },
      'manual': {
        'title': 'Асобна дададзеная малітва',
        'tags': [],
        'text': 'Сінтэтычная малітва.',
      },
      'both': {
        'title': 'Малітва па тэгу і спасылцы',
        'tags': ['root-tag'],
        'text': 'Сінтэтычная малітва.',
      },
      'leaf-prayer': {
        'title': 'Малітва ў падкатэгорыі',
        'tags': [],
        'text': 'Тэкст у другім узроўні ўкладзенасці.',
      },
      'legacy-linked': {
        'title': 'Малітва са старой сувяззю',
        'categoryId': 'legacy',
        'text': 'Сінтэтычная малітва.',
      },
      'shared-private': {
        'title': 'PRIVATE SHARED FIXTURE',
        'text': 'PRIVATE TEXT FIXTURE',
      },
    },
    {
      'root': {
        'name': 'Штодзённыя малітвы з доўгай назвай катэгорыі',
        'tags': ['root-tag'],
        'prayerIds': ['manual', 'both', 'shared-private'],
        'order': 10,
        'iconKey': 'virgin-mary',
        'comment': {
          'title': 'Тлумачэнне',
          'content':
              '''Гэта **сінтэтычны тэкст** для праверкі адлюстравання.

> Прыклад аформленай цытаты.

:::rubric
Прыклад аформленай рубрыкі.
:::

[Адкрыць прыклад малітвы](/prayer/manual)

${List.filled(8, 'Доўгі каментарый пракручваецца разам са спісам катэгорый і малітваў.').join('\n\n')}

Канец сінтэтычнага каментарыя.''',
          'sourceId': 'ojcha-nash-2022',
        },
      },
      'middle': {
        'name': 'Малітвы на кожны дзень',
        'tags': [],
        'parentId': 'root',
        'order': 10,
        'iconKey': 'rosary',
      },
      'leaf': {
        'name': 'Ранішнія і вячэрнія малітвы',
        'tags': [],
        'prayerIds': ['leaf-prayer'],
        'parentId': 'middle',
        'order': 20,
        'iconKey': 'candle',
      },
      'legacy': {'name': 'Іншыя малітвы', 'tags': [], 'order': 20},
      'comment-only': {
        'name': 'Раздзел з каментарыем',
        'parentId': 'root',
        'order': 30,
        'comment': {'content': 'Тэкст раздзела без асобных запісаў.'},
      },
      'folder': {'name': 'Empty fixture folder', 'tags': [], 'order': 30},
      'closed': {
        'name': 'PRIVATE CATEGORY FIXTURE',
        'priestOnly': true,
        'prayerIds': ['shared-private'],
      },
    },
  );
  runApp(
    PrayerCategoriesHarness(
      content: content,
      scheme: Uri.base.queryParameters['theme'] ?? 'light',
      scale: double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1,
    ),
  );
}
