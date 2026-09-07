/// The three categories a user can file feedback under, shown in the
/// Feedback & Help screen's Type dropdown and sent verbatim (via [label])
/// as the `type` field of the Web3Forms submission.
enum FeedbackType {
  bugReport,
  featureRequest,
  generalComment;

  String get label => switch (this) {
    FeedbackType.bugReport => 'Bug report',
    FeedbackType.featureRequest => 'Feature request',
    FeedbackType.generalComment => 'General comment',
  };
}
