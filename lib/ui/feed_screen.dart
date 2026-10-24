import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_state.dart';
import '../models/fact.dart';
import '../models/feed_item.dart';
import '../models/outbound_message.dart';
import '../voice/reson8_client.dart';
import 'widgets/common.dart';
import 'widgets/fact_tile.dart';
import 'widgets/tool_trace.dart';

const _chatWidth = 760.0;

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.feed.where((f) => f.week == s.viewWeek).toList();
    final card = nextStepCard(s);
    if (items.isEmpty) return _EmptyAgent(card: card);
    return Column(children: [
      Expanded(
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          itemCount: items.length + (card == null ? 0 : 1),
          itemBuilder: (_, i) {
            final child = card != null && i == 0
                ? Padding(padding: const EdgeInsets.only(bottom: 8), child: card)
                : ChatTurn(items[card == null ? i : i - 1], key: ObjectKey(items[card == null ? i : i - 1]));
            return Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _chatWidth), child: child),
            );
          },
        ),
      ),
      const Composer(),
    ]);
  }
}

/// What the founder can start next in the week being viewed, if anything.
Widget? nextStepCard(AppState s) {
  if (s.isBusy) return null;
  if (s.canRunCheckIn) {
    final w = simWeeks[s.viewWeek];
    final since = w.since.add(const Duration(minutes: 1));
    return _SuggestionCard(
      icon: LucideIcons.calendarCheck,
      title: 'Run the ${w.label.toLowerCase()} check-in',
      detail: '${shortDate.format(since)} to ${shortDate.format(w.until)}',
      onTap: s.runCheckIn,
    );
  }
  if (s.canCloseMonth) {
    return _SuggestionCard(
      icon: LucideIcons.fileText,
      title: 'Close October and draft the update',
      detail: 'Oct 29 to Oct 31',
      onTap: s.closeMonth,
    );
  }
  return null;
}

/// Start screen of a week: greeting, centered composer and the next step.
class _EmptyAgent extends StatelessWidget {
  const _EmptyAgent({this.card});

  final Widget? card;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppLogo(size: 64),
          const SizedBox(height: 20),
          Text('Good morning, Reson8', style: tt.h2.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          const SizedBox(height: 28),
          const Composer(),
          if (card != null) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _chatWidth + 20 + 48),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: card),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({required this.icon, required this.title, required this.detail, this.onTap});

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hover ? cs.muted.withValues(alpha: 0.6) : cs.background,
            borderRadius: BorderRadius.circular(rLg),
            border: Border.all(color: cs.border),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(rSm)),
              child: Icon(widget.icon, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: tt.small.copyWith(fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(widget.detail, style: tt.muted.copyWith(fontSize: 13)),
              ]),
            ),
            Icon(LucideIcons.arrowRight, size: 16, color: cs.mutedForeground),
          ]),
        ),
      ),
    );
  }
}

/// One turn in the conversation: optional divider, optional user bubble,
/// and the agent's reply.
class ChatTurn extends StatelessWidget {
  const ChatTurn(this.item, {super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    final run = item.run;
    final facts = run == null ? <Fact>[] : run.proposedFactIds.map(s.factById).whereType<Fact>().toList();
    final pendingIds = facts.where((f) => f.status == FactStatus.pending).map((f) => f.id).toList();
    final suggestions = s.kpiSuggestions.where((k) => k.factId != null && (run?.proposedFactIds.contains(k.factId) ?? false));
    final messages = run == null ? <OutboundMessage>[] : run.messageIds.map(s.messageById).whereType<OutboundMessage>().toList();
    final divider = switch (item.type) {
      FeedType.checkIn || FeedType.report => item.title,
      _ => null,
    };
    final text = tt.p.copyWith(fontSize: 15, height: 1.6, color: cs.foreground);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (divider != null) _Divider('${shortDate.format(item.date)} · $divider'),
        if (item.userText != null && item.author == null) _UserBubble(item.userText!),
        if (item.author != null) _IncomingMessage(author: item.author!, text: item.userText!),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _AgentAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (run != null) ToolTrace(run, key: ObjectKey(run)),
              if (item.body != null) ...[
                const SizedBox(height: 4),
                Text(item.body!, style: text),
              ],
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 14),
                FactList(facts),
                if (pendingIds.length > 1 && !item.offersReport)
                  Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(top: 10),
                    child: ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: () => s.confirmAll(pendingIds),
                      leading: const Icon(LucideIcons.checkCheck, size: 14),
                      child: const Text('Confirm all'),
                    ),
                  ),
              ],
              for (final k in suggestions) _KpiSuggestion(k),
              if (run != null)
                for (final q in run.questions) ...[
                  const SizedBox(height: 14),
                  Text(q, style: text),
                ],
              for (final m in messages) _ApprovalCard(m),
              if (item.offersReport && run != null && run.done && s.report == null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ShadButton(
                    enabled: !s.isBusy,
                    onPressed: () async {
                      s.confirmAll(pendingIds);
                      await s.draftReport();
                    },
                    leading: const Icon(LucideIcons.fileText, size: 16),
                    child: Text(pendingIds.isEmpty ? 'Draft the update' : 'Confirm & draft the update'),
                  ),
                ),
              if (item.type == FeedType.report && s.report != null && run != null && run.done)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _ReportLink(onTap: () => s.setTab(3)),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      child: Row(children: [
        Expanded(child: Divider(color: cs.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: context.tt.muted.copyWith(fontSize: 12)),
        ),
        Expanded(child: Divider(color: cs.border)),
      ]),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.only(top: 3, left: 3, right: 3), child: AppLogo(size: 24));
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: _chatWidth * 0.75),
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: context.cs.muted, borderRadius: BorderRadius.circular(rLg + 2)),
          child: Text(text, style: context.tt.p.copyWith(fontSize: 15, height: 1.5)),
        ),
      );
}

class _IncomingMessage extends StatelessWidget {
  const _IncomingMessage({required this.author, required this.text});

  final String author;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 42),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(rMd), border: Border.all(color: cs.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SourceLogo('slack', size: 16),
          const SizedBox(width: 8),
          Text(author, style: tt.small),
        ]),
        const SizedBox(height: 8),
        Text(text, style: tt.p.copyWith(fontSize: 14, height: 1.5)),
      ]),
    );
  }
}

class _KpiSuggestion extends StatelessWidget {
  const _KpiSuggestion(this.k);

  final KpiSuggestion k;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(rMd), border: Border.all(color: cs.border)),
      child: Row(children: [
        Expanded(child: Text('Add ${kpiCatalog[k.metric] ?? k.metric} to the KPIs?', style: tt.small)),
        if (k.accepted == null) ...[
          ShadButton.ghost(size: ShadButtonSize.sm, onPressed: () => s.resolveKpiSuggestion(k, false), child: const Text('No')),
          ShadButton(size: ShadButtonSize.sm, onPressed: () => s.resolveKpiSuggestion(k, true), child: const Text('Add')),
        ] else
          Icon(k.accepted! ? LucideIcons.circleCheck : LucideIcons.circleSlash, size: 17, color: k.accepted! ? green : cs.mutedForeground),
      ]),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard(this.m);

  final OutboundMessage m;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(rMd), border: Border.all(color: cs.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Row(children: [
            const SourceLogo('slack', size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('To ${m.to}', style: tt.small)),
            MessageStatusBadge(m.status),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Text(m.text, style: tt.p.copyWith(fontSize: 14, height: 1.55)),
        ),
        if (m.status == MessageStatus.draft || m.status == MessageStatus.sent)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (m.status == MessageStatus.draft) ...[
                ShadButton.ghost(size: ShadButtonSize.sm, onPressed: () => s.rejectMessage(m.id), child: const Text('Discard')),
                ShadButton.outline(size: ShadButtonSize.sm, onPressed: () => editMessageDialog(context, m), child: const Text('Edit')),
                const SizedBox(width: 6),
                ShadButton(
                  size: ShadButtonSize.sm,
                  onPressed: () => s.approveMessage(m.id),
                  leading: const Icon(LucideIcons.send, size: 14),
                  child: const Text('Send'),
                ),
              ],
              if (m.status == MessageStatus.sent)
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  enabled: !s.isBusy,
                  onPressed: () => s.simulateReply(m.id),
                  leading: const Icon(LucideIcons.reply, size: 14),
                  child: Text('Simulate reply from ${m.to}'),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// Preview card for the drafted investor update, in the style of a document artifact.
class _ReportLink extends StatefulWidget {
  const _ReportLink({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ReportLink> createState() => _ReportLinkState();
}

class _ReportLinkState extends State<_ReportLink> {
  static const _width = 440.0;
  static const _bannerHeight = 180.0;
  static const _orange = Color(0xFFDD742A);
  static const _brightOrange = Color(0xFFFF8616);
  static const _brown = Color(0xFF411A14);

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final dark = isDark(context);
    final r = context.watch<AppState>().report!;
    final accent = dark ? _brightOrange : _orange;
    final alive = r.defaultAlive;
    final subtitle = [
      'Investor update',
      '${r.kpis.length} ${r.kpis.length == 1 ? 'KPI' : 'KPIs'}',
      if (alive != null) alive.alive ? 'Default alive' : 'Default dead',
    ].join(' · ');
    final badge = r.approved
        ? const TintBadge('Sent', green, icon: LucideIcons.check)
        : r.flaggedCount > 0
            ? TintBadge('${r.flaggedCount} to check', amber)
            : TintBadge('Draft', cs.mutedForeground);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: _width,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.circular(rLg),
            border: Border.all(color: _hover ? accent.withValues(alpha: 0.55) : cs.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? (dark ? 0.45 : 0.10) : (dark ? 0.25 : 0.04)),
                blurRadius: _hover ? 22 : 8,
                offset: Offset(0, _hover ? 8 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rLg - 1),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _banner(context, accent, dark),
              Container(height: 1, color: cs.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? 0.16 : 0.12),
                      borderRadius: BorderRadius.circular(rSm),
                    ),
                    child: Icon(LucideIcons.fileText, size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        r.subject,
                        style: tt.small.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: tt.muted.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  badge,
                  const SizedBox(width: 6),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 160),
                    offset: Offset(_hover ? 0.15 : 0, 0),
                    child: Icon(LucideIcons.chevronRight, size: 16, color: _hover ? accent : cs.mutedForeground),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Warm banner with a stylized preview of the update: two stacked sheets with skeleton lines.
  Widget _banner(BuildContext context, Color accent, bool dark) {
    final cs = context.cs;
    const sheetWidth = 232.0;
    const sheetLeft = (_width - sheetWidth) / 2;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark ? const [_brown, Color(0xFF2A120E)] : const [Color(0xFFF2A15F), _orange],
    );
    final glow = dark ? _brightOrange.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.35);
    return SizedBox(
      height: _bannerHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned(
            right: -60,
            top: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [glow, glow.withValues(alpha: 0)]),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -90,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [glow.withValues(alpha: glow.a * 0.6), glow.withValues(alpha: 0)]),
              ),
            ),
          ),
          // Sheet behind, tilted.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: sheetLeft - 14,
            top: _hover ? 30 : 36,
            child: Transform.rotate(
              angle: -0.07,
              child: Container(
                width: sheetWidth,
                height: 200,
                decoration: BoxDecoration(
                  color: dark
                      ? Color.alphaBlend(_brightOrange.withValues(alpha: 0.14), cs.card)
                      : cs.card.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dark ? _brightOrange.withValues(alpha: 0.30) : Colors.white24),
                ),
              ),
            ),
          ),
          // Front sheet with the skeleton of the update.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: sheetLeft + 6,
            top: _hover ? 18 : 26,
            child: Transform.rotate(
              angle: 0.015,
              child: Container(
                width: sheetWidth,
                height: 200,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                decoration: BoxDecoration(
                  color: cs.card,
                  borderRadius: BorderRadius.circular(8),
                  border: dark ? Border.all(color: cs.border) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.45 : 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _sheetContent(cs, accent),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sheetContent(ShadColorScheme cs, Color accent) {
    Widget bar(double width, double height, Color color) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
        );
    final line = cs.border;
    final title = cs.foreground.withValues(alpha: 0.70);
    const bars = [0.35, 0.45, 0.42, 0.58, 0.66, 0.80, 1.0];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const AppLogo(size: 16),
        const SizedBox(width: 8),
        bar(96, 7, title),
        const Spacer(),
        bar(28, 5, line),
      ]),
      const SizedBox(height: 7),
      bar(64, 4, line),
      const SizedBox(height: 12),
      // Mini KPI tiles.
      Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                bar(20, 3, line),
                const SizedBox(height: 4),
                bar(i == 0 ? 34 : 26, 6, i == 0 ? accent : title.withValues(alpha: 0.45)),
              ]),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 10),
      // Mini chart next to a few text lines.
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
          decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < bars.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Container(
                width: 7,
                height: 33 * bars[i],
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.35 + 0.65 * i / (bars.length - 1)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            bar(double.infinity, 4, line),
            const SizedBox(height: 6),
            bar(double.infinity, 4, line),
            const SizedBox(height: 6),
            bar(52, 4, line),
            const SizedBox(height: 4),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      bar(64, 5, title.withValues(alpha: 0.45)),
      const SizedBox(height: 7),
      bar(double.infinity, 4, line),
      const SizedBox(height: 6),
      bar(double.infinity, 4, line),
      const SizedBox(height: 6),
      bar(140, 4, line),
    ]);
  }
}

class MessageStatusBadge extends StatelessWidget {
  const MessageStatusBadge(this.status, {super.key});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        MessageStatus.draft => const TintBadge('Draft', amber),
        MessageStatus.sent => const TintBadge('Sent', blue),
        MessageStatus.replied => const TintBadge('Replied', green),
        MessageStatus.rejected => TintBadge('Discarded', context.cs.mutedForeground),
      };
}

Future<void> editMessageDialog(BuildContext context, OutboundMessage m) async {
  final s = context.read<AppState>();
  final c = TextEditingController(text: m.text);
  final ok = await showShadDialog<bool>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: Text('Message to ${m.to}'),
      radius: BorderRadius.circular(rLg),
      actions: [
        ShadButton.outline(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ShadButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
      ],
      child: SizedBox(width: 500, child: ShadInput(controller: c, maxLines: 6, minLines: 4)),
    ),
  );
  if (ok == true) await s.approveMessage(m.id, editedText: c.text.trim());
}

/// Rounded, floating composer in the style of frontier-lab chat apps.
class Composer extends StatefulWidget {
  const Composer({super.key});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _c = TextEditingController();
  final _voice = Reson8Client();
  bool _recording = false;
  bool _transcribing = false;
  bool _fromVoice = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = context.read<AppState>();
    final text = _c.text.trim();
    if (text.isEmpty || s.isBusy) return;
    final source = _fromVoice ? 'voice' : 'founder';
    _c.clear();
    setState(() => _fromVoice = false);
    await s.sendInbound(text, sourceId: source);
  }

  Future<void> _toggleMic() async {
    if (_transcribing) return;
    if (!_recording) {
      if (!_voice.hasKey) {
        toast(context, 'No Reson8 key in this build. Start the app with --dart-define-from-file=secrets.json');
        return;
      }
      final ok = await _voice.start();
      if (!mounted) return;
      if (!ok) {
        toast(context, 'Microphone permission denied');
        return;
      }
      setState(() => _recording = true);
      return;
    }
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    try {
      _c.text = await _voice.stopAndTranscribe();
      _fromVoice = true;
    } catch (e) {
      if (mounted) toast(context, 'Transcription failed: $e');
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _attach() async {
    final s = context.read<AppState>();
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Documents', extensions: ['pdf', 'txt', 'md', 'csv']),
    ]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mime = file.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'text/plain';
    await s.sendDocument(file.name, bytes, mime);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = context.cs;
    final tt = context.tt;
    final canSend = _c.text.trim().isNotEmpty && !s.isBusy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _chatWidth + 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            decoration: BoxDecoration(
              color: cs.background,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: cs.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 6))],
            ),
            child: Column(children: [
              Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: _c,
                  minLines: 1,
                  maxLines: 6,
                  style: tt.p.copyWith(fontSize: 15),
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration.collapsed(
                    hintText: _recording ? 'Listening…' : _transcribing ? 'Transcribing…' : 'Reply to your agent',
                    hintStyle: tt.muted.copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                ShadIconButton.ghost(
                  width: 34,
                  height: 34,
                  iconSize: 18,
                  enabled: !s.isBusy,
                  icon: const Icon(LucideIcons.plus),
                  onPressed: _attach,
                ),
                const Spacer(),
                if (_transcribing)
                  const Padding(
                    padding: EdgeInsets.all(9),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  ShadIconButton.ghost(
                    width: 34,
                    height: 34,
                    iconSize: 18,
                    foregroundColor: _recording ? red : null,
                    icon: Icon(_recording ? LucideIcons.square : LucideIcons.mic),
                    onPressed: _toggleMic,
                  ),
                const SizedBox(width: 4),
                ShadIconButton(
                  width: 34,
                  height: 34,
                  iconSize: 17,
                  enabled: canSend,
                  icon: const Icon(LucideIcons.arrowUp),
                  onPressed: _send,
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
