import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'plan_repository.dart';
import 'plan_task.dart';

/// Checklist texts the plan's owner used this month, as quick choices.
List<String> _suggestions(WidgetRef ref, String ownerId, String date, Iterable<String> exclude) {
  final tasks = ref.watch(monthTasksProvider((ownerId, date.substring(0, 7)))).value ?? const <PlanTask>[];
  final taken = exclude.toSet();
  return recentChecklistTexts(tasks).where((t) => !taken.contains(t)).take(8).toList();
}

/// The tasks of one planned client visit. The owner ticks them ([canTick]),
/// with an optional comment; [canEdit] adds tasks and removes open ones
/// (KAM / managers any, the owner the ones they added). Changes go to
/// [onChanged] as the whole new list.
class PlanChecklist extends ConsumerWidget {
  const PlanChecklist({
    super.key,
    required this.task,
    this.canTick = false,
    this.canEdit = false,
    this.onChanged,
  });

  final PlanTask task;
  final bool canTick;
  final bool canEdit;
  final ValueChanged<List<ChecklistItem>>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(currentUserProvider).value;
    final items = task.checklist;
    final locale = Localizations.localeOf(context).toString();

    void replace(ChecklistItem item) => onChanged?.call([for (final i in items) i.id == item.id ? item : i]);

    Future<void> complete(ChecklistItem item) async {
      final updated = await showDialog<ChecklistItem>(
        context: context,
        builder: (_) => _CompleteDialog(item: item),
      );
      if (updated != null) replace(updated);
    }

    Future<void> add() async {
      final texts = await showDialog<List<String>>(
        context: context,
        builder: (_) => _AddDialog(suggestions: _suggestions(ref, task.ownerId, task.date, items.map((i) => i.text))),
      );
      if (texts == null || texts.isEmpty || me == null) return;
      onChanged?.call([...items, for (final t in texts) ChecklistItem.create(t, me.id)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          InkWell(
            onTap: canTick ? () => complete(item) : null,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
              child: Row(
                children: [
                  canTick
                      ? Checkbox(value: item.done, onChanged: (v) => replace(item.complete(done: v ?? false)))
                      : Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            item.done ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 20,
                            color: item.done ? Colors.green.shade700 : scheme.onSurfaceVariant,
                          ),
                        ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: item.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                        ),
                        if (item.comment.isNotEmpty || item.doneAt != null)
                          Text(
                            [
                              if (item.doneAt != null) DateFormat.jm(locale).format(item.doneAt!),
                              item.comment,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (canEdit && !item.done && (me?.role.isSupervisor == true || item.addedBy == me?.id))
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.remove,
                      onPressed: () => onChanged?.call([for (final i in items) if (i.id != item.id) i]),
                    ),
                ],
              ),
            ),
          ),
        if (canEdit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: TextButton.icon(onPressed: add, icon: const Icon(Icons.add, size: 18), label: Text(l10n.addTask)),
            ),
          ),
      ],
    );
  }
}

/// Mark a task done (or not done again) with an optional comment.
class _CompleteDialog extends StatefulWidget {
  const _CompleteDialog({required this.item});

  final ChecklistItem item;

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  late final _comment = TextEditingController(text: widget.item.comment);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    return AlertDialog(
      title: Text(item.text),
      content: TextField(
        controller: _comment,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.commentOptional),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        if (item.done)
          TextButton(
            onPressed: () => Navigator.pop(context, item.complete(done: false, comment: _comment.text.trim())),
            child: Text(l10n.markNotDone),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, item.complete(done: true, comment: _comment.text.trim())),
          child: Text(l10n.markDone),
        ),
      ],
    );
  }
}

/// New tasks for a visit: typed, or picked from the ones used before.
class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.suggestions});

  final List<String> suggestions;

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _texts = <String>[];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addTask),
      content: SizedBox(
        width: 400,
        child: ChecklistEditor(
          texts: _texts,
          suggestions: widget.suggestions,
          autofocus: true,
          onChanged: (t) => setState(() => _texts
            ..clear()
            ..addAll(t)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _texts.isEmpty ? null : () => Navigator.pop(context, List.of(_texts)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Edits a list of task texts before they are saved: a field to type one,
/// chips of the ones entered, and quick choices from [suggestions].
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.texts,
    required this.onChanged,
    this.suggestions = const [],
    this.autofocus = false,
  });

  final List<String> texts;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final bool autofocus;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add(String text) {
    final t = text.trim();
    _input.clear();
    if (t.isEmpty || widget.texts.contains(t)) return;
    widget.onChanged([...widget.texts, t]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestions = widget.suggestions.where((s) => !widget.texts.contains(s)).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _input,
          autofocus: widget.autofocus,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.visitTasksLabel,
            prefixIcon: const Icon(Icons.checklist),
            suffixIcon: IconButton(icon: const Icon(Icons.add), tooltip: l10n.addTask, onPressed: () => _add(_input.text)),
          ),
          onSubmitted: _add,
        ),
        if (widget.texts.isNotEmpty || suggestions.isNotEmpty) const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final t in widget.texts)
              InputChip(
                label: Text(t),
                selected: true,
                showCheckmark: false,
                onDeleted: () => widget.onChanged([for (final x in widget.texts) if (x != t) x]),
              ),
            for (final s in suggestions)
              ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(s), onPressed: () => _add(s)),
          ],
        ),
      ],
    );
  }
}

/// [ChecklistEditor] with the plan owner's recent tasks as suggestions.
class OwnerChecklistEditor extends ConsumerWidget {
  const OwnerChecklistEditor({
    super.key,
    required this.ownerId,
    required this.date,
    required this.texts,
    required this.onChanged,
  });

  final String ownerId;
  final String date;
  final List<String> texts;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ChecklistEditor(
        texts: texts,
        onChanged: onChanged,
        suggestions: _suggestions(ref, ownerId, date, const []),
      );
}
