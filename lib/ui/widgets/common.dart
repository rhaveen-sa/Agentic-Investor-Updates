import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app_state.dart';
import '../../data/connectors.dart';
import '../../models/fact.dart';

final shortDate = DateFormat('MMM d');

extension ShadContext on BuildContext {
  ShadColorScheme get cs => ShadTheme.of(this).colorScheme;
  ShadTextTheme get tt => ShadTheme.of(this).textTheme;
}

const amber = Color(0xFFD97706);
const green = Color(0xFF16A34A);
const red = Color(0xFFDC2626);
const blue = Color(0xFF2563EB);

// Radii used across the app.
const rSm = 10.0;
const rMd = 14.0;
const rLg = 20.0;

bool isDark(BuildContext context) => ShadTheme.of(context).brightness == Brightness.dark;

/// The Ledger logo, in the variant made for the current theme.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        isDark(context) ? 'assets/brand/logo_dark.png' : 'assets/brand/logo_light.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      );
}

/// The company logo of a source (or an icon for founder input).
class SourceLogo extends StatelessWidget {
  const SourceLogo(this.sourceId, {super.key, this.size = 16});

  final String sourceId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final info = sourceInfo(sourceId);
    if (info.logo == null) return Icon(info.icon, size: size, color: context.cs.mutedForeground);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(info.logo!, width: size, height: size, filterQuality: FilterQuality.medium),
    );
    if (!isDark(context)) return image;
    // Some logos are dark on transparent; give them a light tile in dark mode.
    return Container(
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.26)),
      child: SizedBox(width: size * 0.84, height: size * 0.84, child: FittedBox(child: image)),
    );
  }
}

/// Pill with the source logo and name.
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.sourceId, {super.key, this.onTap});

  final String sourceId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 9, 3),
      decoration: BoxDecoration(
        color: context.cs.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.cs.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SourceLogo(sourceId, size: 14),
        const SizedBox(width: 6),
        Text(sourceInfo(sourceId).name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
    if (onTap == null) return badge;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: badge));
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final FactStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        FactStatus.pending => const TintBadge('Pending', amber),
        FactStatus.confirmed => const TintBadge('Confirmed', green),
        FactStatus.dismissed => TintBadge('Dismissed', context.cs.mutedForeground),
      };
}

/// Soft colored pill.
class TintBadge extends StatelessWidget {
  const TintBadge(this.label, this.color, {super.key, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

class SaidTag extends StatelessWidget {
  const SaidTag({super.key});

  @override
  Widget build(BuildContext context) => ShadTooltip(
        builder: (_) => const Text('Only said in a meeting or chat, not backed by a system of record'),
        child: const TintBadge('Unconfirmed', amber),
      );
}

/// Opens the origin of one or more facts: source, record, excerpt.
Future<void> showFactSources(BuildContext context, List<String> factIds, {String? title}) {
  final s = context.read<AppState>();
  final facts = factIds.map(s.factById).whereType<Fact>().toList();
  return showShadDialog(
    context: context,
    builder: (ctx) => ShadDialog(
      title: Text(title ?? 'Source'),
      description: facts.isEmpty ? const Text('No fact is cited for this claim.') : null,
      radius: BorderRadius.circular(rLg),
      constraints: const BoxConstraints(maxWidth: 600),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final f in facts) _SourceBlock(f)],
          ),
        ),
      ),
    ),
  );
}

class _SourceBlock extends StatelessWidget {
  const _SourceBlock(this.f);

  final Fact f;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.background,
        borderRadius: BorderRadius.circular(rMd),
        border: Border.all(color: cs.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SourceBadge(f.sourceId),
          const SizedBox(width: 8),
          Text(shortDate.format(f.date), style: tt.muted.copyWith(fontSize: 12)),
          const Spacer(),
          if (f.statementOnly) ...[const SaidTag(), const SizedBox(width: 6)],
          StatusBadge(f.status),
        ]),
        const SizedBox(height: 10),
        Text(f.text, style: tt.large.copyWith(fontSize: 15)),
        if (f.excerpt != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(rSm)),
            child: Text(f.excerpt!, style: tt.small.copyWith(fontWeight: FontWeight.w400, height: 1.5, color: cs.mutedForeground)),
          ),
        ],
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 28, color: context.cs.mutedForeground),
        const SizedBox(height: 12),
        Text(title, style: context.tt.muted.copyWith(fontSize: 14)),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ]),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 20),
      child: Row(children: [
        Expanded(child: Text(title, style: context.tt.h3)),
        ?trailing,
      ]),
    );
  }
}

void toast(BuildContext context, String title) => ShadToaster.of(context).show(ShadToast(title: Text(title)));
