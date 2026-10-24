import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../agent/claude_client.dart';
import '../app_state.dart';
import 'widgets/common.dart';

Future<void> showSettings(BuildContext context) => showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => const _SettingsDialog(),
    );

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  int section = 0;

  static const _sections = [
    (LucideIcons.sunMoon, 'Appearance'),
    (LucideIcons.calendarClock, 'Schedule'),
    (LucideIcons.chartColumn, 'KPIs'),
    (LucideIcons.messagesSquare, 'Channels'),
    (LucideIcons.bot, 'Agent'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    return Dialog(
      backgroundColor: cs.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 820,
        height: 560,
        child: Row(children: [
          Container(
            width: 220,
            color: cs.muted.withValues(alpha: 0.6),
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 0, 22),
                child: Text('Settings', style: tt.large.copyWith(fontSize: 17)),
              ),
              for (var i = 0; i < _sections.length; i++) _navItem(i),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 24, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_sections[section].$2, style: tt.h4)),
                  ShadIconButton.ghost(
                    width: 32,
                    height: 32,
                    iconSize: 16,
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 8),
                Expanded(child: SingleChildScrollView(child: _content())),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _navItem(int i) {
    final cs = context.cs;
    final selected = section == i;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => section = i),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? cs.border.withValues(alpha: 0.7) : Colors.transparent,
            borderRadius: BorderRadius.circular(rSm),
          ),
          child: Row(children: [
            Icon(_sections[i].$1, size: 16),
            const SizedBox(width: 10),
            Text(_sections[i].$2, style: context.tt.small.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  Widget _content() {
    final s = context.watch<AppState>();
    return switch (section) {
      0 => Column(children: [
          _Row(
            title: 'Theme',
            trailing: _Segmented(const ['System', 'Light', 'Dark'], switch (s.themeMode) {
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
              _ => 'System',
            }, (v) {
              s.themeMode = switch (v) {
                'Light' => ThemeMode.light,
                'Dark' => ThemeMode.dark,
                _ => ThemeMode.system,
              };
              s.touch();
            }),
          ),
        ]),
      1 => Column(children: [
          _Row(
            title: 'Check-in every',
            trailing: _Segmented(['3 days', 'Week', '2 weeks'], s.cadence, (v) {
              s.cadence = v;
              s.touch();
            }),
          ),
          _Row(
            title: 'Investor update',
            trailing: _Segmented(['Monthly', 'Quarterly'], s.period, (v) {
              s.period = v;
              s.touch();
            }),
          ),
        ]),
      2 => Column(children: [
          for (final e in kpiCatalog.entries)
            _Row(
              title: e.value,
              trailing: ShadSwitch(
                value: s.kpis.contains(e.key),
                onChanged: (on) {
                  on ? s.kpis.add(e.key) : s.kpis.remove(e.key);
                  s.touch();
                },
              ),
            ),
        ]),
      3 => Column(children: [
          for (final c in s.channels.keys)
            _Row(
              title: c,
              trailing: ShadSwitch(
                value: s.channels[c]!,
                onChanged: (v) {
                  s.channels[c] = v;
                  s.touch();
                },
              ),
            ),
        ]),
      _ => Column(children: [
          _Row(title: 'Model', trailing: Text(claudeModel, style: context.tt.muted.copyWith(fontSize: 14))),
          _Row(
            title: 'Scripted mode',
            trailing: ShadSwitch(
              value: s.scripted,
              enabled: ClaudeClient().hasKey,
              onChanged: (v) {
                s.scripted = v;
                s.touch();
              },
            ),
          ),
          _Row(
            title: 'Reset demo',
            trailing: ShadButton.outline(
              size: ShadButtonSize.sm,
              enabled: !s.isBusy,
              onPressed: () {
                s.reset();
                Navigator.pop(context);
              },
              child: const Text('Reset'),
            ),
          ),
        ]),
    };
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.cs.border.withValues(alpha: 0.7)))),
        child: Row(children: [
          Expanded(child: Text(title, style: context.tt.p.copyWith(fontSize: 14.5))),
          trailing,
        ]),
      );
}

class _Segmented extends StatelessWidget {
  const _Segmented(this.options, this.value, this.onChanged);

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final o in options)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onChanged(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: o == value ? cs.background : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: o == value ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : null,
                ),
                child: Text(o,
                    style: context.tt.small.copyWith(color: o == value ? cs.foreground : cs.mutedForeground, fontSize: 13)),
              ),
            ),
          ),
      ]),
    );
  }
}
