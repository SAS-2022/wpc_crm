import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'work_hours.dart';
import 'work_hours_editor.dart';
import '../../core/saving.dart';

/// GM / sales manager: the days and hours when field staff locations are shared.
class WorkHoursScreen extends ConsumerStatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  ConsumerState<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends ConsumerState<WorkHoursScreen> {
  WorkHours? _edit;
  bool _busy = false;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final h = _edit!;
    if (h.endMinute <= h.startMinute) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.endAfterStart)));
      return;
    }
    setState(() => _busy = true);
    try {
      await workHoursRef.set(h.toMap());
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(workHoursProvider).value;
    if (saved == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final h = _edit ??= saved;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.workHours)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.workHoursHelp),
          const SizedBox(height: 16),
          WorkHoursEditor(value: h, onChanged: (v) => setState(() => _edit = v)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: BusyLabel(busy: _busy, child: Text(l10n.save))),
        ],
      ),
    );
  }
}
