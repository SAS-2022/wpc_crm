import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'visit_rules.dart';

/// GM / sales manager: how many days each category stays green and yellow.
class VisitRulesScreen extends ConsumerStatefulWidget {
  const VisitRulesScreen({super.key});

  @override
  ConsumerState<VisitRulesScreen> createState() => _VisitRulesScreenState();
}

class _VisitRulesScreenState extends ConsumerState<VisitRulesScreen> {
  final _form = GlobalKey<FormState>();
  final _green = {for (final c in clientCategories) c: TextEditingController()};
  final _yellow = {for (final c in clientCategories) c: TextEditingController()};
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [..._green.values, ..._yellow.values]) {
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
      await saveVisitRules(VisitRules({
        for (final c in clientCategories)
          c: CategoryRule(int.parse(_green[c]!.text.trim()), int.parse(_yellow[c]!.text.trim())),
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
    final rules = ref.watch(visitRulesProvider).value;
    if (rules == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_loaded) {
      for (final c in clientCategories) {
        _green[c]!.text = '${rules.of(c).greenDays}';
        _yellow[c]!.text = '${rules.of(c).yellowDays}';
      }
      _loaded = true;
    }
    String? days(String? v) => (int.tryParse(v?.trim() ?? '') ?? 0) < 1 ? l10n.invalidNumber : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.visitFrequency)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.visitFrequencyHelp),
            const SizedBox(height: 16),
            for (final c in clientCategories)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.categoryName(c), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _green[c],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.greenUpTo,
                                prefixIcon: const Icon(Icons.circle, color: statusRecentColor, size: 14),
                              ),
                              validator: days,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _yellow[c],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.yellowUpTo,
                                prefixIcon: const Icon(Icons.circle, color: statusDueSoonColor, size: 14),
                              ),
                              validator: (v) {
                                final error = days(v);
                                if (error != null) return error;
                                final green = int.tryParse(_green[c]!.text.trim()) ?? 0;
                                return int.parse(v!.trim()) <= green ? l10n.yellowAfterGreen : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.circle, color: statusOverdueColor, size: 14),
                        const SizedBox(width: 6),
                        Text(l10n.redAfter, style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
