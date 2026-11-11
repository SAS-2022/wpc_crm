import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'holidays.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';

/// HR area → Leave types tab: public holidays by name, one year at a time
/// (2026-11-08, user: Eid al-Fitr / Eid al-Adha move every year). Names used
/// in other years are offered for the year shown, with last year's dates
/// as a hint.
class HolidaysSection extends ConsumerStatefulWidget {
  const HolidaysSection({super.key});

  @override
  ConsumerState<HolidaysSection> createState() => _HolidaysSectionState();
}

class _HolidaysSectionState extends ConsumerState<HolidaysSection> {
  int _year = DateTime.now().year;

  Future<void> _edit(HolidayList list, {Holiday? holiday, String? name, String? looseDay}) async {
    final result = await showDialog<Holiday>(
      context: context,
      builder: (_) => _HolidayDialog(
        year: _year,
        holiday: holiday,
        name: name,
        looseDay: looseDay,
        names: {for (final h in list.items) h.name.trim()}.where((n) => n.isNotEmpty).toList(),
        previous: name == null ? null : list.lastOf(name, _year),
      ),
    );
    if (result == null) return;
    await ref.read(leaveRepositoryProvider).saveHolidayList(list.put(result));
  }

  Future<void> _delete(HolidayList list, Holiday h) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.deleteHolidayQ(h.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok == true) await ref.read(leaveRepositoryProvider).saveHolidayList(list.remove(h.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final canEdit = ref.watch(currentUserProvider).value?.can.canManageHr ?? false;
    final list = ref.watch(holidayListProvider).value ?? HolidayList.empty;
    final items = list.ofYear(_year);
    final loose = list.looseOfYear(_year);
    final missing = list.missingNames(_year);
    final f = DateFormat.yMMMEd(locale);
    String range(Holiday h) => h.from == h.to
        ? f.format(DateTime.parse(h.from))
        : '${f.format(DateTime.parse(h.from))} – ${f.format(DateTime.parse(h.to))}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(l10n.publicHolidays, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.publicHolidaysByYearHint, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _year--)),
            Expanded(child: Text('$_year', textAlign: TextAlign.center, style: theme.textTheme.titleSmall)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _year++)),
          ]),
        ),
        if (items.isEmpty && loose.isEmpty)
          ListTile(dense: true, title: Text(l10n.noHolidaysThisYear(_year))),
        for (final h in items)
          ListTile(
            leading: const Icon(Icons.celebration_outlined),
            title: Text(h.name.isEmpty ? l10n.holidayNoName : h.name),
            subtitle: Text('${range(h)} · ${l10n.holidayDays(h.days.length)}'),
            onTap: canEdit ? () => _edit(list, holiday: h) : null,
            trailing: canEdit
                ? IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(list, h),
                  )
                : null,
          ),
        // Days entered before holidays had names: tap to give one a name.
        if (loose.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in loose)
                  InputChip(
                    label: Text('${f.format(DateTime.parse(d))} · ${l10n.holidayNoName}'),
                    onPressed: canEdit ? () => _edit(list, looseDay: d) : null,
                    onDeleted: canEdit
                        ? () => ref.read(leaveRepositoryProvider).saveHolidayList(list.removeLoose(d))
                        : null,
                  ),
              ],
            ),
          ),
        if (canEdit) ...[
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(l10n.holidaysFromOtherYears(_year), style: theme.textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in missing)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(n),
                    onPressed: () => _edit(list, name: n),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addHoliday),
                  onPressed: () => _edit(list),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({
    required this.year,
    required this.names,
    this.holiday,
    this.name,
    this.looseDay,
    this.previous,
  });

  final int year;
  final Holiday? holiday;

  /// A name to add for [year] (from another year).
  final String? name;

  /// An unnamed day being given a name.
  final String? looseDay;
  final List<String> names;

  /// The same holiday in an earlier year (its dates shown as a hint).
  final Holiday? previous;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  late final _name = TextEditingController(text: widget.holiday?.name ?? widget.name ?? '');
  DateTimeRange? _dates;

  @override
  void initState() {
    super.initState();
    final h = widget.holiday;
    if (h != null) {
      _dates = DateTimeRange(start: DateTime.parse(h.from), end: DateTime.parse(h.to));
    } else if (widget.looseDay != null) {
      final d = DateTime.parse(widget.looseDay!);
      _dates = DateTimeRange(start: d, end: d);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    final f = DateFormat.yMMMEd(locale);
    final suggestions = {...widget.names, ...?holidayNameSuggestions[lang]}.toList();
    final prev = widget.previous;
    final days = _dates == null ? 0 : _dates!.end.difference(_dates!.start).inDays + 1;
    return AlertDialog(
      title: Text(widget.holiday == null ? l10n.addHoliday : l10n.editHoliday),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Autocomplete<String>(
              initialValue: _name.value,
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                return suggestions.where((s) => q.isEmpty || s.toLowerCase().contains(q));
              },
              onSelected: (v) => setState(() => _name.text = v),
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                controller: controller,
                focusNode: focus,
                decoration: InputDecoration(labelText: l10n.holidayName),
                onChanged: (v) => setState(() => _name.text = v),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(_dates == null
                  ? l10n.pastLeavePickDates
                  : _dates!.start == _dates!.end
                      ? f.format(_dates!.start)
                      : '${f.format(_dates!.start)} – ${f.format(_dates!.end)}'),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: _dates,
                  // Any year: past holidays too, and next year's once announced.
                  firstDate: DateTime(widget.year - 10),
                  lastDate: DateTime(widget.year + 2, 12, 31),
                  currentDate: DateTime(widget.year, DateTime.now().month, DateTime.now().day),
                );
                if (picked != null) setState(() => _dates = picked);
              },
            ),
            if (days > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.holidayDays(days), style: Theme.of(context).textTheme.bodySmall),
              ),
            if (prev != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.holidayLastTime(prev.year,
                      prev.from == prev.to ? f.format(DateTime.parse(prev.from)) : '${f.format(DateTime.parse(prev.from))} – ${f.format(DateTime.parse(prev.to))}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _dates == null || _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    Holiday(
                      id: widget.holiday?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                      name: _name.text.trim(),
                      from: leaveDayKey(_dates!.start),
                      to: leaveDayKey(_dates!.end),
                    ),
                  ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
