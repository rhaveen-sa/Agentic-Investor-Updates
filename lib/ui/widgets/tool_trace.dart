import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/agent_run.dart';
import 'common.dart';

/// Collapsed "Used N tools" line, like the tool/thinking disclosure in
/// frontier-lab chat apps. Expands to one row per model and tool call.
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
    final label = run.done ? 'Used ${run.toolCalls} tools' : _runningLabel(run);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!run.done) ...[
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
                const SizedBox(width: 8),
              ],
              Text(label, style: tt.muted.copyWith(fontSize: 13)),
              const SizedBox(width: 4),
              Icon(open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 14, color: cs.mutedForeground),
            ]),
          ),
        ),
      ),
      if (open)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6, bottom: 4),
          decoration: BoxDecoration(
            color: cs.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(rMd),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [for (final s in run.steps) _StepRow(s)]),
        ),
    ]);
  }

  String _runningLabel(AgentRun run) {
    final last = run.steps.isEmpty ? null : run.steps.last;
    if (last == null || last.type == StepType.model) return 'Thinking…';
    return switch (last.name) {
      'fetch_source' => 'Reading ${(last.input as Map?)?['source'] ?? 'sources'}…',
      'ledger_search' => 'Checking known facts…',
      'ledger_propose' => 'Writing down facts…',
      'team_directory' => 'Looking up the owner…',
      'message_teammate' => 'Drafting a message…',
      'submit_report' => 'Writing the update…',
      'verify_claims' => 'Verifying every claim…',
      _ => 'Working…',
    };
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);

  final RunStep step;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final isModel = step.type == StepType.model;
    final mono = TextStyle(fontFamily: 'Menlo', fontSize: 11.5, color: cs.mutedForeground, height: 1.4);
    final input = step.inputPretty.replaceAll('\n', ' ');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showShadDialog(
          context: context,
          builder: (ctx) => ShadDialog(
            title: Text(step.name),
            radius: BorderRadius.circular(rLg),
            child: SizedBox(
              width: 640,
              height: 420,
              child: SingleChildScrollView(
                child: SelectableText('INPUT\n${step.inputPretty}\n\nOUTPUT\n${step.outputPretty}',
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 12)),
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Row(children: [
            Icon(isModel ? LucideIcons.sparkles : LucideIcons.wrench, size: 12, color: cs.mutedForeground),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: Text(step.name, style: mono.copyWith(color: cs.foreground, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(input, style: mono, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }
}
