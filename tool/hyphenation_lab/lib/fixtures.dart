/// Local, hard-coded fixtures. No canonical data is read or modified.
///
/// The first sentence run is the opening quoted in the task description
/// (Тыт 2, 1–5). Everything after "…належыць святым" is a NEUTRAL TRAINING
/// TEXT written for this lab. It is NOT a quotation of the Bible.
const fixtureTitle = 'Тыт 2, 1–5';

const fixtureDisclaimer =
    'ФІКСТУРА: пачатак узяты з тэхзадання; працяг — вучэбны тэкст, не цытата.';

const plainParagraphs = <String>[
  'Умілаваныя: Кажы тое, што адпавядае здароваму вучэнню: старцы павінны быць '
      'цвярозыя, годныя пашаны, стрыманыя, здаровыя ў веры, у любові, у '
      'цярплівасці. Старэйшыя жанчыны таксама павінны паводзіць сябе так, як '
      'належыць святым… Далей ідзе вучэбны фрагмент, дададзены толькі для '
      'праверкі наборкі: слова дабраслаўлёны, перасцерагальны, удзячнасць, '
      'працягваецца, выкарыстоўваюцца павінны пераносіцца па складах, а '
      'кароткія слова ў, і, а, з не павінны заставацца ў канцы радка.',
  'Радок з рубрыкай * і знакам † не павінен губляць іх пры пераносе. '
      'Слова «з’яўляецца» і гл. Мц 5, 3–12 не павінны разрывацца недарэчна.',
];

/// Second fixture: an HTML paragraph set with italic, emphasis, a rubric,
/// ў/і/ё, apostrophes, a link and non-breaking spaces (&nbsp;).
const htmlFixture = '''
<p><span class="liturgical-rubric-inline">Рубрыка:</span> Умілаваныя, <em>старэйшыя жанчыны</em> таксама павінны паводзіць сябе <strong>годна</strong>, як належыць святым, і быць <em>прыкладам</em> для маладзейшых. Гл.&nbsp;<a href="https://example.invalid/tyt">Тыт&nbsp;2,&nbsp;3–5</a> і Мц&nbsp;5,&nbsp;3–12. Вучэбны тэкст, не цытата.</p>
<p>Словы з ў, і, ё: <em>удзячнасць, ініцыятыва, ёсць</em>, з’яўляецца, аб’ява, пад’ём, з’езд; <strong>падзякаваць</strong> <span class="liturgical-rubric-inline">* †</span> дабраслаўлёны, перасцерагальны, выкарыстоўваюцца, прадаўжэнне распаўсюджваецца.</p>
''';
