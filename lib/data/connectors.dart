import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Display metadata for every place a fact can come from.
class SourceInfo {
  const SourceInfo(this.id, this.name, this.category, this.icon, this.color, {this.logo});

  final String id;
  final String? logo;
  final String name;
  final String category;
  final IconData icon;
  final Color color;
}

const sourceInfos = <String, SourceInfo>{
  'github': SourceInfo('github', 'GitHub', 'Product', Icons.code, Color(0xFF24292F), logo: 'assets/logos/github.png'),
  'jamie': SourceInfo('jamie', 'Jamie', 'Meetings', Icons.mic_none, Color(0xFF7C4DFF), logo: 'assets/logos/jamie.png'),
  'hubspot': SourceInfo('hubspot', 'HubSpot', 'CRM', Icons.handshake_outlined, Color(0xFFFF7A59), logo: 'assets/logos/hubspot.png'),
  'linkedin': SourceInfo('linkedin', 'LinkedIn', 'Growth', Icons.campaign_outlined, Color(0xFF0A66C2), logo: 'assets/logos/linkedin.png'),
  'stripe': SourceInfo('stripe', 'Stripe', 'Finance', Icons.account_balance_outlined, Color(0xFF635BFF), logo: 'assets/logos/stripe.png'),
  'packages': SourceInfo('packages', 'PyPI · npm', 'Developer adoption', Icons.download_outlined, Color(0xFF3775A9),
      logo: 'assets/logos/npm.png'),
  'founder': SourceInfo('founder', 'Chat', 'Founder input', Icons.person_outline, Color(0xFF2E7D32)),
  'voice': SourceInfo('voice', 'Voice', 'Founder input', Icons.graphic_eq, Color(0xFF2E7D32)),
  'document': SourceInfo('document', 'Document', 'Founder input', Icons.description_outlined, Color(0xFF5D4037)),
  'slack': SourceInfo('slack', 'Slack', 'Team reply', Icons.forum_outlined, Color(0xFF4A154B), logo: 'assets/logos/slack.png'),
};

SourceInfo sourceInfo(String id) =>
    sourceInfos[id] ?? SourceInfo(id, id, 'Other', Icons.link, Colors.blueGrey);

class SourceItem {
  SourceItem(this.sourceId, this.json);

  final String sourceId;
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  DateTime get ts => DateTime.parse(json['ts'] as String);
  String get title => json['title'] as String;
  String get body => json['body'] as String? ?? '';
  List<Map<String, dynamic>> get hintedFacts =>
      ((json['facts'] as List?) ?? const []).cast<Map<String, dynamic>>();

  /// What the agent sees: the raw record without our scripted-mode hints.
  Map<String, dynamic> toAgentJson() => {
        'id': id,
        'ts': json['ts'],
        'type': json['type'],
        'title': title,
        'body': body,
        if (json['data'] != null) 'data': json['data'],
      };
}

/// Shared interface: a real connector (OAuth, webhook, Computer Use) replaces
/// a mock without touching the agent.
abstract class SourceConnector {
  String get id;
  Future<List<SourceItem>> fetch(DateTime since, DateTime until);
}

class MockConnector implements SourceConnector {
  MockConnector(this.id);

  @override
  final String id;
  List<SourceItem>? _items;

  Future<List<SourceItem>> _load() async {
    if (_items != null) return _items!;
    final raw = jsonDecode(await rootBundle.loadString('assets/mock/$id.json'));
    _items = [for (final i in raw['items'] as List) SourceItem(id, i as Map<String, dynamic>)];
    return _items!;
  }

  /// Items with since < ts <= until.
  @override
  Future<List<SourceItem>> fetch(DateTime since, DateTime until) async {
    final items = await _load();
    return items.where((i) => i.ts.isAfter(since) && !i.ts.isAfter(until)).toList();
  }

  Future<SourceItem?> byId(String itemId) async {
    final items = await _load();
    for (final i in items) {
      if (i.id == itemId) return i;
    }
    return null;
  }
}

class Teammate {
  const Teammate(this.name, this.role, this.owns, this.channels);

  final String name;
  final String role;
  final List<String> owns;
  final Map<String, String> channels;

  Map<String, dynamic> toJson() => {'name': name, 'role': role, 'owns': owns, 'channels': channels};
}

const teamDirectory = [
  Teammate('Thomas', 'CEO & co-founder', ['sales', 'CRM (HubSpot)', 'finance (Stripe, bank)', 'investor relations'],
      {'slack': '@thomas', 'email': 'thomas@reson8.dev'}),
  Teammate('Jarno', 'CTO & co-founder',
      ['product', 'engineering', 'GitHub', 'SDK downloads (PyPI, npm)', 'model training', 'uptime', 'hiring engineers'],
      {'slack': '@jarno', 'whatsapp': '+31 6 0000 0001', 'email': 'jarno@reson8.dev'}),
  Teammate('Mirte', 'Head of Growth', ['marketing', 'LinkedIn ads & posts', 'website analytics', 'demo bookings'],
      {'slack': '@mirte', 'whatsapp': '+31 6 0000 0002', 'email': 'mirte@reson8.dev'}),
];
