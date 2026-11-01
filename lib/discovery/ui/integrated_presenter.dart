import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/ui/coachmark.dart';
import 'package:mybrev_flutter/discovery/ui/inline_hint_presenter.dart';

/// Integration glue (stage 3 inline slots + stage 4 coachmarks): a hint goes
/// to the inline slot when its anchor has one, otherwise to the coachmark.
class IntegratedHintPresenter implements HintPresenter {
  IntegratedHintPresenter(this.inline, this.coach);
  final InlineHintPresenter inline;
  final CoachmarkPresenter coach;

  @override
  Future<bool> present(HintDefinition hint) {
    if (inline.mountedAnchors.contains(hint.anchorId)) {
      coach.dismiss();
      return inline.present(hint);
    }
    inline.dismiss();
    return coach.present(hint);
  }

  @override
  void dismiss() {
    inline.dismiss();
    coach.dismiss();
  }
}

InlineHintPresenter? inlineOf(HintPresenter p) => p is IntegratedHintPresenter
    ? p.inline
    : (p is InlineHintPresenter ? p : null);

CoachmarkPresenter? coachOf(HintPresenter p) => p is IntegratedHintPresenter
    ? p.coach
    : (p is CoachmarkPresenter ? p : null);
