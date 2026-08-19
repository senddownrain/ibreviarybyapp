import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';

// ─── Fixed liturgical texts ───────────────────────────────────────────────────

const _kPaterNoster = 'Ойча наш.';

const _kBenedictus = '''<p>Благаслаўлёны Пан, Бог Ізраэля, *<br>бо наведаў і адкупіў народ свой,</p>
<p>і ўзняў моц збаўлення для нас *<br>у доме Давіда, слугі свайго.</p>
<p>Як абвясціў спрадвеку *<br>вуснамі сваіх святых прарокаў,</p>
<p>што збавіць нас ад ворагаў нашых *<br>і ад рук усіх, хто нас ненавідзіць.</p>
<p>Каб праявіць міласэрнасць да айцоў нашых *<br>і нагадаць пра святы запавет свой.</p>
<p>Прысягу, якую даў Абрагаму, айцу нашаму, *<br>дасць нам.</p>
<p>Каб, выбаўленыя з рук ворагаў, *<br>мы без страху служылі Яму</p>
<p>ў святасці і справядлівасці перад Ім *<br>ва ўсе дні нашыя.</p>
<p>А ты, дзіцятка, прарокам Найвышэйшага будзеш названа, *<br>бо пойдзеш прад абліччам Пана падрыхтаваць шляхі Яму,</p>
<p>каб даць народу Ягонаму пазнаць збаўленне *<br>праз адпушчэнне яго грахоў,</p>
<p>дзякуючы сардэчнай міласэрнасці нашага Бога, *<br>у якой наведаў нас Усход з вышыні;</p>
<p>каб асвятліць тых, *<br>хто сядзіць у цемры і ў цені смяротным;</p>
<p>каб накіраваць ногі нашыя *<br>на шлях спакою.</p>
<p>Хвала Айцу і Сыну, *<br>І Духу Святому.</p>
<p>Як была спрадвеку, цяпер і заўсёды, *<br>і на векі вечныя. Амэн.</p>''';

const _kMagnificat = '''<p>Велічае душа мая Пана, *<br>і ўзрадаваўся дух мой у Богу, маім Збаўцу,</p>
<p>бо глянуў Бог на пакору сваёй слугі. *<br>І цяпер благаслаўляць мяне будуць усе пакаленні.</p>
<p>Бо вялікае ўчыніў мне Усемагутны, *<br>а імя Яго святое.</p>
<p>І міласэрнасць Яго з пакалення ў пакаленне *<br>над тымі, хто Яго баіцца.</p>
<p>Паказаў моц сваёй правіцы, *<br>рассеяў тых, хто пыхлівы сэрцам.</p>
<p>Скінуў магутных з трону *<br>і ўзвысіў пакорных.</p>
<p>Дабром галодных насыціў, *<br>а багатых ні з чым адправіў.</p>
<p>Прыняў свайго слугу Ізраэля, *<br>памятаючы пра сваю міласэрнасць,</p>
<p>як абяцаў бацькам нашым — *<br>Абрагаму і яго патомству навекі.</p>
<p>Хвала Айцу і Сыну, *<br>І Духу Святому.</p>
<p>Як была спрадвеку, цяпер і заўсёды, *<br>і на векі вечныя. Амэн.</p>''';

const _kNunc = '''<p>Цяпер адпускаеш слугу Твайго, Валадару, *<br>паводле слова Твайго, у спакоі;</p>
<p>бо вочы мае ўбачылі збаўленне Тваё, *<br>якое падрыхтаваў Ты перад абліччам усіх народаў,</p>
<p>святло для асвятлення язычнікаў *<br>і хвалу народу Твайго Ізраэля.</p>
<p>Хвала Айцу і Сыну, *<br>І Духу Святому.</p>
<p>Як была спрадвеку, цяпер і заўсёды, *<br>і на векі вечныя. Амэн.</p>''';

const _kEndOfVesper =
    '<p><span style="color:red">Потым, калі прысутнічае святар або дыякан, ён рассылае народ.</span></p>'
    '<p><span style="color:red">Калі святар або дыякан адсутнічаюць ці калі Гадзіна чытаецца індывідуальна:</span></p>'
    '<p><span style="color:red">К.</span> Няхай Пан благаславіць нас, абароніць ад усялякага зла і давядзе да жыцця вечнага.</p>'
    '<p><span style="color:red">Н.</span> Амэн.</p>';

const _kEndOfComplineBlessing =
    '<p><span style="color:red">К.</span> Ноч спакойную і смерць шчаслівую няхай дасць нам Бог усемагутны, Айцец і Сын, і Дух Святы.</p>'
    '<p><span style="color:red">Н.</span> Амэн.</p>';

const _kInvitIntro =
    '<p><span style="color:red">К.</span> Пане, адкрый мае вусны.</p>'
    '<p><span style="color:red">Н.</span> І вусны мае будуць абвяшчаць Тваю хвалу.</p>';

// ─── Main screen ──────────────────────────────────────────────────────────────

class OraScreen extends ConsumerWidget {
  final String dayId;
  final String oraType;

  const OraScreen({super.key, required this.dayId, required this.oraType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final raw = HiveService.daysBox.get(dayId);
    if (raw == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_oraTitle(oraType))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsLight.bookOpen, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text('Дзень не знойдзены'),
              const SizedBox(height: 4),
              Text(
                'Магчыма, трэба сінхранізаваць дадзеныя ў Наладах',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final day = LiturgicalDay.fromMap(Map<String, dynamic>.from(raw));

    return ReadingScaffold(
      builder: (context, textStyle) => Scaffold(
        appBar: AppBar(
          title: Text(_oraTitle(oraType)),
          actions: [
            PopupMenuButton<double>(
              icon: const PhosphorIcon(PhosphorIconsRegular.textAa, size: 22),
              onSelected: (size) =>
                  ref.read(settingsProvider.notifier).setFontSize(size),
              itemBuilder: (_) => [
                for (final size in [14.0, 16.0, 18.0, 20.0, 24.0])
                  PopupMenuItem(
                    value: size,
                    child: Text(
                      '${size.toInt()} pt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: size == settings.fontSize
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: _buildContent(context, day, textStyle),
      ),
    );
  }

  // ─── Content dispatcher ─────────────────────────────────────────────────────

  Widget _buildContent(
      BuildContext context, LiturgicalDay day, TextStyle textStyle) {
    final sections = switch (oraType) {
      'morning' => _buildMorning(day),
      'invitatorium' => _buildInvitatorium(day),
      'lectionis' => _buildLectionis(day),
      'laudes' => _buildLaudes(day),
      'terz' => _buildSextHour(day, num: 1, psalmDb: 1),
      'sext' => _buildSextHour(day, num: 2, psalmDb: 1),
      'non' => _buildSextHour(day, num: 3, psalmDb: 3),
      'vespers' => _buildVespers(day),
      'completorium' => _buildCompline(day),
      _ => <_OraItem>[],
    };

    if (sections.isEmpty) {
      return const Center(child: Text('Няма зместу'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sections.length,
      itemBuilder: (_, i) => sections[i].build(context, textStyle),
    );
  }

  // ─── Invitatorium ────────────────────────────────────────────────────────────
  // Fields: invitatoriumAnt, invitatoriumPs1–6

  List<_OraItem> _buildInvitatorium(LiturgicalDay day) {
    final ant = day.field('invitatoriumAnt') ?? '';
    final items = <_OraItem>[];

    items.add(_OraItem.sectionTitle('ЗАКЛІК'));
    items.add(_OraItem.html(_kInvitIntro));

    if (ant.isNotEmpty) {
      for (var i = 1; i <= 6; i++) {
        final ps = day.field('invitatoriumPs$i');
        if (ps == null || ps.isEmpty) break;
        items.add(_OraItem.labeled('Антыфон', ant));
        items.add(_OraItem.labeled('Псальм $i', ps));
      }
      items.add(_OraItem.labeled('Антыфон', ant));
    }

    return items;
  }

  // ─── Lectionis (Office of Readings / Гадзіна чытанняў) ──────────────────────
  // Fields: officeOfReadings{Hymn, Ant1-3, Ps1-3, Vers, R1, R2, Pr}

  List<_OraItem> _buildLectionis(LiturgicalDay day) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('ГАДЗІНА ЧЫТАННЯЎ'));
    _addHymn(items, day, 'officeOfReadingsHymn');
    _addPsalmsWithAnts(items, day,
        antPrefix: 'officeOfReadingsAnt', psPrefix: 'officeOfReadingsPs', count: 3);
    _addField(items, day, 'officeOfReadingsVers', 'Верш');
    _addField(items, day, 'officeOfReadingsR1', 'Чытанне 1');
    _addField(items, day, 'officeOfReadingsR2', 'Чытанне 2');
    _addField(items, day, 'officeOfReadingsPr', 'Малітва');
    items.add(_OraItem.html(_kEndOfVesper));
    return items;
  }

  // ─── Laudes (Ютрань) ─────────────────────────────────────────────────────────
  // Fields: laudes{Hymn, Ant1-3, Ps1-3, R, AntBen, Inter, Pr}

  List<_OraItem> _buildLaudes(LiturgicalDay day) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('ЮТРАНЬ'));
    _addHymn(items, day, 'laudesHymn');
    _addPsalmsWithAnts(items, day,
        antPrefix: 'laudesAnt', psPrefix: 'laudesPs', count: 3);
    _addField(items, day, 'laudesR', 'Рэспансорый');

    // Benedictus with antiphon
    final antBen = day.field('laudesAntBen') ?? '';
    if (antBen.isNotEmpty) {
      items.add(_OraItem.labeled('Антыфон', antBen));
      items.add(_OraItem.titled('ПЕСНЯ З ЕВАНГЕЛЛЯ',
          subtitle: 'Песня Захарыі (Лк 1, 68–79)\nМесія і Яго папярэднік',
          html: _kBenedictus));
      items.add(_OraItem.labeled('Антыфон', antBen));
    }

    _addField(items, day, 'laudesInter', 'Прашэнні');
    items.add(_OraItem.plain('Ойча наш.', label: 'Малітва Гасподняя'));
    _addField(items, day, 'laudesPr', 'Малітва');
    items.add(_OraItem.html(_kEndOfVesper));
    return items;
  }

  // ─── Terz / Sext / Non ───────────────────────────────────────────────────────
  // Terz: num=1, psalmDb=1 — sext1Hymn, sext1Ant1-3, sext1Ps1-3, sext1R, sext1Pr
  // Sext: num=2, psalmDb=1 — sext2Hymn, sext1Ant1-3, sext1Ps1-3, sext2R, sext2Pr
  // Non:  num=3, psalmDb=3 — sext3Hymn, sext3Ant1-3, sext3Ps1-3, sext3R, sext3Pr

  List<_OraItem> _buildSextHour(LiturgicalDay day,
      {required int num, required int psalmDb}) {
    final title = switch (num) {
      1 => 'МАЛІТВА ПЕРАД ПОЎДНЕМ',
      2 => 'МАЛІТВА АПОЎДНІ',
      3 => 'МАЛІТВА ПАСЛЯ ПОЎДНЯ',
      _ => 'МАЛІТВА',
    };

    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle(title));
    _addHymn(items, day, 'sext${num}Hymn');
    _addPsalmsWithAnts(items, day,
        antPrefix: 'sext${psalmDb}Ant', psPrefix: 'sext${psalmDb}Ps', count: 3);
    _addField(items, day, 'sext${num}R', 'Чытанне');
    _addField(items, day, 'sext${num}Pr', 'Малітва');
    items.add(_OraItem.html(_kEndOfVesper));
    return items;
  }

  // ─── Vespers (Нешпары) ───────────────────────────────────────────────────────
  // Fields: vesper{Hymn, Ant1-3, Ps1-3, R, AntMag, Inter, Pr}

  List<_OraItem> _buildVespers(LiturgicalDay day) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('НЕШПАРЫ'));
    _addHymn(items, day, 'vesperHymn');
    _addPsalmsWithAnts(items, day,
        antPrefix: 'vesperAnt', psPrefix: 'vesperPs', count: 3);
    _addField(items, day, 'vesperR', 'Рэспансорый');

    // Magnificat with antiphon
    final antMag = day.field('vesperAntMag') ?? '';
    if (antMag.isNotEmpty) {
      items.add(_OraItem.labeled('Антыфон', antMag));
      items.add(_OraItem.titled('ПЕСНЯ З ЕВАНГЕЛЛЯ',
          subtitle: 'Песня Марыі (Лк 1, 46–55)\nРадасць душы ў Пану',
          html: _kMagnificat));
      items.add(_OraItem.labeled('Антыфон', antMag));
    }

    _addField(items, day, 'vesperInter', 'Прашэнні');
    items.add(_OraItem.plain(_kPaterNoster, label: 'Малітва Гасподняя'));

    // vesperPr fallback to laudesPr
    final pr = day.field('vesperPr') ?? '';
    final fallbackPr = pr.isNotEmpty ? pr : (day.field('laudesPr') ?? '');
    if (fallbackPr.isNotEmpty) {
      items.add(_OraItem.labeled('Малітва', fallbackPr));
    }

    items.add(_OraItem.html(_kEndOfVesper));
    return items;
  }

  // ─── Completorium (Камплета) ─────────────────────────────────────────────────
  // Fields: comp{Hymn, Ant1-3, Ps1, R, Resp, AntS, Pr, AntM}

  List<_OraItem> _buildCompline(LiturgicalDay day) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('КАМПЛЕТА'));

    // Examination of conscience intro
    items.add(_OraItem.html(
        '<p><span style="color:red">Кароткі выпытванне сумлення.</span></p>'));

    _addHymn(items, day, 'compHymn');
    _addPsalmsWithAnts(items, day,
        antPrefix: 'compAnt', psPrefix: 'compPs', count: 1);
    _addField(items, day, 'compR', 'Чытанне');
    _addField(items, day, 'compResp', 'Рэспансорый');

    // Nunc Dimittis with antiphon
    final antS = day.field('compAntS') ?? '';
    if (antS.isNotEmpty) {
      items.add(_OraItem.labeled('Антыфон', antS));
      items.add(_OraItem.titled('ПЕСНЯ З ЕВАНГЕЛЛЯ',
          subtitle: 'Песня Сімяона (Лк 2, 29–32)\nХрыстус – святло народаў і хвала Ізраэля',
          html: _kNunc));
      items.add(_OraItem.labeled('Антыфон', antS));
    }

    _addField(items, day, 'compPr', 'Малітва');

    // End of Compline
    items.add(_OraItem.html(_kEndOfComplineBlessing));

    final antM = day.field('compAntM') ?? '';
    if (antM.isNotEmpty) {
      items.add(_OraItem.titled(
          'АНТЫФОНЫ НА ЗАКАНЧЭННЕ ДА НАЙСВЯЦЕЙШАЙ ПАННЫ МАРЫІ',
          html: antM));
    }

    return items;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _addHymn(List<_OraItem> items, LiturgicalDay day, String field) {
    final v = day.field(field) ?? '';
    if (v.isNotEmpty) items.add(_OraItem.labeled('Гімн', v));
  }

  void _addField(
      List<_OraItem> items, LiturgicalDay day, String field, String label) {
    final v = day.field(field) ?? '';
    if (v.isNotEmpty) items.add(_OraItem.labeled(label, v));
  }

  void _addPsalmsWithAnts(
    List<_OraItem> items,
    LiturgicalDay day, {
    required String antPrefix,
    required String psPrefix,
    required int count,
  }) {
    for (var i = 1; i <= count; i++) {
      final ant = day.field('${antPrefix}$i') ?? '';
      final ps = day.field('${psPrefix}$i') ?? '';
      if (ant.isNotEmpty) items.add(_OraItem.labeled('Антыфон $i', ant));
      if (ps.isNotEmpty) items.add(_OraItem.labeled('Псальм $i', ps));
      if (ant.isNotEmpty && ps.isNotEmpty) {
        items.add(_OraItem.labeled('Антыфон $i', ant));
      }
    }
  }

  // ─── Morning (Агульная гадзіна) ─────────────────────────────────────────────
  // Combines Invitatorium + Lectionis + Laudes into one scroll

  List<_OraItem> _buildMorning(LiturgicalDay day) {
    return [
      ..._buildInvitatorium(day),
      ..._buildLectionis(day),
      ..._buildLaudes(day),
    ];
  }

  String _oraTitle(String type) => switch (type) {
        'morning' => 'Агульная гадзіна',
        'invitatorium' => 'Заклік',
        'lectionis' => 'Гадзіна чытанняў',
        'laudes' => 'Ютрань (Хвалы)',
        'terz' => 'Малітва перад поўднем',
        'sext' => 'Малітва апоўдні',
        'non' => 'Малітва пасля поўдня',
        'vespers' => 'Нешпары',
        'completorium' => 'Камплета',
        _ => type,
      };

}

// ─── _OraItem ─────────────────────────────────────────────────────────────────

enum _OraItemType { sectionTitle, labeled, titled, html, plain }

class _OraItem {
  final _OraItemType type;
  final String? label;
  final String? subtitle;
  final String content;

  const _OraItem._(this.type, this.content, {this.label, this.subtitle});

  factory _OraItem.sectionTitle(String title) =>
      _OraItem._(_OraItemType.sectionTitle, title);

  factory _OraItem.labeled(String label, String content) =>
      _OraItem._(_OraItemType.labeled, content, label: label);

  factory _OraItem.titled(String label, {String? subtitle, required String html}) =>
      _OraItem._(_OraItemType.titled, html, label: label, subtitle: subtitle);

  factory _OraItem.html(String html) =>
      _OraItem._(_OraItemType.html, html);

  factory _OraItem.plain(String text, {String? label}) =>
      _OraItem._(_OraItemType.plain, text, label: label);

  Widget build(BuildContext context, TextStyle textStyle) {
    switch (type) {
      case _OraItemType.sectionTitle:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Text(
            content,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        );

      case _OraItemType.labeled:
        return _LabeledSection(
            label: label!, content: content, textStyle: textStyle);

      case _OraItemType.titled:
        return _TitledSection(
          title: label!,
          subtitle: subtitle,
          content: content,
          textStyle: textStyle,
        );

      case _OraItemType.html:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HtmlOrText(content: content, textStyle: textStyle),
        );

      case _OraItemType.plain:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            Text(content, style: textStyle),
            const Divider(height: 24),
          ],
        );
    }
  }
}

// ─── Section widgets ──────────────────────────────────────────────────────────

class _LabeledSection extends StatelessWidget {
  final String label;
  final String content;
  final TextStyle textStyle;

  const _LabeledSection({
    required this.label,
    required this.content,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        _HtmlOrText(content: content, textStyle: textStyle),
        const Divider(height: 24),
      ],
    );
  }
}

class _TitledSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String content;
  final TextStyle textStyle;

  const _TitledSection({
    required this.title,
    this.subtitle,
    required this.content,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red[700],
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          const SizedBox(height: 8),
        _HtmlOrText(content: content, textStyle: textStyle),
        const Divider(height: 24),
      ],
    );
  }
}

class _HtmlOrText extends StatelessWidget {
  final String content;
  final TextStyle textStyle;

  const _HtmlOrText({required this.content, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    if (content.contains('<') && content.contains('>')) {
      return Html(
        data: content,
        style: {
          'body': Style(
            fontSize: FontSize(textStyle.fontSize ?? 16),
            fontFamily: textStyle.fontFamily,
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'p': Style(margin: Margins.only(bottom: 8)),
        },
      );
    }
    return SelectableText(content, style: textStyle);
  }
}
