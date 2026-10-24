import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_state.dart';
import '../data/connectors.dart';
import 'widgets/common.dart';

class _Available {
  const _Available(this.name, {this.logo, this.icon});
  final String name;
  final String? logo;
  final IconData? icon;
}

const _available = [
  _Available('Granola', logo: 'assets/logos/granola.png'),
  _Available('Salesforce', logo: 'assets/logos/salesforce.png'),
  _Available('Linear', logo: 'assets/logos/linear.png'),
  _Available('Slack', logo: 'assets/logos/slack.png'),
  _Available('Google Analytics', logo: 'assets/logos/googleanalytics.png'),
  _Available('Instagram', logo: 'assets/logos/instagram.png'),
  _Available('Notion', logo: 'assets/logos/notion.png'),
  _Available('Any dashboard', icon: LucideIcons.monitor),
  _Available('Document or URL', icon: LucideIcons.filePlus),
];

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tt = context.tt;
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      const ScreenHeader('Sources'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 14, runSpacing: 14, children: [
            for (final id in s.connectors.keys) _ConnectedCard(sourceInfo(id)),
          ]),
          const SizedBox(height: 36),
          Text('Add more', style: tt.large),
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 14, children: [for (final a in _available) _AvailableCard(a)]),
        ]),
      ),
    ]);
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard(this.info);

  final SourceInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(rLg), border: Border.all(color: cs.border)),
      child: Row(children: [
        SourceLogo(info.id, size: 36),
        const SizedBox(width: 14),
        Expanded(child: Text(info.name, style: context.tt.large.copyWith(fontSize: 15))),
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: green, shape: BoxShape.circle)),
      ]),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard(this.a);

  final _Available a;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(rLg), border: Border.all(color: cs.border)),
      child: Row(children: [
        if (a.logo != null)
          Container(
            padding: EdgeInsets.all(isDark(context) ? 2 : 0),
            decoration: BoxDecoration(
              color: isDark(context) ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(a.logo!, width: isDark(context) ? 24 : 28, height: isDark(context) ? 24 : 28, filterQuality: FilterQuality.medium),
            ),
          )
        else
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(6)),
            child: Icon(a.icon, size: 16),
          ),
        const SizedBox(width: 12),
        Expanded(child: Text(a.name, style: context.tt.small)),
        ShadIconButton.ghost(
          width: 30,
          height: 30,
          iconSize: 16,
          icon: const Icon(LucideIcons.plus),
          onPressed: () => toast(context, '${a.name} is not part of the demo yet'),
        ),
      ]),
    );
  }
}
