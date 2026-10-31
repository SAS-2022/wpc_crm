import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import 'absence.dart';
import 'attendance_repository.dart' show attendanceDay;

String absenceReasonLabel(AppLocalizations l10n, AbsenceReason r) => switch (r) {
      AbsenceReason.sick => l10n.absenceSick,
      AbsenceReason.tired => l10n.absenceTired,
      AbsenceReason.cantCome => l10n.absenceCantCome,
    };

String absenceLeaveLabel(AppLocalizations l10n, AbsenceLeave? l) => switch (l) {
      AbsenceLeave.sick => l10n.asSickLeave,
      AbsenceLeave.annual => l10n.asAnnualLeave,
      null => '',
    };

/// "Waiting for HR" / "Accepted as sick leave" / "Not accepted – absence day".
String absenceStatusText(AppLocalizations l10n, Absence a) => switch (a.status) {
      AbsenceStatus.pending when a.waitingForManager => l10n.absenceWaitingManager,
      AbsenceStatus.pending => l10n.absenceWaiting,
      AbsenceStatus.accepted => l10n.absenceAcceptedAs(absenceLeaveLabel(l10n, a.countAs)),
      AbsenceStatus.rejected when a.rejectedByManager => l10n.absenceRejectedByManager,
      AbsenceStatus.rejected => l10n.absenceRejectedText,
    };

Color absenceStatusColor(Absence a, ColorScheme scheme) => switch (a.status) {
      AbsenceStatus.pending => Colors.orange.shade800,
      AbsenceStatus.accepted => Colors.blue.shade600,
      AbsenceStatus.rejected => scheme.error,
    };

IconData absenceReasonIcon(AbsenceReason r) => switch (r) {
      AbsenceReason.sick => Icons.sick_outlined,
      AbsenceReason.tired => Icons.bedtime_outlined,
      AbsenceReason.cantCome => Icons.event_busy_outlined,
    };

/// "Not coming to work": today or tomorrow, reason (sick / tired / can't
/// come) and a short explanation. [todayOpen]: false once they checked in
/// or reported today; [tomorrowOpen]: false once tomorrow is reported.
Future<void> showAbsenceSheet(BuildContext context, AppUser me, {required bool todayOpen, required bool tomorrowOpen}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AbsenceSheet(me: me, todayOpen: todayOpen, tomorrowOpen: tomorrowOpen),
    );

class _AbsenceSheet extends ConsumerStatefulWidget {
  const _AbsenceSheet({required this.me, required this.todayOpen, required this.tomorrowOpen});

  final AppUser me;
  final bool todayOpen;
  final bool tomorrowOpen;

  @override
  ConsumerState<_AbsenceSheet> createState() => _AbsenceSheetState();
}

class _AbsenceSheetState extends ConsumerState<_AbsenceSheet> {
  final _note = TextEditingController();
  late bool _today = widget.todayOpen;
  AbsenceReason? _reason;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = _note.text.trim();
    if (_reason == null || note.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(_reason == null ? l10n.absencePickReason : l10n.absenceWriteReason)));
      return;
    }
    final now = DateTime.now();
    final date = attendanceDay(_today ? now : DateTime(now.year, now.month, now.day + 1));
    setState(() => _busy = true);
    try {
      await reportAbsence(
        me: widget.me,
        date: date,
        reason: _reason!,
        note: note,
      );
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.absenceSent)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.absenceTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.today), enabled: widget.todayOpen),
                ButtonSegment(value: false, label: Text(l10n.tomorrow), enabled: widget.tomorrowOpen),
              ],
              selected: {_today},
              onSelectionChanged: (v) => setState(() => _today = v.first),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in AbsenceReason.values)
                  ChoiceChip(
                    avatar: Icon(absenceReasonIcon(r), size: 18),
                    label: Text(absenceReasonLabel(l10n, r)),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.absenceReasonField, border: const OutlineInputBorder()),
            ),
            if (_reason == AbsenceReason.sick) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.absenceSickHelp, style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: busyIcon(_busy, const Icon(Icons.send)),
              label: Text(l10n.absenceSend),
            ),
          ],
        ),
      ),
    );
  }
}

/// On the attendance card: "Not coming today · Sick", what they wrote, the
/// decision (waiting / accepted as … / not accepted), and while waiting
/// "Attach document" (medical report for sick days) and Undo. Tap = the
/// absence page.
class AbsenceNotice extends ConsumerWidget {
  const AbsenceNotice({super.key, required this.absence, required this.today});

  final Absence absence;

  /// Today's absence (else tomorrow's, shown smaller).
  final bool today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final files =
        ref.watch(attachmentsProvider((parent: AttachmentParent.absences, id: absence.id))).value ?? const <Attachment>[];
    final reason = absenceReasonLabel(l10n, absence.reason);
    final when = today
        ? l10n.absentToday(reason)
        : l10n.absentOn(DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(DateTime.parse(absence.date)), reason);
    final color = absenceStatusColor(absence, theme.colorScheme);
    final sickNoReport = absence.pending && absence.reason == AbsenceReason.sick && files.isEmpty;

    Future<void> undo() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(l10n.absenceUndoConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.absenceUndo)),
          ],
        ),
      );
      if (ok == true) await withdrawAbsence(absence);
    }

    return ListTile(
      onTap: () => context.push('/absence/${absence.id}'),
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.14), child: Icon(absenceReasonIcon(absence.reason), color: color)),
      title: Text(when, style: today ? theme.textTheme.titleMedium : null),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (absence.note.isNotEmpty) Text(absence.note),
          const SizedBox(height: 4),
          Text(absenceStatusText(l10n, absence), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (absence.comment.isNotEmpty) Text('“${absence.comment}”'),
          if (sickNoReport) Text(l10n.sickReportMissing, style: TextStyle(color: theme.colorScheme.error)),
          if (absence.pending)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => context.push('/absence/${absence.id}'),
                  icon: const Icon(Icons.attach_file),
                  label: Text(files.isEmpty
                      ? (absence.reason == AbsenceReason.sick ? l10n.attachSickReport : l10n.attachDocument)
                      : l10n.documentsCount(files.length)),
                ),
                TextButton(onPressed: undo, child: Text(l10n.absenceUndo)),
              ],
            ),
        ],
      ),
    );
  }
}
