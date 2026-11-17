import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/search_text.dart';

// Products (2026-11-17, user): imported from the Odoo export "Product
// Variant (product.product)" (CSV / Excel) at Settings → Import → Products.
// Our collection is organised by DECOR = the Odoo "Color Code" (+ "Color"),
// e.g. "139 · Beige"; each decor has products: panels (SW / RS / ZH / CL / GZ
// boards: MFC, MDF, …), edge bands (PVC / ABS), laminates (HPL) and samples.
// Rows without a colour code are accessories. Machines / test items are left
// out. Prices are imported (the whole sales team sees them); stock and
// Total Value (cost) are not. Firestore `products/{id}`: name, nameKey,
// ref (Odoo Internal Reference when the export has it), decor (key, '' =
// none), decorCode, color, type, board, size, unit, price?, source 'odoo',
// importBatchId, createdAt, updatedAt. Matched by ref, else by nameKey.
// Projects pick a decor (`ProjectMaterial.materialId` = decor key) and
// optionally one product (`productId`).

enum ProductType { panel, edgeBand, laminate, sample, accessory }

ProductType productTypeOf(Object? v) => ProductType.values.asNameMap()['$v'] ?? ProductType.accessory;

/// Spaces collapsed and trimmed (names in the export have stray spaces).
String cleanProductName(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Matching key: [cleanProductName] lower case.
String productNameKey(String s) => cleanProductName(s).toLowerCase();

/// Decor key of an Odoo colour code ("044 Naturel" → "044 NATUREL"); '' when
/// it isn't a decor code (no digit: "Accessories", "Pallet", "Samples", …).
String decorKeyOf(String code) {
  final c = cleanProductName(code).toUpperCase();
  return RegExp(r'\d').hasMatch(c) ? c : '';
}

const _panelPrefixes = {'SW', 'RS', 'ZH', 'CL', 'GZ'};

ProductType classifyProduct(String name) {
  final n = cleanProductName(name).toUpperCase();
  if (RegExp(r'\bSMPL\b').hasMatch(n) || n == 'SAMPLES') return ProductType.sample;
  final first = n.split(' ').first;
  if (first == 'PVC' || first == 'ABS') return ProductType.edgeBand;
  if (first == 'HPL') return ProductType.laminate;
  if (_panelPrefixes.contains(first)) return ProductType.panel;
  return ProductType.accessory;
}

/// Board / material named in a product name (MFC, MDF, Microlam …); '' if none.
String boardOf(String name) {
  final n = ' ${cleanProductName(name).toUpperCase()} ';
  for (final (key, label) in const [
    ('MICROLAM PAPER', 'Microlam Paper'),
    ('MICROLAM', 'Microlam'),
    ('PAINTED MDF', 'Painted MDF'),
    ('MFC MR', 'MFC MR'),
    ('MFC', 'MFC'),
    ('MDF', 'MDF'),
    ('ACOUSTIC', 'Acoustic'),
    ('PVC', 'PVC'),
    ('ABS', 'ABS'),
    ('HPL', 'HPL'),
  ]) {
    if (n.contains(' $key ')) return label;
  }
  return '';
}

/// The size in a product name, e.g. "280*210*18" or "1.0*22"; '' if none.
String sizeOf(String name) {
  final matches = RegExp(r'\d+(?:\.\d+)?(?:\*\d*(?:\.\d+)?)+').allMatches(name).toList();
  if (matches.isEmpty) return '';
  return matches.last.group(0)!.replaceAll(RegExp(r'\*+$'), '');
}

/// Machines and test items: not products we sell (user 2026-11-17).
bool isExcludedProduct(String name) {
  final n = cleanProductName(name).toLowerCase();
  return RegExp(r'\b(machine|bander|saw|compressor|dust collector|drill|drilling)\b').hasMatch(n) ||
      RegExp(r'\(mc[a-z0-9-]+\)').hasMatch(n) ||
      n.startsWith('test ');
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.ref = '',
    this.decor = '',
    this.decorCode = '',
    this.color = '',
    this.type = ProductType.accessory,
    this.board = '',
    this.size = '',
    this.unit = '',
    this.price,
  });

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Product(
      id: doc.id,
      name: d['name'] as String? ?? '',
      ref: d['ref'] as String? ?? '',
      decor: d['decor'] as String? ?? '',
      decorCode: d['decorCode'] as String? ?? '',
      color: d['color'] as String? ?? '',
      type: productTypeOf(d['type']),
      board: d['board'] as String? ?? '',
      size: d['size'] as String? ?? '',
      unit: d['unit'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;
  final String ref;

  /// Decor key ([decorKeyOf]); '' = not part of a decor (accessories).
  final String decor;

  /// The colour code as Odoo has it ("044 Naturel").
  final String decorCode;
  final String color;
  final ProductType type;
  final String board;
  final String size;
  final String unit;
  final double? price;

  String get nameKey => productNameKey(name);

  /// The fields an import writes (and compares).
  Map<String, Object?> get fields => {
        'name': name,
        'nameKey': nameKey,
        'ref': ref,
        'decor': decor,
        'decorCode': decorCode,
        'color': color,
        'type': type.name,
        'board': board,
        'size': size,
        'unit': unit,
        'price': price,
      };
}

/// A decor of the collection with its products.
class Decor {
  const Decor({required this.key, required this.code, required this.color, required this.products});

  final String key;
  final String code;
  final String color;
  final List<Product> products;

  String get label => color.isEmpty ? code : '$code · $color';
}

/// Decors (sorted by code, numbers first) from the products.
List<Decor> decorsOf(Iterable<Product> products) {
  final by = <String, List<Product>>{};
  for (final p in products) {
    if (p.decor.isEmpty) continue;
    by.putIfAbsent(p.decor, () => []).add(p);
  }
  final list = [
    for (final e in by.entries)
      Decor(
        key: e.key,
        code: e.value.first.decorCode.isEmpty ? e.key : e.value.first.decorCode,
        color: e.value.map((p) => p.color).firstWhere((c) => c.isNotEmpty, orElse: () => ''),
        products: [...e.value]..sort(compareProducts),
      ),
  ];
  list.sort((a, b) => _codeOrder(a.key, b.key));
  return list;
}

/// "002" < "017" < "2028 G" < "AF10" < "RS 008": leading numbers by value.
int _codeOrder(String a, String b) {
  final na = int.tryParse(RegExp(r'^\d+').stringMatch(a) ?? '');
  final nb = int.tryParse(RegExp(r'^\d+').stringMatch(b) ?? '');
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  if (na != null && nb == null) return -1;
  if (na == null && nb != null) return 1;
  return a.compareTo(b);
}

/// Panels, edge bands, laminates, samples, accessories; then by name.
int compareProducts(Product a, Product b) {
  final t = a.type.index.compareTo(b.type.index);
  return t != 0 ? t : a.name.compareTo(b.name);
}

bool decorMatches(Decor d, String query) =>
    query.trim().isEmpty || searchHas(d.code, query) || searchHas(d.color, query) || d.products.any((p) => searchHas(p.name, query));

bool productMatches(Product p, String query) =>
    query.trim().isEmpty || searchHas(p.name, query) || searchHas(p.color, query) || searchHas(p.decorCode, query) || searchHas(p.ref, query);

// ---------------------------------------------------------------- import

class ProductParseException implements Exception {
  const ProductParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A product row of the export (machines / test items already flagged).
class ProductRow {
  const ProductRow({required this.product, required this.excluded});

  final Product product;
  final bool excluded;
}

double? _price(String s) => double.tryParse(s.trim().replaceAll(',', ''));

/// Reads the export: "Name" required; "Internal Reference", "Color",
/// "Color Code", "Sales Price", "Unit of Measure" used when present; every
/// other column (stock, Total Value, …) ignored. Missing colours are filled
/// from other rows with the same colour code.
List<ProductRow> parseProductTable(List<List<String>> table) {
  if (table.isEmpty) throw const ProductParseException('The file is empty');
  final header = [for (final h in table.first) h.trim().toLowerCase()];
  int col(List<String> names) => header.indexWhere(names.contains);
  final name = col(['name', 'product', 'display name']);
  if (name < 0) throw const ProductParseException('No "Name" column found');
  final ref = col(['internal reference', 'reference', 'default_code']);
  final color = col(['color', 'colour']);
  final code = col(['color code', 'colour code']);
  final price = col(['sales price', 'price', 'list price']);
  final unit = col(['unit of measure', 'uom', 'unit']);
  String cell(List<String> row, int i) => i < 0 || i >= row.length ? '' : row[i].trim();

  final raw = <(String, String, String, String, String, String)>[];
  for (final row in table.skip(1)) {
    final n = cleanProductName(cell(row, name));
    if (n.isEmpty) continue;
    raw.add((n, cell(row, ref), cell(row, color), cleanProductName(cell(row, code)), cell(row, price), cell(row, unit)));
  }
  // Colour per decor: the most used non-empty one.
  final colors = <String, Map<String, int>>{};
  for (final r in raw) {
    final key = decorKeyOf(r.$4);
    if (key.isEmpty || r.$3.isEmpty) continue;
    final m = colors.putIfAbsent(key, () => {});
    m[r.$3] = (m[r.$3] ?? 0) + 1;
  }
  String colorFor(String key) {
    final m = colors[key];
    if (m == null || m.isEmpty) return '';
    return (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  return [
    for (final (n, rf, c, cd, pr, u) in raw)
      ProductRow(
        excluded: isExcludedProduct(n),
        product: Product(
          id: '',
          name: n,
          ref: rf,
          decor: decorKeyOf(cd),
          decorCode: decorKeyOf(cd).isEmpty ? '' : cd,
          color: c.isNotEmpty ? c : colorFor(decorKeyOf(cd)),
          type: classifyProduct(n),
          board: boardOf(n),
          size: sizeOf(n),
          unit: u,
          price: _price(pr),
        ),
      ),
  ];
}

class ProductUpdate {
  const ProductUpdate({required this.existing, required this.product, required this.changes});

  final Product existing;
  final Product product;

  /// Field → new value.
  final Map<String, Object?> changes;
}

class ProductPlan {
  const ProductPlan({
    required this.creates,
    required this.updates,
    required this.unchanged,
    required this.excluded,
    required this.duplicates,
    required this.notInFile,
  });

  final List<Product> creates;
  final List<ProductUpdate> updates;
  final int unchanged;

  /// Machines / test items left out.
  final List<Product> excluded;

  /// Rows repeating an earlier row of the file (same reference / name).
  final List<Product> duplicates;

  /// Products already in the app that this file doesn't have (kept).
  final List<Product> notInFile;
}

/// Compares the file with the products already saved: by Internal Reference
/// when both have one, else by name (spaces and case ignored).
ProductPlan buildProductPlan(List<ProductRow> rows, List<Product> existing) {
  final byRef = {for (final p in existing) if (p.ref.isNotEmpty) p.ref: p};
  final byName = {for (final p in existing) p.nameKey: p};
  final seen = <String>{};
  final matched = <String>{};
  final creates = <Product>[];
  final updates = <ProductUpdate>[];
  final excluded = <Product>[];
  final duplicates = <Product>[];
  var unchanged = 0;
  for (final r in rows) {
    final p = r.product;
    if (r.excluded) {
      excluded.add(p);
      continue;
    }
    final key = p.ref.isNotEmpty ? 'ref:${p.ref}' : 'name:${p.nameKey}';
    if (!seen.add(key)) {
      duplicates.add(p);
      continue;
    }
    final old = (p.ref.isNotEmpty ? byRef[p.ref] : null) ?? byName[p.nameKey];
    if (old == null) {
      creates.add(p);
      continue;
    }
    if (!matched.add(old.id)) {
      duplicates.add(p);
      continue;
    }
    final oldFields = old.fields;
    final changes = {
      for (final e in p.fields.entries)
        // Keep a reference the app has when the file has none.
        if (!(e.key == 'ref' && (e.value as String).isEmpty) && oldFields[e.key] != e.value) e.key: e.value,
    };
    if (changes.isEmpty) {
      unchanged++;
    } else {
      updates.add(ProductUpdate(existing: old, product: p, changes: changes));
    }
  }
  return ProductPlan(
    creates: creates,
    updates: updates,
    unchanged: unchanged,
    excluded: excluded,
    duplicates: duplicates,
    notInFile: [for (final p in existing) if (!matched.contains(p.id)) p],
  );
}
