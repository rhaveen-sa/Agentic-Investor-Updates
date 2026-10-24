enum MessageStatus { draft, sent, replied, rejected }

class OutboundMessage {
  OutboundMessage({
    required this.id,
    required this.to,
    required this.channel,
    required this.text,
    required this.createdAt,
    this.reason,
  });

  final String id;
  final String to;
  final String channel;
  String text;
  final DateTime createdAt;

  /// Why the agent wants to send this (shown on the approval card).
  final String? reason;
  MessageStatus status = MessageStatus.draft;
  String? reply;
  DateTime? sentAt;
}
