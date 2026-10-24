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
    this.author,
  });

  final FeedType type;
  String title;
  final DateTime date;
  String? body;
  final AgentRun? run;

  /// What the founder sent (for inbound items).
  final String? userText;

  /// Set when [userText] came from a teammate instead of the founder.
  final String? author;

  /// Which October week (0-3) this belongs to; set when added to the feed.
  int week = 0;

  /// For month-close check-ins: show the "Draft report" action.
  bool offersReport = false;
}
