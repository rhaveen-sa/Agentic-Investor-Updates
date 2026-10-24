import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../agent/claude_client.dart';
import '../app_state.dart';
import '../models/fact.dart';
import '../models/outbound_message.dart';
import 'facts_screen.dart';
import 'feed_screen.dart';
import 'messages_screen.dart';
import 'report_screen.dart';
import 'settings_sheet.dart';
import 'sources_screen.dart';
import 'widgets/common.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    return Scaffold(
      backgroundColor: cs.background,
      body: Row(children: [
        const _Sidebar(),
        Expanded(
          child: Column(children: [
            const TopBar(),
            Expanded(
              child: IndexedStack(index: s.tab, children: const [
                FeedScreen(),
                FactsScreen(),
                SourcesScreen(),
                MessagesScreen(),
                ReportScreen(),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    final pending = s.facts.where((f) => f.status == FactStatus.pending).length;
    final open = s.outbox.where((m) => m.status == MessageStatus.draft || m.status == MessageStatus.sent).length;

    Widget item(int i, IconData icon, String label, {int count = 0}) {
      final selected = s.tab == i;
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => s.setTab(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? cs.border.withValues(alpha: 0.7) : Colors.transparent,
                borderRadius: BorderRadius.circular(rSm),
              ),
              child: Row(children: [
                Icon(icon, size: 17, color: cs.foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: tt.small.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                ),
                if (count > 0) Text('$count', style: tt.muted.copyWith(fontSize: 12.5)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 248,
      color: cs.muted.withValues(alpha: 0.6),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
              child: Icon(LucideIcons.sparkles, size: 15, color: cs.primaryForeground),
            ),
            const SizedBox(width: 10),
            Text('Shelfwise', style: tt.large.copyWith(fontSize: 15)),
          ]),
        ),
        const SizedBox(height: 24),
        item(0, LucideIcons.messageCircle, 'Agent'),
        item(1, LucideIcons.listChecks, 'Facts', count: pending),
        item(2, LucideIcons.plug, 'Sources'),
        item(3, LucideIcons.send, 'Messages', count: open),
        item(4, LucideIcons.fileText, 'Report'),
        const Spacer(),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => showSettings(context),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                ShadAvatar('', placeholder: const Text('L'), size: const Size(30, 30)),
                const SizedBox(width: 10),
                Expanded(child: Text('Lena', style: tt.small)),
                Icon(LucideIcons.settings2, size: 16, color: cs.mutedForeground),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    final live = !s.scripted && ClaudeClient().hasKey;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        if (s.busy != null) ...[
          const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6)),
          const SizedBox(width: 8),
          Text(s.busy!, style: tt.muted.copyWith(fontSize: 13)),
        ],
        const Spacer(),
        if (!live) ...[
          ShadTooltip(
            builder: (_) => const Text('No API key: runs are replayed from the mock data'),
            child: TintBadge('Scripted', cs.mutedForeground),
          ),
          const SizedBox(width: 8),
        ],
        ShadIconButton.ghost(
          enabled: !s.isBusy,
          width: 34,
          height: 34,
          iconSize: 16,
          icon: const Icon(LucideIcons.rotateCcw),
          onPressed: s.reset,
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: cs.border)),
          child: Row(children: [
            Text(DateFormat('EEE, MMM d').format(s.today), style: tt.small),
            const SizedBox(width: 10),
            ShadButton(
              size: ShadButtonSize.sm,
              enabled: s.canAdvance,
              decoration: ShadDecoration(border: ShadBorder.all(radius: BorderRadius.circular(999))),
              onPressed: s.advance,
              trailing: const Icon(LucideIcons.chevronRight, size: 15),
              child: Text(s.monthClosed ? 'Closed' : s.nextLabel),
            ),
          ]),
        ),
      ]),
    );
  }
}
