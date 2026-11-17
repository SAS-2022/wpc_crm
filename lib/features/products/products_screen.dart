import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'product.dart';
import 'product_widgets.dart';
import 'products_repository.dart';

/// Products (2026-11-17): the collection by decor, with prices, plus the
/// accessories. The sales team, SM and GM.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';
  ProductType? _type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final all = ref.watch(productsProvider).value;
    final products = [
      for (final p in all ?? const <Product>[])
        if ((_type == null || p.type == _type) && productMatches(p, _query)) p,
    ];
    final decors = decorsOf(products);
    final loose = [for (final p in products) if (p.decor.isEmpty) p];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products),
        actions: [
          if (me?.can.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: l10n.importProducts,
              onPressed: () => context.push('/import/products'),
            ),
        ],
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.searchProducts,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(label: Text(l10n.statusAll), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
                      for (final t in ProductType.values)
                        ChoiceChip(
                          avatar: Icon(productTypeIcon(t), size: 18),
                          label: Text(productTypeLabel(l10n, t)),
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = _type == t ? null : t),
                        ),
                    ],
                  ),
                ),
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l10n.noProductsYet, textAlign: TextAlign.center),
                  ),
                for (final d in decors)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: CircleAvatar(child: Text(d.code.split(' ').first, style: theme.textTheme.labelSmall)),
                      title: Text(d.label),
                      subtitle: Text(l10n.productsCount(d.products.length)),
                      children: [for (final p in d.products) _ProductTile(product: p)],
                    ),
                  ),
                if (loose.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: const CircleAvatar(child: Icon(Icons.handyman_outlined)),
                      title: Text(l10n.productsWithoutDecor),
                      subtitle: Text(l10n.productsCount(loose.length)),
                      children: [for (final p in loose) _ProductTile(product: p)],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(productTypeIcon(product.type), size: 20),
        title: Text(product.name),
        subtitle: Text([productLine(context, product), if (product.ref.isNotEmpty) product.ref].join(' · ')),
      );
}
