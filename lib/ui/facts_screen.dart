import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_state.dart';
import '../models/fact.dart';
import 'widgets/common.dart';

/// Every fact the agent collected. The update is built only from confirmed ones.
class FactsScreen extends StatefulWidget {
  const FactsScreen({super.key});

  @override
  State<FactsScreen> createState() => _FactsScreenState();
}

class _FactsScreenState extends State<FactsScreen> {
  FactStatus? filter;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    final all = s.facts.reversed.toList();
    final shown =
        filter == null ? all.where((f) => f.status != FactStatus.dismissed).toList() : all.where((f) => f.status == filter).toList();
    final pending = s.facts.where((f) => f.status == FactStatus.pending).length;

    Widget tab(String label, FactStatus? value) {
      final selected = filter == value;
      return GestureDetector(
        onTap: () => setState(() => filter = value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? cs.background : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : null,
            ),
            child: Text(label, style: tt.small.copyWith(color: selected ? cs.foreground : cs.mutedForeground)),
          ),
        ),
      );
    }

    final head = tt.muted.copyWith(fontSize: 12.5);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ScreenHeader(
        'Facts',
        trailing: pending > 0
            ? ShadButton(
                onPressed: () => s.confirmAll(s.facts.map((f) => f.id)),
                leading: const Icon(LucideIcons.checkCheck, size: 16),
                child: Text('Confirm $pending'),
              )
            : null,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            tab('All', null),
            tab('Pending', FactStatus.pending),
            tab('Confirmed', FactStatus.confirmed),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 36, 32),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(rLg)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.border))),
                child: Row(children: [
                  Expanded(child: Text('Fact', style: head)),
                  SizedBox(width: 130, child: Text('Source', style: head)),
                  SizedBox(width: 70, child: Text('Date', style: head)),
                  SizedBox(width: 90, child: Text('Status', style: head)),
                ]),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const EmptyState(icon: LucideIcons.listChecks, title: 'No facts yet')
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: cs.border),
                        itemBuilder: (_, i) => _Row(shown[i]),
                      ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _Row extends StatefulWidget {
  const _Row(this.f);

  final Fact f;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final cs = context.cs;
    final cell = context.tt.p.copyWith(fontSize: 14);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: () => showFactSources(context, [f.id]),
        child: Container(
          color: hover ? cs.muted.withValues(alpha: 0.5) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(f.text, style: cell),
                if (f.statementOnly) const SaidTag(),
              ]),
            ),
            SizedBox(width: 130, child: Align(alignment: Alignment.centerLeft, child: SourceBadge(f.sourceId))),
            SizedBox(width: 70, child: Text(shortDate.format(f.date), style: cell.copyWith(color: cs.mutedForeground))),
            SizedBox(width: 90, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(f.status))),
          ]),
        ),
      ),
    );
  }
}
