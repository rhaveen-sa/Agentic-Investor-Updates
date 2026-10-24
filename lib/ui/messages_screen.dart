import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_state.dart';
import '../models/outbound_message.dart';
import 'feed_screen.dart';
import 'widgets/common.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    final msgs = s.outbox.reversed.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ScreenHeader('Messages'),
      Expanded(
        child: msgs.isEmpty
            ? const EmptyState(icon: LucideIcons.messagesSquare, title: 'No messages yet')
            : ListView(
                padding: const EdgeInsets.fromLTRB(36, 0, 36, 32),
                children: [
                  for (final m in msgs)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 760),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(rLg), border: Border.all(color: cs.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const SourceLogo('slack', size: 22),
                            const SizedBox(width: 10),
                            Expanded(child: Text(m.to, style: tt.large.copyWith(fontSize: 15))),
                            MessageStatusBadge(m.status),
                          ]),
                          const SizedBox(height: 16),
                          _Bubble(text: m.text, mine: true),
                          if (m.reply != null) ...[
                            const SizedBox(height: 8),
                            _Bubble(text: m.reply!, mine: false),
                          ],
                          if (m.status == MessageStatus.draft || m.status == MessageStatus.sent) ...[
                            const SizedBox(height: 14),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              if (m.status == MessageStatus.draft) ...[
                                ShadButton.outline(onPressed: () => editMessageDialog(context, m), child: const Text('Edit')),
                                const SizedBox(width: 6),
                                ShadButton(
                                  onPressed: () => s.approveMessage(m.id),
                                  leading: const Icon(LucideIcons.send, size: 16),
                                  child: const Text('Send'),
                                ),
                              ],
                              if (m.status == MessageStatus.sent)
                                ShadButton.outline(
                                  enabled: !s.isBusy,
                                  onPressed: () => s.simulateReply(m.id),
                                  leading: const Icon(LucideIcons.reply, size: 16),
                                  child: const Text('Simulate reply'),
                                ),
                            ]),
                          ],
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: mine ? cs.primary : cs.muted,
          borderRadius: BorderRadius.circular(rLg),
        ),
        child: Text(text,
            style: context.tt.p.copyWith(fontSize: 14, height: 1.5, color: mine ? cs.primaryForeground : cs.foreground)),
      ),
    );
  }
}
