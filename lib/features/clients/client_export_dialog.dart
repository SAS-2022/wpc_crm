import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/save_file.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'client_export.dart';
import 'client_tags.dart';
import 'visit_rules.dart';

const _prefsKey = 'clientExportFields';

/// Web only: lets the user tick the columns (remembered in this browser),
/// then downloads [clients] as an Excel file.
Future<void> showClientExportDialog(BuildContext context, WidgetRef ref, List<Client> clients) async {
  List<String>? saved;
  try {
    saved = (await SharedPreferences.getInstance()).getStringList(_prefsKey);
  } catch (_) {}
  if (!context.mounted) return;
  final initial = saved == null ? ExportField.values.toSet() : ExportField.fromIds(saved).toSet();
  final fields = await showDialog<List<ExportField>>(
    context: context,
    builder: (_) => _ExportDialog(count: clients.length, initial: initial),
  );
  if (fields == null || fields.isEmpty || !context.mounted) return;
  try {
    await (await SharedPreferences.getInstance()).setStringList(_prefsKey, [for (final f in fields) f.id]);
  } catch (_) {}
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();
  final bytes = buildClientsXlsx(
    clients,
    fields,
    ClientExportContext(
      l10n: l10n,
      languageCode: Localizations.localeOf(context).languageCode,
      userNames: {for (final u in ref.read(usersProvider).value ?? const []) u.id: u.name},
      tags: ref.read(clientTagsByIdProvider),
      rules: ref.read(visitRulesProvider).value ?? VisitRules.defaults,
      now: now,
    ),
  );
  saveBytes(
    bytes,
    'clients_${DateFormat('yyyy-MM-dd').format(now)}.xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.count, required this.initial});

  final int count;
  final Set<ExportField> initial;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late final Set<ExportField> _fields = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.exportClientsTitle),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.exportClientsBody(widget.count)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _fields.addAll(ExportField.values)),
                  child: Text(l10n.selectAll),
                ),
                TextButton(onPressed: () => setState(_fields.clear), child: Text(l10n.exportSelectNone)),
                const Spacer(),
                Text(l10n.exportColumnsCount(_fields.length, ExportField.values.length)),
              ],
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  children: [
                    for (final f in ExportField.values)
                      SizedBox(
                        width: 270,
                        child: CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(f.label(l10n)),
                          value: _fields.contains(f),
                          onChanged: (v) => setState(() => v == true ? _fields.add(f) : _fields.remove(f)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton.icon(
          onPressed: _fields.isEmpty || widget.count == 0
              ? null
              : () => Navigator.pop(context, [for (final f in ExportField.values) if (_fields.contains(f)) f]),
          icon: const Icon(Icons.download),
          label: Text(l10n.exportButton),
        ),
      ],
    );
  }
}
