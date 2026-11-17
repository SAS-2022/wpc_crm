import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import 'product.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;
CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');

/// Every product; the sales team, SM and GM read them (rules).
final productsProvider = StreamProvider<List<Product>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true && u.value!.can.isSales ? u.value!.id : null));
  if (uid == null) return Stream.value(const []);
  return _products.snapshots().map((s) => s.docs.map(Product.fromDoc).toList()..sort(compareProducts));
});

final productsByIdProvider = Provider<Map<String, Product>>(
  (ref) => {for (final p in ref.watch(productsProvider).value ?? const <Product>[]) p.id: p},
);

/// The collection by decor (colour code).
final decorsProvider = Provider<List<Decor>>((ref) => decorsOf(ref.watch(productsProvider).value ?? const []));

final decorsByKeyProvider = Provider<Map<String, Decor>>((ref) => {for (final d in ref.watch(decorsProvider)) d.key: d});

/// Writes the plan in batches and records it in `product_imports`.
Future<void> commitProductImport(ProductPlan plan, {required String fileName, required String importedBy}) => saving(() async {
      final batchRef = _db.collection('product_imports').doc();
      final ops = <void Function(WriteBatch)>[
        for (final p in plan.creates)
          (b) => b.set(_products.doc(), {
                ...p.fields,
                'source': 'odoo',
                'importBatchId': batchRef.id,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }),
        for (final u in plan.updates)
          (b) => b.update(_products.doc(u.existing.id), {
                ...u.changes,
                'importBatchId': batchRef.id,
                'updatedAt': FieldValue.serverTimestamp(),
              }),
      ];
      for (var i = 0; i < ops.length; i += 400) {
        final batch = _db.batch();
        for (final op in ops.skip(i).take(400)) {
          op(batch);
        }
        await batch.commit();
      }
      await batchRef.set({
        'fileName': fileName,
        'importedBy': importedBy,
        'added': plan.creates.length,
        'updated': plan.updates.length,
        'unchanged': plan.unchanged,
        'excluded': plan.excluded.length,
        'duplicates': plan.duplicates.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
