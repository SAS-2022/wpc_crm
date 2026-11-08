import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sign_out.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import 'hr_actions.dart';
import 'hr_actions_repository.dart';
import 'hr_actions_screen.dart';

/// Covers the whole app (phones and web) while the signed-in employee has a
/// warning / deduction / reward / note from HR they haven't accepted yet
/// (user request 2026-11-07): its details and "Agreed and Accepted"; the
/// app opens only once every one is accepted. Sits in `MaterialApp.builder`
/// (above the router's Navigator), so it brings its own Navigator for
/// dialogs and file viewers.
class HrAcknowledgeGate extends ConsumerWidget {
  const HrAcknowledgeGate({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(myPendingHrActionsProvider).value ?? const <HrAction>[];
    if (pending.isEmpty) return child ?? const SizedBox.shrink();
    final first = pending.first;
    return Navigator(
      key: ValueKey('hrGate_${first.id}'),
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _AcknowledgeScreen(action: first, left: pending.length)),
    );
  }
}

class _AcknowledgeScreen extends ConsumerStatefulWidget {
  const _AcknowledgeScreen({required this.action, required this.left});

  final HrAction action;

  /// Records still to accept, this one included.
  final int left;

  @override
  ConsumerState<_AcknowledgeScreen> createState() => _AcknowledgeScreenState();
}

class _AcknowledgeScreenState extends ConsumerState<_AcknowledgeScreen> {
  bool _busy = false;

  Future<void> _accept() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(hrActionsRepositoryProvider).accept(widget.action.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final a = widget.action;
    final date = DateTime.tryParse(a.date);
    final color = hrKindColor(context, a.kind);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.bodyLarge),
          ]),
        );
    final month = DateTime.tryParse('${a.payMonth}-01');
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.hrGateTitle),
          actions: [TextButton(onPressed: signOut, child: Text(l10n.signOut))],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.left > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l10n.hrGateMore(widget.left), style: theme.textTheme.bodySmall),
                  ),
                Card(
                  color: color.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(hrKindIcon(a.kind), color: color, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            a.kind == HrActionKind.warning && a.level != null
                                ? warningLevelLabel(l10n, a.level!)
                                : hrKindLabel(l10n, a.kind),
                            style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      row(l10n.hrActionTitleLabel, a.title),
                      if (date != null) row(l10n.date, DateFormat.yMMMMd(locale).format(date)),
                      if (a.kind.affectsPay && hrPayLine(l10n, a).isNotEmpty)
                        row(a.kind == HrActionKind.deduction ? l10n.deductionAmount : l10n.rewardAmount, hrPayLine(l10n, a)),
                      if (a.kind.affectsPay && month != null) row(l10n.payrollMonth, DateFormat.yMMMM(locale).format(month)),
                      if (a.notes.isNotEmpty) row(l10n.notes, a.notes),
                    ]),
                  ),
                ),
                AttachmentsSection(owner: (parent: AttachmentParent.hrActions, id: a.id), canAdd: false, canDelete: false),
                const SizedBox(height: 16),
                Text(l10n.hrGateBody, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : _accept,
                  icon: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(l10n.hrAgreedAccepted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
