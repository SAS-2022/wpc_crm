import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/documents/company_docs.dart';

CompanyDoc item(
  String id, {
  bool folder = false,
  DocSection section = DocSection.product,
  String parent = '',
  String company = '',
  bool own = false,
  bool restricted = false,
  String name = '',
  String expiry = '',
  String number = '',
  String person = '',
}) =>
    CompanyDoc(
      id: id,
      isFolder: folder,
      section: section,
      name: name.isEmpty ? id : name,
      parentId: parent,
      companyId: company,
      ownRestricted: own,
      restricted: restricted,
      expiry: expiry,
      docNumber: number,
      personId: person,
    );

void main() {
  test('sections and editing by role', () {
    expect(docSectionsFor(UserRole.salesExec), [DocSection.official, DocSection.product]);
    expect(docSectionsFor(UserRole.kam), [DocSection.official, DocSection.product]);
    expect(docSectionsFor(UserRole.hr), DocSection.values);
    expect(docSectionsFor(UserRole.gm), DocSection.values);
    expect(docSectionsFor(UserRole.accounting), isEmpty);
    expect(canEditDocSection(UserRole.salesManager, DocSection.official), isTrue);
    expect(canEditDocSection(UserRole.hr, DocSection.expiring), isTrue);
    expect(canEditDocSection(UserRole.hr, DocSection.product), isFalse);
    expect(canEditDocSection(UserRole.kam, DocSection.product), isFalse);
  });

  test('expiry states and the next expiry offered', () {
    final today = DateTime(2026, 11, 1);
    docDueSoonDays = 30;
    expect(docExpiryState('', today), DocExpiryState.none);
    expect(docExpiryState('2026-12-15', today), DocExpiryState.ok);
    expect(docExpiryState('2026-12-01', today), DocExpiryState.dueSoon);
    expect(docExpiryState('2026-11-01', today), DocExpiryState.expired);
    expect(nextDocExpiry('2026-12-01', today), '2027-12-01');
    expect(nextDocExpiry('2026-08-01', today), '2027-11-01');
    expect(nextDocExpiry('2028-02-29', DateTime(2028, 2, 1)), '2029-02-28');
    // Only expiring files have a state.
    expect(item('a', section: DocSection.official, expiry: '2026-11-05').expiryState(today), DocExpiryState.none);
    expect(item('b', section: DocSection.expiring, expiry: '2026-11-05').needsRenewal(today), isTrue);
  });

  test('items in a place: folders first, Official top split by company', () {
    final all = [
      item('f2', section: DocSection.official, company: 'c1', name: 'b'),
      item('d1', folder: true, section: DocSection.official, company: 'c1', name: 'z'),
      item('f1', section: DocSection.official, company: 'c1', name: 'a'),
      item('x', section: DocSection.official, company: 'c2'),
      item('in', section: DocSection.official, company: 'c1', parent: 'd1'),
      item('p', section: DocSection.product),
    ];
    expect(docsIn(all, (section: DocSection.official, companyId: 'c1', folderId: '')).map((d) => d.id), ['d1', 'f1', 'f2']);
    expect(docsIn(all, (section: DocSection.official, companyId: '', folderId: '')), isEmpty);
    expect(docsIn(all, (section: DocSection.official, companyId: 'c1', folderId: 'd1')).map((d) => d.id), ['in']);
    expect(docsIn(all, (section: DocSection.product, companyId: '', folderId: '')).map((d) => d.id), ['p']);
  });

  test('path, descendants and move targets', () {
    final all = [
      item('a', folder: true),
      item('b', folder: true, parent: 'a'),
      item('c', folder: true, parent: 'b'),
      item('f', parent: 'c'),
      item('other', folder: true),
      item('exp', folder: true, section: DocSection.expiring),
    ];
    expect(docPath(all, 'c').map((d) => d.id), ['a', 'b', 'c']);
    expect(docDescendants(all, 'a').map((d) => d.id).toSet(), {'b', 'c', 'f'});
    expect(docMoveTargets(all, all.first).map((d) => d.id), ['other']);
    expect(docMoveTargets(all, all[3]).map((d) => d.id).toSet(), {'a', 'b', 'c', 'other'});
  });

  test('management only is inherited, and Expiring always is', () {
    final all = [
      item('a', folder: true, own: true, restricted: true),
      item('b', folder: true, parent: 'a', restricted: true),
      item('open', folder: true),
    ];
    expect(docRestrictedUnder(all, DocSection.product, 'b', false), isTrue);
    expect(docRestrictedUnder(all, DocSection.product, 'open', false), isFalse);
    expect(docRestrictedUnder(all, DocSection.product, 'open', true), isTrue);
    expect(docRestrictedUnder(all, DocSection.expiring, '', false), isTrue);
  });

  test('subtree changes after unmarking a folder or moving it to another company', () {
    final all = [
      item('a', folder: true, section: DocSection.official, company: 'c1', own: true, restricted: true),
      item('b', folder: true, section: DocSection.official, company: 'c1', parent: 'a', restricted: true),
      item('f', section: DocSection.official, company: 'c1', parent: 'b', restricted: true),
      item('secret', section: DocSection.official, company: 'c1', parent: 'b', own: true, restricted: true),
    ];
    final unmarked = item('a', folder: true, section: DocSection.official, company: 'c1');
    expect(docSubtreeChanges(all, unmarked), {
      'b': (restricted: false, companyId: 'c1'),
      'f': (restricted: false, companyId: 'c1'),
    });
    final moved = item('a', folder: true, section: DocSection.official, company: 'c2', own: true, restricted: true);
    expect(docSubtreeChanges(all, moved).map((k, v) => MapEntry(k, v.companyId)), {'b': 'c2', 'f': 'c2', 'secret': 'c2'});
  });

  test('search: every word, name / number / employee, Arabic letter forms', () {
    final all = [
      item('1', name: 'Moqeem', number: '2456', person: 'u1'),
      item('2', name: 'شهادة الزكاة'),
      item('3', name: 'Datasheet MDF'),
      item('folder', folder: true, name: 'Moqeem folder'),
    ];
    expect(searchDocs(all, 'moqeem ali', {'u1': 'Ali Hassan'}).map((d) => d.id), ['1']);
    expect(searchDocs(all, '2456', const {}).map((d) => d.id), ['1']);
    expect(searchDocs(all, 'شهاده', const {}).map((d) => d.id), ['2']);
    expect(searchDocs(all, 'mdf data', const {}).map((d) => d.id), ['3']);
    expect(searchDocs(all, '  ', const {}), isEmpty);
  });
}
