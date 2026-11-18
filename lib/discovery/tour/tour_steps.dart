import 'package:flutter/foundation.dart' show immutable;
import 'package:mybrev_flutter/navigation/app_navigation.dart';

/// How a step finds the real control it points at. A step lists several
/// matchers; the first one that is mounted and on screen wins.
@immutable
class TourAnchor {
  const TourAnchor.exact(String key) : matches = null, exactKey = key;

  const TourAnchor.suffix(String suffix) : exactKey = null, matches = suffix;

  final String? exactKey;
  final String? matches;

  bool test(String key) =>
      exactKey != null ? key == exactKey : key.endsWith(matches!);
}

/// One stop of the product tour.
@immutable
class TourStep {
  const TourStep({
    required this.id,
    required this.titleBe,
    required this.bodyBe,
    required this.anchors,
    this.branch,
    this.unionAll = false,
    this.spotlightPadding = 6,
  });

  /// Stable identifier, for tests and logs.
  final String id;
  final String titleBe;
  final String bodyBe;

  /// Tried in order.
  final List<TourAnchor> anchors;

  /// Section the step needs. Null means "wherever the person is".
  final AppBranch? branch;

  /// Highlight every matching anchor together (two dock tabs).
  final bool unionAll;

  /// Space between the anchor and the spotlight outline, in logical pixels.
  final double spotlightPadding;
}

/// The tour of Stage 6. A step whose control is not on screen is dropped at
/// run time, so the list never forces navigation that would lose a place.
const List<TourStep> defaultTourSteps = [
  TourStep(
    id: 'tour.sections',
    titleBe: 'Раздзелы дадатку',
    bodyBe:
        'Унізе пераключаюцца Літургія, Чытанні, Малітоўнік і Біблія. '
        'Ваша месца ў кожным раздзеле застаецца.',
    anchors: [
      TourAnchor.exact('app-dock-full'),
      TourAnchor.exact('app-dock-compact'),
    ],
  ),
  TourStep(
    id: 'tour.date',
    titleBe: 'Дата і літургічны каляндар',
    bodyBe:
        'Тут адкрываецца літургічны дзень і каляндар. '
        'Тур нічога не мяняе ў выбранай даце.',
    anchors: [TourAnchor.exact('hours-calendar-action')],
    branch: AppBranch.hours,
  ),
  TourStep(
    id: 'tour.text',
    titleBe: 'Памер тэксту і псалмы',
    bodyBe:
        'У меню «···» можна змяніць памер тэксту, паказ псалмоў '
        'і адкрыць налады.',
    anchors: [TourAnchor.exact('app-overflow-open')],
    branch: AppBranch.hours,
  ),
  TourStep(
    id: 'tour.variants',
    titleBe: 'Варыянты дня і цыклы',
    bodyBe:
        'Націсніце на ўвесь блок літургічнага дня з алоўкам, '
        'каб выбраць іншы даступны варыянт. '
        'Іншы цыкл чытанняў (A, B, C) можна толькі паглядзець, '
        'ён не мяняе вашу Імшу.',
    // Only highlight the real tappable area. When the selector is not
    // available, the tour must not point at an inactive title.
    anchors: [TourAnchor.suffix('-alternatives-control')],
    spotlightPadding: 0,
    branch: AppBranch.readings,
  ),
  TourStep(
    id: 'tour.library',
    titleBe: 'Біблія і Малітоўнік',
    bodyBe:
        'Малітвы, песні і Біблія — у асобных раздзелах унізе. '
        'Пошук ёсць у кожным з іх.',
    anchors: [
      TourAnchor.exact('app-destination-Малітоўнік'),
      TourAnchor.exact('app-destination-Біблія'),
    ],
    unionAll: true,
  ),
  TourStep(
    id: 'tour.again',
    titleBe: 'Падказкі і паўтор туру',
    bodyBe:
        'У меню «···» → «Налады» можна ўключыць ці выключыць падказкі '
        'і паўтарыць гэты тур: «Як карыстацца дадаткам».',
    anchors: [TourAnchor.exact('app-overflow-open')],
  ),
];

/// A run of the tour. Pure: steps without a control are removed, so the
/// progress is always «N з M» over steps the person can really see.
class TourSession {
  TourSession(Iterable<TourStep> steps) : _steps = [...steps];

  final List<TourStep> _steps;
  int _index = 0;

  int get total => _steps.length;
  int get index => _index;
  bool get isEmpty => _steps.isEmpty;
  bool get isFirst => _index == 0;
  bool get isLast => _index >= _steps.length - 1;
  TourStep get current => _steps[_index];
  String get progressBe => '${_index + 1} з ${_steps.length}';

  /// Moves on; false when [current] was the last step.
  bool next() {
    if (isLast) return false;
    _index++;
    return true;
  }

  /// Moves back; false at the first step.
  bool back() {
    if (isFirst) return false;
    _index--;
    return true;
  }

  /// Drops the current step (its control is missing). After the removal
  /// [current] is the step that followed it, or the previous one when
  /// [forward] is false. Returns false when no step is left that way.
  bool dropCurrent({required bool forward}) {
    _steps.removeAt(_index);
    if (_steps.isEmpty) return false;
    if (forward) {
      if (_index >= _steps.length) {
        _index = _steps.length - 1;
        return false;
      }
      return true;
    }
    if (_index == 0) return _steps.isNotEmpty;
    _index--;
    return true;
  }
}
