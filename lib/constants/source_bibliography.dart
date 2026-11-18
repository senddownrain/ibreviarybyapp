// Public bibliography from the approved "Крыніцы-2" document (12.11.2026).
// This list is independent of the technical registry used for reader footers.
class SourceBibliographyItem {
  const SourceBibliographyItem({
    required this.id,
    required this.section,
    required this.title,
    this.details = const [],
    required this.notices,
  });

  final String id;
  final String section;
  final String title;
  final List<String> details;
  final List<String> notices;
}

const kPublicSourceBibliographySections = <String>[
  'Касцёльныя крыніцы',
  'Іншыя крыніцы',
];

const kPublicSourceBibliography = <SourceBibliographyItem>[
  SourceBibliographyItem(
    id: 'novy-zapavet-2017',
    section: 'Касцёльныя крыніцы',
    title: '«Новы запавет» (Мінск, 2017)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2017'],
  ),
  SourceBibliographyItem(
    id: 'rymski-imshal-2004',
    section: 'Касцёльныя крыніцы',
    title: '«Рымскі Імшал для дыяцэзій на Беларусі» (Мінск, 2004)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2004'],
  ),
  SourceBibliographyItem(
    id: 'liturhiya-hadzinau-2012-2020',
    section: 'Касцёльныя крыніцы',
    title: '«Літургія гадзінаў» (Мінск, 2012-2020)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2012-2020'],
  ),
  SourceBibliographyItem(
    id: 'kampendyi-2010',
    section: 'Касцёльныя крыніцы',
    title: '«Катэхізіс Каталіцкага Касцёла. Кампендый» (Мінск, 2010)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2010'],
  ),
  SourceBibliographyItem(
    id: 'paradak-khrostu-2026',
    section: 'Касцёльныя крыніцы',
    title: '«Парадак хросту дзяцей» (Мінск, 2026)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2026'],
  ),
  SourceBibliographyItem(
    id: 'paradak-pakajannia-2016',
    section: 'Касцёльныя крыніцы',
    title: '«Парадак пакаяння» (Мінск, 2016)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2016'],
  ),
  SourceBibliographyItem(
    id: 'paradak-namashchennia-2009',
    section: 'Касцёльныя крыніцы',
    title: '«Парадак намашчэння хворых» (Мінск, 2009)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2009'],
  ),
  SourceBibliographyItem(
    id: 'sviataja-kamunija-2017',
    section: 'Касцёльныя крыніцы',
    title: '«Святая Камунія і культ эўхарыстычнай таямніцы па-за Імшой» (Мінск, 2017)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2017'],
  ),
  SourceBibliographyItem(
    id: 'lektsyjanaryi-2002-2005',
    section: 'Касцёльныя крыніцы',
    title: '«Лекцыянарый» (Мінск, 2002-2005)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2002-2005'],
  ),
  SourceBibliographyItem(
    id: 'liturhichnaja-ahenda-2010',
    section: 'Касцёльныя крыніцы',
    title: '«Літургічная агенда» (Мінск, 2010)',
    notices: ['© Мінска-Магілёўская архідыяцэзія, 2010'],
  ),
  SourceBibliographyItem(
    id: 'bozha-my-tsiabe-uslavljajem-2026',
    section: 'Касцёльныя крыніцы',
    title: 'Спеўнік «Божа, мы Цябе ўслаўляем» (Мінск, 2026)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2026'],
  ),
  SourceBibliographyItem(
    id: 'ojcha-nash-2022',
    section: 'Касцёльныя крыніцы',
    title: 'Малітоўнік «Ойча наш» (Мінск, 2022)',
    notices: ['© Камісія Божага Культу і Дысцыпліны Сакрамэнтаў, 2022', '© Выдавецтва «Про Хрысто», 2022'],
  ),
  SourceBibliographyItem(
    id: 'prasitsee-i-atrymaetse-2024',
    section: 'Касцёльныя крыніцы',
    title: 'Малітоўнік «Прасіце і атрымаеце» (Мінск, 2024).',
    notices: ['© Выдавецтва «Про Хрысто», 2024'],
  ),
  SourceBibliographyItem(
    id: 'bog-dobry-2022',
    section: 'Касцёльныя крыніцы',
    title: 'Малітоўнік «Бог Добры» (Пінск, 2022)',
    notices: ['© Выдавецтва Пінскай дыяцэзіі, 2022'],
  ),
  SourceBibliographyItem(
    id: 'kab-paznali-tsiabe-2014',
    section: 'Касцёльныя крыніцы',
    title: 'Малітоўнік «Каб пазналі Цябе» (Гродна, 2014)',
    notices: ['© Выдавецтва Гродзенскай дыяцэзіі, 2014'],
  ),
  SourceBibliographyItem(
    id: 'biblia-charniauski-2017',
    section: 'Іншыя крыніцы',
    title: '«Біблія» (Мінск, 2017)',
    details: ['Стары Запавет - на падставе рукапісаў кс. У. Чарняўскага'],
    notices: ['© «Біблійнае таварыства ў Рэспубліцы Беларусь», 2017'],
  ),
  SourceBibliographyItem(
    id: 'biblia-synodal',
    section: 'Іншыя крыніцы',
    title: '«Библия» (Синодальный перевод)',
    notices: [],
  ),
];
