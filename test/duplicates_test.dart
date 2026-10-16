import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/duplicates.dart';
import 'package:wpc_crm/features/clients/merge.dart';
import 'package:wpc_crm/features/import/import_plan.dart';
import 'package:wpc_crm/features/import/odoo_parser.dart';

Client c(
  String id,
  String name, {
  String vat = '',
  String phone = '',
  double? lat,
  double? lng,
  String? assignedTo,
  DateTime? lastVisitAt,
  List<String> notDuplicates = const [],
  List<MergedClient> mergedFrom = const [],
  String source = 'import',
  String city = '',
  List<String> aliases = const [],
}) =>
    Client(
      id: id, vat: vat, nameKey: Client.normalizeName(name), name: name, aliases: aliases,
      phone: phone, mobile: '', address: '', city: city, tags: '', odooSalesperson: '',
      googlePin: '', lat: lat, lng: lng, assignedTo: assignedTo, category: 'B', lastVisitAt: lastVisitAt,
      notDuplicates: notDuplicates, mergedFrom: mergedFrom, source: source,
    );

List<Set<String>> ids(List<DuplicateGroup> groups) => [for (final g in groups) {for (final x in g.clients) x.id}];

void main() {
  group('findDuplicates', () {
    test('same name, ignoring punctuation, spacing, Arabic letter forms and company words', () {
      final g = findDuplicates([
        c('1', 'Al-Noor Trading Co.'),
        c('2', 'alnoor trading'),
        c('3', 'مؤسسة النور'),
        c('4', 'النور'),
        c('5', 'Something else'),
      ]);
      expect(ids(g), containsAll([{'1', '2'}, {'3', '4'}]));
      expect(g.every((x) => x.reasons.contains(DuplicateReason.sameName)), isTrue);
    });

    test('same Tax ID and same phone (any prefix)', () {
      final g = findDuplicates([
        c('1', 'First', vat: '300123'),
        c('2', 'Second', vat: '300123'),
        c('3', 'Third', phone: '+966 50 123 4567'),
        c('4', 'Fourth', phone: '0501234567'),
      ]);
      expect(ids(g), containsAll([{'1', '2'}, {'3', '4'}]));
    });

    test('similar names and typos', () {
      expect(ids(findDuplicates([c('1', 'Riyadh Wood Factory'), c('2', 'Riyadh Wood Factory Branch 2')])), [{'1', '2'}]);
      expect(ids(findDuplicates([c('1', 'Masterpiece Kitchens'), c('2', 'Masterpeice Kitchens')])), [{'1', '2'}]);
    });

    test('close by alone is not enough; close by with a shared word is', () {
      expect(findDuplicates([c('1', 'Alpha Shop', lat: 24.7, lng: 46.7), c('2', 'Beta Store', lat: 24.7001, lng: 46.7)]), isEmpty);
      final g = findDuplicates([c('1', 'Alpha Shop', lat: 24.7, lng: 46.7), c('2', 'Alpha Furniture', lat: 24.7001, lng: 46.7)]);
      expect(g.single.reasons, contains(DuplicateReason.nearby));
    });

    test('different Tax IDs only count when the names are identical', () {
      expect(findDuplicates([c('1', 'Riyadh Wood Factory', vat: '1'), c('2', 'Riyadh Wood Factory Branch', vat: '2')]), isEmpty);
      expect(findDuplicates([c('1', 'Same Name', vat: '1'), c('2', 'Same Name', vat: '2')]), hasLength(1));
    });

    test('pairs marked not duplicates are left apart', () {
      expect(findDuplicates([c('1', 'Same', notDuplicates: ['2']), c('2', 'Same')]), isEmpty);
    });

    test('a phone used by many clients is a placeholder', () {
      expect(findDuplicates([for (final n in ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo']) c(n, n, phone: '0500000000')]), isEmpty);
    });
  });

  group('merge', () {
    test('fills empty details, keeps name and owner, logs the merged client', () {
      final keep = c('k', 'Keep Co', vat: '300', assignedTo: 'u1', lastVisitAt: DateTime(2026, 10, 1));
      final other = c('o', 'Keep Company', phone: '0501234567', lat: 24.1, lng: 46.1, assignedTo: 'u2',
          lastVisitAt: DateTime(2026, 10, 10), city: 'Riyadh', notDuplicates: ['x', 'k']);
      final u = mergeUpdate(keep, [other], byId: 'gm', at: DateTime(2026, 10, 15));
      expect(u['vat'], '300');
      expect(u['phone'], '0501234567');
      expect(u['city'], 'Riyadh');
      expect((u['lat'], u['lng']), (24.1, 46.1));
      expect(u['assignedTo'], 'u1');
      expect((u['lastVisitAt'] as Timestamp).toDate(), DateTime(2026, 10, 10));
      expect(u['aliases'], ['Keep Company']);
      expect(u['notDuplicates'], ['x']);
      expect((u['mergedFrom'] as List).single, containsPair('id', 'o'));
      expect(u.containsKey('name'), isFalse);
      expect(u.containsKey('category'), isFalse);
    });

    test('suggests keeping the Odoo client with a Tax ID', () {
      expect(suggestedKeep([c('m', 'A', source: 'manual', lat: 1, lng: 1), c('o', 'A', vat: '3')]).id, 'o');
    });

    test('the import skips rows of merged clients and keeps their names as aliases', () {
      final keep = c('k', 'Keep Co', vat: '300', aliases: ['Old Shop'], mergedFrom: const [
        MergedClient(id: 'o', name: 'Old Shop', nameKey: 'old shop', vat: '', byId: 'gm', at: null),
      ]);
      final p = buildPlan(
        rows: parseOdooTable([
          ['Complete Name', 'Tax ID', 'City'],
          ['Keep Co', '300', 'Jeddah'],
          ['Old Shop', '', ''],
        ]),
        existing: [keep],
        resolvedPins: const {},
        salespersonToUid: const {},
      );
      expect(p.creates, isEmpty);
      expect(p.updates.single.data['city'], 'Jeddah');
      expect(p.updates.single.data.containsKey('aliases'), isFalse);
    });
  });
}
