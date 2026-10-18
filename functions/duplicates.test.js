// Run with: node --test (in functions/)
const test = require('node:test');
const assert = require('node:assert');
const { findMatches, duplicateReasons } = require('./duplicates');

const clients = [
  { id: 'a', name: 'Al-Noor Trading Est.', vat: '300111', phone: '+966 50 123 4567' },
  { id: 'b', name: 'مؤسسة البيت الحرفي للتجارة', vat: '' },
  { id: 'c', name: 'Riyadh Furniture Factory', vat: '300999', lat: 24.7, lng: 46.6 },
  { id: 'd', name: 'Other', companyId: '1010123456' },
];

test('same name ignoring punctuation and company words', () => {
  const m = findMatches({ name: 'alnoor trading' }, clients);
  assert.deepStrictEqual(m.map((x) => x.client.id), ['a']);
  assert.ok(m[0].reasons.includes('sameName'));
});

test('Arabic letter forms and company words are ignored', () => {
  const m = findMatches({ name: 'البيت الحرفى للتجارة' }, clients);
  assert.deepStrictEqual(m.map((x) => x.client.id), ['b']);
});

test('same Tax ID, CR number or phone', () => {
  assert.ok(duplicateReasons({ name: 'X', vat: '300 111' }, clients[0]).includes('sameVat'));
  assert.ok(duplicateReasons({ name: 'X', companyId: '1010123456' }, clients[3]).includes('sameCompanyId'));
  assert.ok(duplicateReasons({ name: 'X', mobile: '0501234567' }, clients[0]).includes('samePhone'));
});

test('similar names and nearby pins', () => {
  assert.ok(duplicateReasons({ name: 'Riyadh Furniture Factry' }, clients[2]).includes('similarName'));
  assert.ok(duplicateReasons({ name: 'Furniture Showroom', lat: 24.7002, lng: 46.6 }, clients[2]).includes('nearby'));
});

test('different Tax IDs are different companies unless the names are identical', () => {
  assert.deepStrictEqual(duplicateReasons({ name: 'Riyadh Furniture Factry', vat: '300555' }, clients[2]), []);
  assert.deepStrictEqual(duplicateReasons({ name: 'Riyadh Furniture Factory', vat: '300555' }, clients[2]), ['sameName']);
});

test('a new name matches nothing', () => {
  assert.deepStrictEqual(findMatches({ name: 'Completely New Client' }, clients), []);
});
