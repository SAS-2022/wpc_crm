import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../import/import_service.dart';
import 'product.dart';
import 'product_widgets.dart';
import 'products_repository.dart';

/// Settings → Import → Products (2026-11-17): the Odoo "Product Variant"
/// export (CSV / Excel) → preview → save. SM / GM.
class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key});

  @override
  ConsumerState<ProductImportScreen> createState() => _ProductImportScreenState();
}

class _ProductImportScreenState extends ConsumerState<ProductImportScreen> {
  String _fileName = '';
  ProductPlan? _plan;
  List<ProductRow> _rows = const [];
  String? _error;
  bool _reading = false;
  bool _committing = false;

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'csv']);
    if (files.isEmpty) return;
    final file = files.first;
    setState(() {
      _reading = true;
      _error = null;
      _plan = null;
    });
    try {
      final rows = parseProductTable(readTable(file.name, await file.readAsBytes()));
      final existing = await ref.read(productsProvider.future).timeout(const Duration(seconds: 60));
      setState(() {
        _fileName = file.name;
        _rows = rows;
        _plan = buildProductPlan(rows, existing);
      });
    } catch (e) {
      setState(() => _error = l10n.errorWithMessage('$e'));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context);
    final plan = _plan!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _committing = true;
      _error = null;
    });
    try {
      await commitProductImport(plan, fileName: _fileName, importedBy: ref.read(currentUserProvider).value!.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.productImportDone(plan.creates.length, plan.updates.length))));
      router.go('/products');
    } catch (e) {
      setState(() => _error = l10n.errorWithMessage('$e'));
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the products live while open (paused providers would never answer).
    ref.watch(productsProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = _plan;
    final kept = _rows.where((r) => !r.excluded).map((r) => r.product).toList();
    final decors = decorsOf(kept);
    final hasRef = _rows.any((r) => r.product.ref.isNotEmpty);

    Widget list(String title, List<String> lines, {IconData icon = Icons.list, Color? color}) => lines.isEmpty
        ? const SizedBox.shrink()
        : Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: Icon(icon, color: color),
              title: Text('$title (${lines.length})'),
              children: [
                for (final l in lines.take(300)) ListTile(dense: true, title: Text(l)),
                if (lines.length > 300) ListTile(dense: true, title: Text('+${lines.length - 300}')),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importProducts)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.productImportHelp, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reading || _committing ? null : _pick,
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName.isEmpty ? l10n.importPickFile : _fileName),
          ),
          if (_reading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (plan != null) ...[
            const SizedBox(height: 16),
            if (!hasRef)
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: ListTile(leading: const Icon(Icons.info_outline), title: Text(l10n.productImportNoRef)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(avatar: const Icon(Icons.add, size: 18), label: Text(l10n.productImportNew(plan.creates.length))),
                Chip(avatar: const Icon(Icons.edit, size: 18), label: Text(l10n.productImportUpdated(plan.updates.length))),
                Chip(label: Text(l10n.productImportUnchanged(plan.unchanged))),
                Chip(avatar: const Icon(Icons.palette_outlined, size: 18), label: Text(l10n.decorsCount(decors.length))),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ProductType.values)
                  Chip(
                    avatar: Icon(productTypeIcon(t), size: 18),
                    label: Text('${productTypeLabel(l10n, t)}: ${kept.where((p) => p.type == t).length}'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            list(l10n.productImportNewList, [for (final p in plan.creates) p.name], icon: Icons.add),
            list(l10n.productImportUpdatedList, [
              for (final u in plan.updates) '${u.product.name} — ${u.changes.keys.where((k) => k != 'nameKey').join(', ')}',
            ], icon: Icons.edit),
            list(l10n.productImportExcluded, [for (final p in plan.excluded) p.name], icon: Icons.block, color: theme.colorScheme.error),
            list(l10n.productImportDuplicates, [for (final p in plan.duplicates) p.name], icon: Icons.copy_all),
            list(l10n.productImportNotInFile, [for (final p in plan.notInFile) p.name], icon: Icons.inventory_2_outlined),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _committing || (plan.creates.isEmpty && plan.updates.isEmpty) ? null : _commit,
              icon: const Icon(Icons.cloud_upload),
              label: BusyLabel(busy: _committing, child: Text(l10n.productImportSave(plan.creates.length + plan.updates.length))),
            ),
          ],
        ],
      ),
    );
  }
}
