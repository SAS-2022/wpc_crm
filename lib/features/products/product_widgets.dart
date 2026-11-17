import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'product.dart';
import 'products_repository.dart';

String productTypeLabel(AppLocalizations l10n, ProductType t) => switch (t) {
      ProductType.panel => l10n.productPanels,
      ProductType.edgeBand => l10n.productEdgeBands,
      ProductType.laminate => l10n.productLaminates,
      ProductType.sample => l10n.productSamples,
      ProductType.accessory => l10n.productAccessories,
    };

IconData productTypeIcon(ProductType t) => switch (t) {
      ProductType.panel => Icons.view_agenda_outlined,
      ProductType.edgeBand => Icons.straighten,
      ProductType.laminate => Icons.layers_outlined,
      ProductType.sample => Icons.inventory_2_outlined,
      ProductType.accessory => Icons.handyman_outlined,
    };

/// "285 SAR / Pnl"; '' without a price.
String productPrice(BuildContext context, Product p) {
  if (p.price == null) return '';
  final n = NumberFormat.decimalPatternDigits(locale: Localizations.localeOf(context).toLanguageTag(), decimalDigits: p.price! % 1 == 0 ? 0 : 2)
      .format(p.price);
  return p.unit.isEmpty ? '$n SAR' : '$n SAR / ${p.unit}';
}

/// One line about a product: type, board, size, price.
String productLine(BuildContext context, Product p) => [
      productTypeLabel(AppLocalizations.of(context), p.type),
      if (p.board.isNotEmpty && p.board != 'PVC' && p.board != 'ABS' && p.board != 'HPL') p.board,
      if (p.size.isNotEmpty) p.size,
      productPrice(context, p),
    ].where((s) => s.isNotEmpty).join(' · ');

/// A material on a project: the decor, and the product when one was picked.
String materialLabel(Map<String, Decor> decors, Map<String, Product> products, String decorKey, String productId, String removed) {
  final d = decors[decorKey];
  final p = productId.isEmpty ? null : products[productId];
  final base = d?.label ?? (decorKey.isEmpty ? '' : decorKey);
  if (p != null) return base.isEmpty ? p.name : '$base — ${p.name}';
  return base.isEmpty ? removed : base;
}

/// Picks a decor and, optionally, one of its products. Returns (decor key,
/// product id or '') or null. [sampleFirst]: sample products listed first
/// and the first sample preselected (recording samples).
Future<(String, String)?> showDecorPicker(BuildContext context, {bool sampleFirst = false, String? initialDecor}) =>
    showDialog<(String, String)>(
      context: context,
      builder: (_) => _DecorPickerDialog(sampleFirst: sampleFirst, initialDecor: initialDecor),
    );

class _DecorPickerDialog extends ConsumerStatefulWidget {
  const _DecorPickerDialog({required this.sampleFirst, this.initialDecor});

  final bool sampleFirst;
  final String? initialDecor;

  @override
  ConsumerState<_DecorPickerDialog> createState() => _DecorPickerDialogState();
}

class _DecorPickerDialogState extends ConsumerState<_DecorPickerDialog> {
  String _query = '';
  late String? _decor = widget.initialDecor;
  String _product = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final decors = ref.watch(decorsProvider);
    final picked = _decor == null ? null : ref.watch(decorsByKeyProvider)[_decor];

    if (picked == null) {
      final shown = [for (final d in decors) if (decorMatches(d, _query)) d];
      return AlertDialog(
        title: Text(l10n.chooseDecor),
        content: SizedBox(
          width: 480,
          height: 520,
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchDecors),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: decors.isEmpty
                    ? Center(child: Text(l10n.noProductsYet, textAlign: TextAlign.center))
                    : ListView(
                        children: [
                          for (final d in shown)
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(radius: 16, child: Text(d.code.split(' ').first, style: theme.textTheme.labelSmall)),
                              title: Text(d.label),
                              subtitle: Text(l10n.productsCount(d.products.length)),
                              onTap: () => setState(() {
                                _decor = d.key;
                                final samples = d.products.where((p) => p.type == ProductType.sample);
                                _product = widget.sampleFirst && samples.isNotEmpty ? samples.first.id : '';
                              }),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel))],
      );
    }

    final products = [...picked.products];
    if (widget.sampleFirst) {
      products.sort((a, b) => (a.type == ProductType.sample ? 0 : 1).compareTo(b.type == ProductType.sample ? 0 : 1));
    }
    return AlertDialog(
      title: Text(picked.label),
      content: SizedBox(
        width: 480,
        height: 520,
        child: ListView(
          children: [
            RadioGroup<String>(
              groupValue: _product,
              onChanged: (v) => setState(() => _product = v ?? ''),
              child: Column(
                children: [
                  RadioListTile<String>(dense: true, value: '', title: Text(l10n.anyProductOfDecor)),
                  for (final p in products)
                    RadioListTile<String>(
                      dense: true,
                      value: p.id,
                      title: Text(p.name),
                      subtitle: Text(productLine(context, p)),
                      secondary: Icon(productTypeIcon(p.type), size: 20),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => setState(() => _decor = null), child: Text(l10n.otherDecor)),
        FilledButton(onPressed: () => Navigator.pop(context, (picked.key, _product)), child: Text(l10n.done)),
      ],
    );
  }
}
