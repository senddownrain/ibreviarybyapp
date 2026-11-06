const kMyBrevWebBaseUrl = 'https://ibreviaryby.web.app';

/// Canonical public privacy document shared by MyBrev Web, Android and iOS.
/// Firebase Hosting serves standalone HTML here without application scripts.
/// Verify the public URL after the web Hosting deployment, before Play review.
const kPrivacyPolicyUrl = '$kMyBrevWebBaseUrl/privacy';

const kLiturgyHoursDecreesUrl =
    '$kMyBrevWebBaseUrl/documents/liturgy-hours-decrees';
const kLiturgyHoursIntroductionUrl =
    '$kMyBrevWebBaseUrl/documents/liturgy-hours-introduction';
const kProperCalendarUrl = '$kMyBrevWebBaseUrl/documents/proper-calendar';

/// The current official documents live on Web, outside the mobile asset bundle.
const kSourceDocumentLinks = [
  (label: 'Дэкрэты Літургіі гадзінаў', url: kLiturgyHoursDecreesUrl),
  (
    label: 'Агульныя ўводзіны да Літургіі гадзінаў',
    url: kLiturgyHoursIntroductionUrl,
  ),
  (label: 'Уласны каляндар дыяцэзій на Беларусі', url: kProperCalendarUrl),
];
