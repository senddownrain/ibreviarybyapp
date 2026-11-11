// Public bibliography from the approved "Крыніцы" document (11.11.2026).
// This list is independent of the technical registry used for reader footers.
class SourceBibliographyItem {
  const SourceBibliographyItem({
    required this.id,
    required this.title,
    required this.notices,
  });

  final String id;
  final String title;
  final List<String> notices;
}

const kPublicSourceBibliography = <SourceBibliographyItem>[
  SourceBibliographyItem(
    id: 'novy-zapavet-2017',
    title: '«Новы запавет» (Мінск, 2017)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2017'],
  ),
  SourceBibliographyItem(
    id: 'rymski-imshal-2004',
    title: '«Рымскі Імшал для дыяцэзій на Беларусі» (Мінск, 2004)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2004'],
  ),
  SourceBibliographyItem(
    id: 'liturhiya-hadzinau-2012-2020',
    title: '«Літургія гадзінаў» (Мінск, 2012-2020)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2012-2020'],
  ),
  SourceBibliographyItem(
    id: 'kampendyi-2010',
    title: '«Катэхізіс Каталіцкага Касцёла. Кампендый» (Мінск, 2010)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2010'],
  ),
  SourceBibliographyItem(
    id: 'paradak-khrostu-2026',
    title: '«Парадак хросту дзяцей» (Мінск, 2026)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2026'],
  ),
  SourceBibliographyItem(
    id: 'paradak-pakajannia-2016',
    title: '«Парадак пакаяння» (Мінск, 2016)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2016'],
  ),
  SourceBibliographyItem(
    id: 'paradak-namashchennia-2009',
    title: '«Парадак намашчэння хворых» (Мінск, 2009)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2009'],
  ),
  SourceBibliographyItem(
    id: 'sviataja-kamunija-2017',
    title: '«Святая Камунія і культ эўхарыстычнай таямніцы па-за Імшой» (Мінск, 2017)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2017'],
  ),
  SourceBibliographyItem(
    id: 'lektsyjanaryi-2002-2005',
    title: '«Лекцыянарый» (Мінск, 2002-2005)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2002-2005'],
  ),
  SourceBibliographyItem(
    id: 'liturhichnaja-ahenda-2010',
    title: '«Літургічная агенда» (Мінск, 2010)',
    notices: ['© Мінска-Магілёўская архідыяцэзія, 2010'],
  ),
  SourceBibliographyItem(
    id: 'ojcha-nash-2022',
    title: 'Малітоўнік «Ойча наш» (Мінск, 2022)',
    notices: ['© Камісія Божага Культу і Дысцыпліны Сакрамэнтаў, 2022', '© Выдавецтва «Про Хрысто», 2022'],
  ),
  SourceBibliographyItem(
    id: 'prasitsee-i-atrymaetse-2024',
    title: 'Малітоўнік «Прасіце і атрымаеце» (Мінск, 2024).',
    notices: ['© Выдавецтва «Про Хрысто», 2024'],
  ),
  SourceBibliographyItem(
    id: 'bozha-my-tsiabe-uslavljajem-2026',
    title: 'Спеўнік «Божа, мы Цябе ўслаўляем» (Мінск, 2026)',
    notices: ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2026'],
  ),
];
