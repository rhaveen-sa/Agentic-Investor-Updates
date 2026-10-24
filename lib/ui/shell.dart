import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../app_state.dart';
import '../models/fact.dart';
import 'facts_screen.dart';
import 'feed_screen.dart';
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
      padding: const EdgeInsets.fromLTRB(12, 56, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item(0, LucideIcons.messageCircle, 'Agent'),
        item(1, LucideIcons.listChecks, 'Facts', count: pending),
        item(2, LucideIcons.plug, 'Sources'),
        item(3, LucideIcons.fileText, 'Report'),
        const Spacer(),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => showSettings(context),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                ClipOval(child: Image.asset('assets/logos/reson8.png', width: 30, height: 30, filterQuality: FilterQuality.medium)),
                const SizedBox(width: 10),
                Expanded(child: Text('Reson8', style: tt.small)),
                Icon(LucideIcons.settings, size: 17, color: cs.mutedForeground),
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
    final tt = context.tt;
    final bar = SizedBox(
      height: 60,
      child: Stack(alignment: Alignment.center, children: [
        if (s.busy != null)
          Positioned(
            left: 20,
            child: Row(children: [
              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6)),
              const SizedBox(width: 8),
              Text(s.busy!, style: tt.muted.copyWith(fontSize: 13)),
            ]),
          ),
        if (s.tab == 0) const WeekStepper(),
      ]),
    );
    return kIsWeb ? bar : DragToMoveArea(child: bar);
  }
}

/// The four simulated weeks of October. Any week can be opened; check-ins
/// are started from the card in the chat.
class WeekStepper extends StatelessWidget {
  const WeekStepper({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;

    Widget week(int i) {
      final done = s.ranWeeks.contains(i);
      final viewed = i == s.viewWeek;
      final child = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: viewed ? cs.background : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: viewed ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (done) ...[
            Icon(LucideIcons.check, size: 13, color: viewed ? cs.foreground : cs.mutedForeground),
            const SizedBox(width: 5),
          ],
          Text(shortDate.format(simWeeks[i].until),
              style: tt.small.copyWith(
                fontWeight: viewed ? FontWeight.w600 : FontWeight.w500,
                color: viewed ? cs.foreground : cs.mutedForeground,
              )),
        ]),
      );
      return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: () => s.selectWeek(i), child: child));
    }

    final allRan = [0, 1, 2, 3].every(s.ranWeeks.contains);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 4; i++) week(i),
        if (allRan) ...[const SizedBox(width: 4), const _ReportButton()],
      ]),
    );
  }
}

/// Round button at the end of the week stepper once all four weeks have run: opens or creates the
/// report, or leads to the open questions first.
class _ReportButton extends StatefulWidget {
  const _ReportButton();

  @override
  State<_ReportButton> createState() => _ReportButtonState();
}

class _ReportButtonState extends State<_ReportButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final enabled = !s.isBusy;
    final tip = s.report != null
        ? 'Open the report'
        : s.hasOpenQuestions
            ? 'Answer open questions first'
            : 'Create the report';
    return ShadTooltip(
      builder: (_) => Text(tip),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: enabled ? s.openOrCreateReport : null,
          // Same height as a week segment (7px padding around a 13-14px label).
          child: SizedBox.square(
            dimension: 33,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: !enabled ? 0.4 : (_hover ? 0.82 : 1)),
              ),
              child: Icon(LucideIcons.fileText, size: 15, color: cs.primaryForeground),
            ),
          ),
        ),
      ),
    );
  }
}
