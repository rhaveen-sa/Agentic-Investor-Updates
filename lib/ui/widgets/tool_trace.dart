import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app_state.dart';
import '../../data/connectors.dart';
import '../../models/agent_run.dart';
import 'common.dart';
import 'shimmer_text.dart';

/// Collapsed "Used N tools" line, like the tool disclosure in frontier-lab
/// chat apps. Expands to one plain-language row per step.
class ToolTrace extends StatefulWidget {
  const ToolTrace(this.run, {super.key});

  final AgentRun run;

  @override
  State<ToolTrace> createState() => _ToolTraceState();
}

class _ToolTraceState extends State<ToolTrace> {
  late bool open = !widget.run.done;
  bool _wasDone = false;

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    // Collapse automatically when the run finishes.
    if (run.done && !_wasDone) {
      _wasDone = true;
      open = false;
    }
    final cs = context.cs;
    final tt = context.tt;
    final steps = [for (final s in run.steps) ?describeStep(s)];
    final last = run.steps.isEmpty ? null : run.steps.last;
    // The model is working when the run is live and the last step is a model call.
    final thinking = !run.done && (last == null || last.type == StepType.model);
    final label = run.done ? 'Used ${run.toolCalls} tools' : (thinking || steps.isEmpty ? 'Thinking' : steps.last.label);
    final labelStyle = tt.muted.copyWith(fontSize: 13);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              run.done ? Text(label, style: labelStyle) : ShimmerText(label, style: labelStyle),
              const SizedBox(width: 4),
              Icon(open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 14, color: cs.mutedForeground),
            ]),
          ),
        ),
      ),
      if (open && (steps.isNotEmpty || thinking))
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6, left: 2),
          child: Column(children: [
            for (final s in steps) _StepRow(s),
            if (thinking)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  const SizedBox(width: 26),
                  ShimmerText('Thinking', style: tt.small.copyWith(fontWeight: FontWeight.w400, fontSize: 13.5)),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

class StepView {
  const StepView(this.label, {this.icon, this.sourceId, this.warning = false});

  final String label;
  final IconData? icon;
  final String? sourceId;
  final bool warning;
}

/// Plain-language description of a step, or null for internal steps.
StepView? describeStep(RunStep s) {
  final input = s.input is Map ? (s.input as Map).cast<String, dynamic>() : const <String, dynamic>{};
  if (s.type == StepType.model) {
    if (s.name == 'fallback') return const StepView('Live run failed, finished with the backup run', icon: LucideIcons.triangleAlert, warning: true);
    if (s.name == 'verifier') return const StepView('Handing the draft to a separate verifier', icon: LucideIcons.shieldCheck);
    // Model turns show as a shimmering "Thinking" row while they run, not as list rows.
    return null;
  }
  return switch (s.name) {
    'list_sources' => const StepView('Listing connected sources', icon: LucideIcons.plug),
    'fetch_source' => StepView(
        'Looking up ${sourceInfo('${input['source']}').name} data for ${_period('${input['until']}')}',
        sourceId: '${input['source']}',
      ),
    'ledger_search' => const StepView('Checking what is already known', icon: LucideIcons.search),
    'ledger_propose' => const StepView('Writing down a fact', icon: LucideIcons.listPlus),
    'suggest_kpi' => StepView('Suggesting ${kpiCatalog[input['metric']] ?? 'a KPI'} as a new KPI', icon: LucideIcons.chartColumn),
    'team_directory' => const StepView('Looking up who owns this', icon: LucideIcons.users),
    'ask_founder' => const StepView('Asking you a question', icon: LucideIcons.messageCircleQuestion),
    'message_teammate' => StepView('Drafting a message to ${input['person'] ?? 'a teammate'}', icon: LucideIcons.send),
    'submit_report' => const StepView('Writing the investor update', icon: LucideIcons.fileText),
    'verify_claims' => const StepView('Checking every claim against its source', icon: LucideIcons.shieldCheck),
    _ => const StepView('Working', icon: LucideIcons.wrench),
  };
}

/// "October week 2" for a date that ends one of the simulated weeks.
String _period(String until) {
  final d = DateTime.tryParse(until.length >= 10 ? until.substring(0, 10) : until);
  if (d == null) return 'this period';
  for (var i = 0; i < simWeeks.length; i++) {
    final w = simWeeks[i].until;
    if (w.year == d.year && w.month == d.month && w.day == d.day) {
      return i < 4 ? 'October week ${i + 1}' : 'the end of October';
    }
  }
  return 'this period';
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);

  final StepView step;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final color = step.warning ? amber : cs.mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(
          width: 16,
          child: step.sourceId != null ? SourceLogo(step.sourceId!, size: 14) : Icon(step.icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(step.label, style: context.tt.small.copyWith(fontWeight: FontWeight.w400, fontSize: 13.5, color: step.warning ? amber : cs.foreground)),
        ),
      ]),
    );
  }
}
