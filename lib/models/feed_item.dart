import 'agent_run.dart';

enum FeedType { welcome, checkIn, approval, inbound, report, info, error }

class FeedItem {
  FeedItem({
    required this.type,
    required this.title,
    required this.date,
    this.body,
    this.run,
    this.userText,
  });

  final FeedType type;
  final String title;
  final DateTime date;
  String? body;
  final AgentRun? run;

  /// What the founder sent (for inbound items).
  final String? userText;

  /// For month-close check-ins: show the "Draft report" action.
  bool offersReport = false;
}
