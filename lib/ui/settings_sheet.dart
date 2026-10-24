import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../agent/claude_client.dart';
import '../app_state.dart';
import 'widgets/common.dart';

Future<void> showSettings(BuildContext context) =>
    showShadSheet(side: ShadSheetSide.right, context: context, builder: (_) => const _SettingsSheet());

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tt = context.tt;
    final hasKey = ClaudeClient().hasKey;

    Widget label(String t, [String? sub]) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: tt.small),
            if (sub != null) Text(sub, style: tt.muted.copyWith(fontSize: 12.5)),
          ]),
        );

    Widget segmented(List<String> options, String value, void Function(String) onChanged) => Row(children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: o == value
                  ? ShadButton(size: ShadButtonSize.sm, onPressed: () {}, child: Text(o))
                  : ShadButton.outline(size: ShadButtonSize.sm, onPressed: () => onChanged(o), child: Text(o)),
            ),
        ]);

    Widget switchRow(String title, bool value, ValueChanged<bool>? onChanged, {String? sub}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tt.small.copyWith(fontWeight: FontWeight.w500)),
                if (sub != null) Text(sub, style: tt.muted.copyWith(fontSize: 12.5)),
              ]),
            ),
            ShadSwitch(value: value, onChanged: onChanged, enabled: onChanged != null),
          ]),
        );

    return ShadSheet(
      constraints: const BoxConstraints(maxWidth: 440, minWidth: 440),
      title: const Text('Settings'),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label('Check-in cadence'),
          segmented(['Weekly', 'Every 2 weeks'], s.cadence, (v) {
            s.cadence = v;
            s.touch();
          }),
          label('Reporting period'),
          segmented(['Monthly', 'Quarterly'], s.period, (v) {
            s.period = v;
            s.touch();
          }),
          label('KPIs'),
          for (final e in kpiCatalog.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: ShadCheckbox(
                value: s.kpis.contains(e.key),
                label: Text(e.value),
                onChanged: (on) {
                  on ? s.kpis.add(e.key) : s.kpis.remove(e.key);
                  s.touch();
                },
              ),
            ),
          label('Channels'),
          for (final c in s.channels.keys)
            switchRow(c, s.channels[c]!, (v) {
              s.channels[c] = v;
              s.touch();
            }),
          label('Agent'),
          switchRow(
            'Scripted mode',
            s.scripted,
            hasKey
                ? (v) {
                    s.scripted = v;
                    s.touch();
                  }
                : null,
          ),
        ]),
      ),
    );
  }
}
