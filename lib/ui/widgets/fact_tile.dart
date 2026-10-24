import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app_state.dart';
import '../../models/fact.dart';
import 'common.dart';

/// One proposed fact with Confirm / Edit / Dismiss.
class FactTile extends StatelessWidget {
  const FactTile(this.fact, {super.key});

  final Fact fact;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    final f = fact;
    final dismissed = f.status == FactStatus.dismissed;
    final confirmed = f.status == FactStatus.confirmed;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dismissed ? 0.4 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          ShadTooltip(
            builder: (_) => Text('${f.owner} · ${shortDate.format(f.date)}'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => showFactSources(context, [f.id]),
                child: SourceLogo(f.sourceId, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(f.text,
                  style: tt.p.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    decoration: dismissed ? TextDecoration.lineThrough : null,
                  )),
              if (f.statementOnly) const SaidTag(),
            ]),
          ),
          const SizedBox(width: 8),
          if (f.status == FactStatus.pending) ...[
            ShadIconButton.ghost(
              width: 30,
              height: 30,
              iconSize: 15,
              icon: const Icon(LucideIcons.pencil),
              onPressed: () => editFactDialog(context, f),
            ),
            const SizedBox(width: 4),
            ShadIconButton.outline(
              width: 30,
              height: 30,
              iconSize: 15,
              icon: const Icon(LucideIcons.x),
              onPressed: () => s.setFactStatus(f.id, FactStatus.dismissed),
            ),
            const SizedBox(width: 4),
            ShadIconButton.outline(
              width: 30,
              height: 30,
              iconSize: 15,
              icon: const Icon(LucideIcons.check),
              onPressed: () => s.setFactStatus(f.id, FactStatus.confirmed),
            ),
          ] else
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => s.setFactStatus(f.id, FactStatus.pending),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(confirmed ? LucideIcons.circleCheck : LucideIcons.circleSlash,
                      size: 17, color: confirmed ? green : cs.mutedForeground),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Facts grouped in one rounded box with dividers.
class FactList extends StatelessWidget {
  const FactList(this.facts, {super.key});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      decoration: BoxDecoration(
        color: cs.background,
        borderRadius: BorderRadius.circular(rMd),
        border: Border.all(color: cs.border),
      ),
      child: Column(children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) Divider(height: 1, color: cs.border),
          FactTile(facts[i]),
        ],
      ]),
    );
  }
}

Future<void> editFactDialog(BuildContext context, Fact f) async {
  final s = context.read<AppState>();
  final text = TextEditingController(text: f.text);
  final value = TextEditingController(text: f.value == null ? '' : f.value!.toStringAsFixed(f.value! % 1 == 0 ? 0 : 1));
  final ok = await showShadDialog<bool>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: const Text('Edit fact'),
      radius: BorderRadius.circular(rLg),
      actions: [
        ShadButton.outline(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ShadButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
      child: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          ShadInput(controller: text, maxLines: 3, minLines: 2),
          if (f.value != null) ...[
            const SizedBox(height: 10),
            ShadInput(controller: value, placeholder: Text('Value (${f.unit ?? ''})')),
          ],
        ]),
      ),
    ),
  );
  if (ok == true) s.editFact(f.id, text.text.trim(), double.tryParse(value.text.trim()));
}
