import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'hr_actions.dart';
import 'hr_actions_repository.dart';
import 'payroll.dart';
import 'payroll_repository.dart';

// Payroll (2026-11-07): the month's salaries of every active employee, with
// the deductions / rewards of that payroll month (Warnings & deductions).
// Only for [canSeePayroll].

/// HR area tab "Payroll".
class PayrollTab extends ConsumerStatefulWidget {
  const PayrollTab({super.key});

  @override
  ConsumerState<PayrollTab> createState() => _PayrollTabState();
}

class _PayrollTabState extends ConsumerState<PayrollTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    if (!canSeePayroll(me)) return Center(child: Text(l10n.noAccess));
    final salaries = ref.watch(salariesProvider);
    final actions = ref.watch(allHrActionsProvider).value ?? const <HrAction>[];
    final monthKey = DateFormat('yyyy-MM').format(_month);
    final people = [
      for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
        if (u.active && (_search.isEmpty || searchHas(u.name, _search))) u,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final map = salaries.value ?? const <String, SalaryStructure>{};
    final rows = [
      for (final u in people)
        (user: u, salary: map[u.id] ?? SalaryStructure.empty, slip: payslipFor(map[u.id] ?? SalaryStructure.empty, actions, u.id, monthKey)),
    ];
    final withSalary = rows.where((r) => r.salary.isSet).toList();
    double total(double Function(({AppUser user, SalaryStructure salary, Payslip slip}) r) f) =>
        withSalary.fold(0.0, (a, r) => a + f(r));
    final money = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
    String m(double v) => v == 0 ? '–' : money.format(v);
    final bold = const TextStyle(fontWeight: FontWeight.w600);

    DataCell num(double v, {TextStyle? style}) => DataCell(Text(m(v), style: style));
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Text(DateFormat.yMMMM(locale).format(_month), style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchEmployee,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _Tile(label: l10n.payrollEmployees, value: '${withSalary.length} / ${rows.length}'),
            _Tile(label: l10n.payrollGross, value: money.format(total((r) => r.slip.gross))),
            _Tile(label: l10n.payrollDeductions, value: money.format(total((r) => r.slip.deductions)), color: theme.colorScheme.error),
            _Tile(label: l10n.payrollRewards, value: money.format(total((r) => r.slip.rewards)), color: Colors.green.shade700),
            _Tile(label: l10n.payrollNet, value: money.format(total((r) => r.slip.net)), bold: true),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(l10n.payrollHint, style: theme.textTheme.bodySmall),
        ),
        if (salaries.isLoading && !salaries.hasValue)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 20,
            headingTextStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            columns: [
              DataColumn(label: Text(l10n.employee)),
              DataColumn(label: Text(l10n.salaryBasic), numeric: true),
              DataColumn(label: Text(l10n.salaryHousing), numeric: true),
              DataColumn(label: Text(l10n.salaryTransport), numeric: true),
              DataColumn(label: Text(l10n.salaryOther), numeric: true),
              DataColumn(label: Text(l10n.payrollGross), numeric: true),
              DataColumn(label: Text(l10n.payrollDeductions), numeric: true),
              DataColumn(label: Text(l10n.payrollRewards), numeric: true),
              DataColumn(label: Text(l10n.payrollNet), numeric: true),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  onSelectChanged: (_) => showSalaryDialog(context, ref, r.user, r.salary),
                  cells: [
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.user.name),
                        if (!r.salary.isSet)
                          Text(l10n.salaryNotSet, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                      ],
                    )),
                    num(r.salary.basic),
                    num(r.salary.housing),
                    num(r.salary.transport),
                    DataCell(Tooltip(
                      message: [for (final o in r.salary.others) '${o.name}: ${money.format(o.amount)}'].join('\n'),
                      child: Text(m(r.salary.otherTotal)),
                    )),
                    num(r.slip.gross),
                    num(r.slip.deductions, style: TextStyle(color: theme.colorScheme.error)),
                    num(r.slip.rewards, style: TextStyle(color: Colors.green.shade700)),
                    num(r.slip.net, style: bold),
                  ],
                ),
              if (withSalary.isNotEmpty)
                DataRow(
                  color: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest),
                  cells: [
                    DataCell(Text(l10n.total, style: bold)),
                    num(total((r) => r.salary.basic), style: bold),
                    num(total((r) => r.salary.housing), style: bold),
                    num(total((r) => r.salary.transport), style: bold),
                    num(total((r) => r.salary.otherTotal), style: bold),
                    num(total((r) => r.slip.gross), style: bold),
                    num(total((r) => r.slip.deductions), style: bold),
                    num(total((r) => r.slip.rewards), style: bold),
                    num(total((r) => r.slip.net), style: bold),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.color, this.bold = false});

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: bold ? FontWeight.w700 : null)),
      ]),
    );
  }
}

/// Employee page: the person's salary (payroll account only).
class PersonSalaryCard extends ConsumerWidget {
  const PersonSalaryCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canSeePayroll(ref.watch(currentUserProvider).value)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final money = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
    final s = ref.watch(salariesProvider).value?[user.id] ?? SalaryStructure.empty;
    Widget line(String label, double v, {bool bold = false, bool locked = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null)),
            if (locked)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Tooltip(message: l10n.salaryFromContract, child: const Icon(Icons.lock_outline, size: 14)),
              ),
            Text(money.format(v), style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null),
          ]),
        );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: InkWell(
        onTap: () => showSalaryDialog(context, ref, user, s),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.payments_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.salary, style: theme.textTheme.titleMedium)),
              const Icon(Icons.edit_outlined, size: 18),
            ]),
            const SizedBox(height: 8),
            if (!s.isSet)
              Text(l10n.salaryNotSet, style: TextStyle(color: theme.colorScheme.error))
            else ...[
              line(l10n.salaryBasic, s.basic, locked: s.isLocked('basic')),
              line(l10n.salaryHousing, s.housing, locked: s.isLocked('housing')),
              line(l10n.salaryTransport, s.transport, locked: s.isLocked('transport')),
              for (final o in s.others) line(o.name, o.amount, locked: s.isLocked('others')),
              const Divider(),
              line(l10n.payrollGross, s.monthly, bold: true),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Edits [user]'s salary: basic, home allowance, transportation and any
/// number of named other allowances (names used for others are suggested).
Future<void> showSalaryDialog(BuildContext context, WidgetRef ref, AppUser user, SalaryStructure current) async {
  final me = ref.read(currentUserProvider).value;
  if (!canSeePayroll(me)) return;
  final names = <String>{
    for (final s in ref.read(salariesProvider).value?.values ?? const <SalaryStructure>[])
      for (final o in s.others) o.name,
  }.toList()
    ..sort();
  final result = await showDialog<SalaryStructure>(
    context: context,
    builder: (_) => _SalaryDialog(name: user.name, current: current, suggestions: names),
  );
  if (result == null) return;
  await ref.read(payrollRepositoryProvider).save(user.id, result, me!.id);
}

class _SalaryDialog extends StatefulWidget {
  const _SalaryDialog({required this.name, required this.current, required this.suggestions});

  final String name;
  final SalaryStructure current;
  final List<String> suggestions;

  @override
  State<_SalaryDialog> createState() => _SalaryDialogState();
}

class _SalaryDialogState extends State<_SalaryDialog> {
  late final _basic = TextEditingController(text: _text(widget.current.basic));
  late final _housing = TextEditingController(text: _text(widget.current.housing));
  late final _transport = TextEditingController(text: _text(widget.current.transport));
  late final List<(TextEditingController, TextEditingController, FocusNode)> _others = [
    for (final o in widget.current.others) _row(o.name, _text(o.amount)),
  ];

  static (TextEditingController, TextEditingController, FocusNode) _row([String name = '', String amount = '']) =>
      (TextEditingController(text: name), TextEditingController(text: amount), FocusNode());

  static String _text(double v) => v == 0 ? '' : formatAmount(v);
  static double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  @override
  void dispose() {
    for (final c in [_basic, _housing, _transport, for (final o in _others) ...[o.$1, o.$2]]) {
      c.dispose();
    }
    for (final o in _others) {
      o.$3.dispose();
    }
    super.dispose();
  }

  /// From the employment contract: changed only by uploading a new one.
  bool _locked(String part) => widget.current.isLocked(part);

  SalaryStructure get _value {
    final c = widget.current;
    return SalaryStructure(
      basic: _locked('basic') ? c.basic : _num(_basic),
      housing: _locked('housing') ? c.housing : _num(_housing),
      transport: _locked('transport') ? c.transport : _num(_transport),
      others: _locked('others')
          ? c.others
          : [
              for (final o in _others)
                if (o.$1.text.trim().isNotEmpty && _num(o.$2) != 0) OtherAllowance(name: o.$1.text.trim(), amount: _num(o.$2)),
            ],
      contractFields: c.contractFields,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final money = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
    const numbers = TextInputType.numberWithOptions(decimal: true);
    final lockIcon = Tooltip(message: l10n.salaryFromContract, child: const Icon(Icons.lock_outline, size: 18));
    Widget field(TextEditingController c, String label, String part) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: numbers,
            enabled: !_locked(part),
            decoration: InputDecoration(labelText: label, suffixText: l10n.sar, suffixIcon: _locked(part) ? lockIcon : null),
            onChanged: (_) => setState(() {}),
          ),
        );
    final othersLocked = _locked('others');
    return AlertDialog(
      title: Text(l10n.salaryOf(widget.name)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.current.contractFields.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    const Icon(Icons.lock_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.salaryLockedHint, style: theme.textTheme.bodySmall)),
                  ]),
                ),
              field(_basic, l10n.salaryBasic, 'basic'),
              field(_housing, l10n.salaryHousing, 'housing'),
              field(_transport, l10n.salaryTransport, 'transport'),
              Row(children: [
                Expanded(child: Text(l10n.salaryOther, style: theme.textTheme.titleSmall)),
                if (othersLocked) lockIcon,
              ]),
              const SizedBox(height: 8),
              if (othersLocked)
                for (final o in widget.current.others)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [Expanded(child: Text(o.name)), Text('${money.format(o.amount)} ${l10n.sar}')]),
                  ),
              if (!othersLocked)
                for (final (i, o) in _others.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        // Names used on other salaries are offered as you type.
                        child: RawAutocomplete<String>(
                          textEditingController: o.$1,
                          focusNode: o.$3,
                          optionsBuilder: (v) => widget.suggestions
                              .where((s) => s != v.text && searchHas(s, v.text))
                              .take(8),
                          fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                            controller: controller,
                            focusNode: focus,
                            decoration: InputDecoration(isDense: true, labelText: l10n.allowanceName),
                          ),
                          optionsViewBuilder: (context, onSelected, options) => Align(
                            alignment: AlignmentDirectional.topStart,
                            child: Material(
                              elevation: 4,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 240),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: [
                                    for (final s in options) ListTile(dense: true, title: Text(s), onTap: () => onSelected(s)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: o.$2,
                          keyboardType: numbers,
                          decoration: InputDecoration(isDense: true, labelText: l10n.amountSarLabel),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: l10n.delete,
                        onPressed: () => setState(() {
                          final removed = _others.removeAt(i);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            removed.$1.dispose();
                            removed.$2.dispose();
                            removed.$3.dispose();
                          });
                        }),
                      ),
                    ]),
                  ),
              if (!othersLocked)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _others.add(_row())),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addAllowance),
                  ),
                ),
              const Divider(),
              Row(children: [
                Expanded(child: Text(l10n.payrollGross, style: theme.textTheme.titleSmall)),
                Text('${money.format(_value.monthly)} ${l10n.sar}', style: theme.textTheme.titleSmall),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _value), child: Text(l10n.save)),
      ],
    );
  }
}
