import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/products/product.dart';

// Rows taken from the user's Odoo export "Product Variant (product.product).csv"
// (2026-11-17), stock columns shortened.
const _header = [
  'At Sea', 'Color', 'Color Code', 'Forecast', 'Forecast Qty', 'Forecasted Quantity', 'Incoming', 'Name', 'On Hand', //
  'Outgoing', 'Sales Price', 'Sold', 'Total Stock', 'Total Value', 'Unit of Measure',
];

List<String> row(String color, String code, String name, String price, String unit) =>
    ['0.0', color, code, '1', '1', '1', '0', name, '1', '0', price, '0', '1', '99.9', unit];

final _table = [
  _header,
  row('Beige', '139', 'SW 139 Kumtasi Naturel MFC 280*210*18', '285.0', 'Pnl'),
  row('Beige', '139', 'PVC 139 SW Kumtasi Naturel 1.0*22', '1.4', 'LM'),
  row('Beige', '139', 'HPL 139 Kumtasi Naturel Gentas 244*122*0.6', '75.0', 'Laminates'),
  row('', '139', 'SW Smpl 139 Kumtasi Naturel  210*183 Microlam Paper', '1.0', 'Pnl'),
  row('Beige', '139', 'SW 139 Kumtasi Naturel MFC MR 280*210*18', '325.0', 'Pnl'),
  row('Latte', '044 Duz', 'SW 044 Atlas Duz MFC 280*210*8', '235.0', 'Pnl'),
  row('Latte', '044 Naturel', 'SW Smpl 044 Atlas Naturel MDF 210*183*2.7', '0.0', 'Pnl'),
  row('White Terrazzo', '2028 G', 'ABS ZH S2028 Gloss 1.0*22', '1.6', 'LM'),
  row('Black', 'S040', 'GZ 3D ALU S040 280*21', '1.0', 'Pnl'),
  row('Black', 'S040', 'GZ 3D ALU S040 280*21', '1.0', 'Pnl'),
  row('', 'Accessories', 'Wooden Dowel', '1.0', 'Unit'),
  row('', 'Pallet', 'Pallet Panel', '120.0', 'Pnl'),
  row('', '', 'Metalla Soft Close Hinge 110 Degrees-Full Overlay', '7.14', 'Unit'),
  row('', '', 'EXT CNC Drilling Machine EHS 1228-C', '184000.0', 'Unit'),
  row('', '', 'Edge Bander EF583GIW', '204000.0', 'Unit'),
  row('', '', 'Panel Saw EP380', '199000.0', 'Unit'),
  row('', '', 'Hinge Drill (MCDRILLHOOOOG)', '0.0', 'Unit'),
  row('', '', 'Screw Air Compressor - TV11PM410', '31000.0', 'Unit'),
  row('', '', 'Test Table Marc', '1.0', 'Unit'),
  row('', '', 'Hospa Screw CS Galv 4.0*15mm', '0.04', 'Unit'),
  row('', 'Samples', 'Samples', '1.125', 'Unit'),
  row('', '', '', '1', 'Unit'),
];

Product _p(List<ProductRow> rows, String name) => rows.firstWhere((r) => r.product.name == cleanProductName(name)).product;

void main() {
  final rows = parseProductTable(_table);

  test('reads names, prices, units; stock and Total Value ignored; empty names skipped', () {
    expect(rows.length, _table.length - 2);
    final mfc = _p(rows, 'SW 139 Kumtasi Naturel MFC 280*210*18');
    expect(mfc.price, 285);
    expect(mfc.unit, 'Pnl');
    expect(mfc.fields.keys, isNot(contains('totalValue')));
  });

  test('decor = colour code; missing colours filled from the same code', () {
    final sample = _p(rows, 'SW Smpl 139 Kumtasi Naturel 210*183 Microlam Paper');
    expect(sample.decor, '139');
    expect(sample.color, 'Beige');
    expect(_p(rows, 'SW 044 Atlas Duz MFC 280*210*8').decor, '044 DUZ');
    expect(_p(rows, 'SW 044 Atlas Duz MFC 280*210*8').decorCode, '044 Duz');
    for (final name in ['Wooden Dowel', 'Pallet Panel', 'Samples', 'Metalla Soft Close Hinge 110 Degrees-Full Overlay']) {
      expect(_p(rows, name).decor, '', reason: name);
    }
  });

  test('type, board and size from the name', () {
    final mfc = _p(rows, 'SW 139 Kumtasi Naturel MFC 280*210*18');
    expect((mfc.type, mfc.board, mfc.size), (ProductType.panel, 'MFC', '280*210*18'));
    final mr = _p(rows, 'SW 139 Kumtasi Naturel MFC MR 280*210*18');
    expect(mr.board, 'MFC MR');
    final pvc = _p(rows, 'PVC 139 SW Kumtasi Naturel 1.0*22');
    expect((pvc.type, pvc.size), (ProductType.edgeBand, '1.0*22'));
    expect(_p(rows, 'ABS ZH S2028 Gloss 1.0*22').type, ProductType.edgeBand);
    expect(_p(rows, 'HPL 139 Kumtasi Naturel Gentas 244*122*0.6').type, ProductType.laminate);
    final smpl = _p(rows, 'SW Smpl 139 Kumtasi Naturel 210*183 Microlam Paper');
    expect((smpl.type, smpl.board, smpl.size), (ProductType.sample, 'Microlam Paper', '210*183'));
    expect(_p(rows, 'SW Smpl 044 Atlas Naturel MDF 210*183*2.7').size, '210*183*2.7');
    expect(_p(rows, 'Samples').type, ProductType.sample);
    expect(_p(rows, 'GZ 3D ALU S040 280*21').type, ProductType.panel);
    expect(_p(rows, 'Wooden Dowel').type, ProductType.accessory);
  });

  test('machines and test items are left out, hardware is kept', () {
    final out = {for (final r in rows) if (r.excluded) r.product.name};
    expect(out, {
      'EXT CNC Drilling Machine EHS 1228-C',
      'Edge Bander EF583GIW',
      'Panel Saw EP380',
      'Hinge Drill (MCDRILLHOOOOG)',
      'Screw Air Compressor - TV11PM410',
      'Test Table Marc',
    });
  });

  test('first import: new products, a repeated row once, machines left out', () {
    final plan = buildProductPlan(rows, const []);
    expect(plan.excluded.length, 6);
    expect(plan.duplicates.map((p) => p.name), ['GZ 3D ALU S040 280*21']);
    expect(plan.creates.length, rows.length - 6 - 1);
    expect(plan.updates, isEmpty);
  });

  test('re-import: matched by name (spaces / case ignored), only changes written, others kept', () {
    final saved = [
      for (final (i, p) in buildProductPlan(rows, const []).creates.indexed)
        Product(
          id: 'p$i',
          name: p.name.toUpperCase(),
          decor: p.decor,
          decorCode: p.decorCode,
          color: p.color,
          type: p.type,
          board: p.board,
          size: p.size,
          unit: p.unit,
          price: p.price,
        ),
      const Product(id: 'old', name: 'Discontinued board'),
    ];
    final cheaper = [
      for (final r in rows)
        r.product.name == 'SW 139 Kumtasi Naturel MFC 280*210*18'
            ? ProductRow(excluded: false, product: Product(id: '', name: r.product.name, decor: '139', decorCode: '139', color: 'Beige', type: ProductType.panel, board: 'MFC', size: '280*210*18', unit: 'Pnl', price: 270))
            : r,
    ];
    final plan = buildProductPlan(cheaper, saved);
    expect(plan.creates, isEmpty);
    // Every name differs in case → name updated too; the price only on one.
    final priceChanges = [for (final u in plan.updates) if (u.changes.containsKey('price')) u];
    expect(priceChanges.single.changes['price'], 270);
    expect(plan.notInFile.map((p) => p.id), ['old']);
  });

  test('Internal Reference wins over the name when the file has one', () {
    final table = [
      ['Name', 'Internal Reference', 'Color Code'],
      ['New name for board', 'WPC-001', '139'],
    ];
    final plan = buildProductPlan(parseProductTable(table), const [Product(id: 'a', name: 'Old name', ref: 'WPC-001', decor: '139', decorCode: '139')]);
    expect(plan.creates, isEmpty);
    expect(plan.updates.single.changes['name'], 'New name for board');
  });

  test('decors sorted by code, labelled with the colour', () {
    final decors = decorsOf(buildProductPlan(rows, const []).creates);
    expect(decors.map((d) => d.key).toList(), ['044 DUZ', '044 NATUREL', '139', '2028 G', 'S040']);
    final d139 = decors.firstWhere((d) => d.key == '139');
    expect(d139.label, '139 · Beige');
    expect(d139.products.first.type, ProductType.panel);
    expect(decorMatches(d139, 'kumtasi'), isTrue);
    expect(decorMatches(d139, 'beige'), isTrue);
  });

  test('a file without a Name column is refused', () {
    expect(() => parseProductTable([
          ['Color', 'Price'],
        ]), throwsA(isA<ProductParseException>()));
  });
}
