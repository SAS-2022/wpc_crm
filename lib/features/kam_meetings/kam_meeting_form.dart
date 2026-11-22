import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart' show BusyLabel;
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'kam_meeting.dart';
import 'kam_meeting_widgets.dart';
import 'kam_meetings_repository.dart';

/// New / edit meeting (SM / GM): KAM, day and time, conclusion, tasks (text
/// + optional due day). Done tasks keep their status when edited.
class KamMeetingForm extends ConsumerStatefulWidget {
  const KamMeetingForm({super.key, this.id, this.kamId});

  /// null = new meeting.
  final String? id;

  /// New meeting: the KAM picked on the list.
  final String? kamId;

  @override
  ConsumerState<KamMeetingForm> createState() => _KamMeetingFormState();
}

class _TaskRow {
  _TaskRow({this.id, String text = '', this.due, this.done = false}) : controller = TextEditingController(text: text);

  final String? id;
  final TextEditingController controller;
  DateTime? due;
  final bool done;
}

class _KamMeetingFormState extends ConsumerState<KamMeetingForm> {
  String? _kam;
  late DateTime _at;
  final _conclusion = TextEditingController();
  final _rows = <_TaskRow>[];
  final _removed = <String>{};
  bool _loaded = false;
  bool _saving = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _kam = widget.kamId;
    final now = DateTime.now();
    _at = DateTime(now.year, now.month, now.day, now.hour + 1);
    if (widget.id == null) {
      _loaded = true;
      _rows.add(_TaskRow());
    }
  }

  @override
  void dispose() {
    _conclusion.dispose();
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  void _load() {
    if (_loaded || widget.id == null) return;
    final m = ref.read(kamMeetingProvider(widget.id!));
    if (m == null) return;
    _loaded = true;
    _kam = m.kamId;
    _at = m.at ?? _at;
    _conclusion.text = m.conclusion;
    for (final t in sortKamTasks(ref.read(meetingTasksProvider(m.id)), DateTime.now())) {
      _rows.add(_TaskRow(id: t.id, text: t.text, due: t.due, done: t.done));
    }
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  Future<void> _pickDue(_TaskRow r) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: r.due ?? _at,
      firstDate: DateTime(2025),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => r.due = d);
  }

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_kam == null) return;
    setState(() => _saving = true);
    try {
      final id = await saveKamMeeting(
        id: widget.id,
        kamId: _kam!,
        at: _at,
        conclusion: _conclusion.text,
        tasks: [for (final r in _rows) (id: r.id, text: r.controller.text, due: r.due)],
        removedTaskIds: {
          ..._removed,
          for (final r in _rows)
            if (r.id != null && r.controller.text.trim().isEmpty) r.id!,
        },
      );
      if (!mounted) return;
      if (widget.id == null) {
        context.pushReplacement('/kam-meetings/$id');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorWithMessage('$e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    ref.watch(kamMeetingsProvider);
    ref.watch(kamTasksProvider);
    _load();
    final kams = activeKams(ref.watch(usersProvider).value ?? const <AppUser>[]);
    if (!_loaded) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? l10n.kamNewMeeting : l10n.kamEditMeeting)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              DropdownButtonFormField<String>(
                initialValue: kams.any((k) => k.id == _kam) ? _kam : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '${l10n.kamLabel} *',
                  errorText: _tried && _kam == null ? l10n.kamPickKam : null,
                  border: const OutlineInputBorder(),
                ),
                items: [for (final k in kams) DropdownMenuItem(value: k.id, child: Text(k.name))],
                onChanged: (v) => setState(() => _kam = v),
              ),
              const SizedBox(height: 16),
              Text(l10n.kamMeetingTime, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat.yMMMEd(locale).format(_at)),
                    onPressed: _pickDay,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(DateFormat.jm(locale).format(_at)),
                    onPressed: _pickTime,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _conclusion,
                minLines: 5,
                maxLines: 14,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.kamConclusion,
                  helperText: l10n.kamConclusionHelp,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.kamTasksTab, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final r in _rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Icon(
                          r.done ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 20,
                          color: r.done ? Colors.green.shade600 : theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: r.controller,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: l10n.kamTaskHint,
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.event, size: 16),
                                  label: Text(r.due == null
                                      ? l10n.kamTaskAddDue
                                      : l10n.kamTaskDue(DateFormat.MMMd(locale).format(r.due!))),
                                  onPressed: () => _pickDue(r),
                                ),
                                if (r.due != null)
                                  IconButton(
                                    tooltip: l10n.kamTaskNoDue,
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => setState(() => r.due = null),
                                  ),
                                if (r.done)
                                  Text(l10n.kamTaskAlreadyDone, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.kamTaskRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          if (r.id != null) _removed.add(r.id!);
                          _rows.remove(r);
                        }),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.kamAddTask),
                  onPressed: () => setState(() => _rows.add(_TaskRow())),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: BusyLabel(busy: _saving, child: Text(l10n.save)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
