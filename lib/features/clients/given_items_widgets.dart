import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../users/users_repository.dart';
import '../../l10n/app_localizations.dart';
import 'client.dart';
import 'given_items.dart';
import 'visit_rules.dart';

String givenItemLabel(AppLocalizations l10n, GivenItem item) => switch (item) {
      GivenItem.switchCatalog => l10n.givenSwitchCatalog,
      GivenItem.bookletCatalog => l10n.givenBookletCatalog,
      GivenItem.displayStand => l10n.givenDisplayStand,
      GivenItem.a4Samples => l10n.givenA4Samples,
    };

IconData givenItemIcon(GivenItem item) => switch (item) {
      GivenItem.switchCatalog => Icons.style,
      GivenItem.bookletCatalog => Icons.menu_book,
      GivenItem.displayStand => Icons.view_quilt,
      GivenItem.a4Samples => Icons.content_copy,
    };

Color? _statusColor(GivenStatus s) => switch (s) {
      GivenStatus.due => statusOverdueColor,
      GivenStatus.dueSoon => Colors.orange.shade800,
      GivenStatus.ok => statusRecentColor,
      GivenStatus.never => null,
    };

/// "Last: 2 on 12 Oct 2026 · 5 in all · New one due 10 Apr 2027".
String givenSummary(AppLocalizations l10n, String locale, GivenRecord? r, GivenItem item, GivenItemRules rules) {
  if (r == null || r.at == null) return l10n.givenNever;
  final date = DateFormat.yMMMd(locale);
  return [
    l10n.givenLast(r.qty, date.format(r.at!)),
    if (r.total != r.qty) l10n.givenTotal(r.total),
    l10n.givenDueOn(date.format(givenNextDue(r, item, rules)!)),
  ].join(' · ');
}

/// Client page: what the client got and when a new one is due, every
/// hand-over (visits and recorded ones), and — for whoever may edit the
/// client — recording one by hand, backdated if needed.
class GivenItemsSection extends ConsumerWidget {
  const GivenItemsSection({super.key, required this.client, this.canEdit = false});

  final Client client;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final rules = ref.watch(givenItemRulesProvider).value ?? GivenItemRules.defaults;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final me = ref.watch(currentUserProvider).value;
    final now = DateTime.now();
    final date = DateFormat.yMMMd(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in GivenItem.values)
          Builder(builder: (context) {
            final r = client.given[item];
            final status = givenStatus(r, item, rules, now);
            final color = _statusColor(status);
            return ListTile(
              dense: true,
              leading: Icon(givenItemIcon(item), color: color),
              title: Text(givenItemLabel(l10n, item)),
              subtitle: Text(givenSummary(l10n, locale, r, item, rules)),
              trailing: switch (status) {
                GivenStatus.due => Text(l10n.givenDue, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                GivenStatus.dueSoon => Text(l10n.givenDueSoon, style: TextStyle(color: color)),
                _ => null,
              },
            );
          }),
        if (client.givenLog.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.givenHistory, style: theme.textTheme.labelLarge),
          ),
          for (final e in client.givenLog)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(givenItemIcon(e.item), size: 20),
              title: Text('${e.qty} × ${givenItemLabel(l10n, e.item)}'),
              subtitle: Text([
                date.format(e.at),
                users[e.byId]?.name ?? '',
                e.manual ? l10n.givenRecordedByHand : l10n.givenAtVisit,
              ].where((t) => t.isNotEmpty).join(' · ')),
              // Recorded entries can be removed; visit ones go with the visit.
              trailing: canEdit && e.manual
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.delete,
                      onPressed: () => removeGivenEntries(client.id, (m) => m['id'] == e.id),
                    )
                  : null,
            ),
        ],
        if (canEdit && me != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.givenRecord),
                onPressed: () => showRecordGivenDialog(context, client, me.id),
              ),
            ),
          ),
      ],
    );
  }
}

/// Records a hand-over on the client page: item, quantity and date (today
/// or earlier).
Future<void> showRecordGivenDialog(BuildContext context, Client client, String byId) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final locale = Localizations.localeOf(context).toString();
  final today = DateTime.now();
  var item = GivenItem.values.first;
  var qty = 1;
  var day = DateTime(today.year, today.month, today.day);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => PointerInterceptor(
        child: AlertDialog(
          title: Text(l10n.givenRecord),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in GivenItem.values)
                      ChoiceChip(
                        avatar: Icon(givenItemIcon(i), size: 18),
                        label: Text(givenItemLabel(l10n, i)),
                        selected: item == i,
                        onSelected: (_) => setState(() => item = i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(l10n.quantity)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: qty <= 1 ? null : () => setState(() => qty--),
                    ),
                    SizedBox(width: 32, child: Text('$qty', textAlign: TextAlign.center, style: Theme.of(dialog).textTheme.titleMedium)),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => qty++)),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('${l10n.givenOn}: ${DateFormat.yMMMd(locale).format(day)}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialog,
                      initialDate: day,
                      firstDate: DateTime(2015),
                      lastDate: today,
                    );
                    if (picked != null) setState(() => day = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return;
  try {
    // Midday, so the date reads the same in every time zone nearby.
    await addGivenEntry(
      client.id,
      GivenEntry(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        item: item,
        qty: qty,
        at: DateTime(day.year, day.month, day.day, 12),
        byId: byId,
      ),
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

/// Check-in: how many of each item were handed over (0 = none).
class GivenItemsPicker extends ConsumerWidget {
  const GivenItemsPicker({super.key, required this.client, required this.values, required this.onChanged});

  final Client client;
  final Map<GivenItem, int> values;
  final ValueChanged<Map<GivenItem, int>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final rules = ref.watch(givenItemRulesProvider).value ?? GivenItemRules.defaults;
    final now = DateTime.now();
    void set(GivenItem item, int qty) => onChanged({...values, item: qty.clamp(0, 999)}..removeWhere((_, q) => q == 0));
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(l10n.itemsGiven, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final item in GivenItem.values)
            Builder(builder: (context) {
              final qty = values[item] ?? 0;
              final r = client.given[item];
              final color = _statusColor(givenStatus(r, item, rules, now));
              return ListTile(
                contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                leading: Icon(givenItemIcon(item), color: color),
                title: Text(givenItemLabel(l10n, item)),
                subtitle: Text(givenSummary(l10n, locale, r, item, rules), style: TextStyle(color: color)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: qty == 0 ? null : () => set(item, qty - 1),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('$qty', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => set(item, qty + 1)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// GM / sales manager: after how many days each item should be renewed.
class GivenItemRulesScreen extends ConsumerStatefulWidget {
  const GivenItemRulesScreen({super.key});

  @override
  ConsumerState<GivenItemRulesScreen> createState() => _GivenItemRulesScreenState();
}

class _GivenItemRulesScreenState extends ConsumerState<GivenItemRulesScreen> {
  final _form = GlobalKey<FormState>();
  final _days = {for (final item in GivenItem.values) item: TextEditingController()};
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _days.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await saveGivenItemRules(GivenItemRules({
        for (final item in GivenItem.values) item: int.parse(_days[item]!.text.trim()),
      }));
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
    final rules = ref.watch(givenItemRulesProvider).value;
    if (rules == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_loaded) {
      for (final item in GivenItem.values) {
        _days[item]!.text = '${rules.of(item)}';
      }
      _loaded = true;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.givenItemsSettings)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.givenItemsHelp),
            const SizedBox(height: 16),
            for (final item in GivenItem.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _days[item],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: givenItemLabel(l10n, item),
                    prefixIcon: Icon(givenItemIcon(item)),
                    suffixText: l10n.givenEveryDaysSuffix,
                  ),
                  validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) < 1 ? l10n.invalidNumber : null,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
