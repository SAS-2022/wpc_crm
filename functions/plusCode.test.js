// Run with: node --test (in functions/)
const test = require('node:test');
const assert = require('node:assert');
const { coordsFromPlusCode, cityReference } = require('./plusCode');

test('short code + city in the address (link from the iPhone share sheet)', () => {
  const url = decodeURIComponent('https://www.google.com/maps/place/RH8W%2B2QH+%D8%A3%D9%83%D8%AF%D8%A7%D9%84+Akdal%D8%8C+%D8%A7%D9%84%D9%85%D9%84%D9%82%D8%A7%D8%8C+%D8%A7%D9%84%D8%B1%D9%8A%D8%A7%D8%B6+13525/data=!4m2');
  const c = coordsFromPlusCode(url);
  assert.ok(Math.abs(c.lat - 24.81506) < 0.0001 && Math.abs(c.lng - 46.59698) < 0.0001);
});

test('full code, no city needed; short code without a city is unreadable', () => {
  const c = coordsFromPlusCode('7HP8RH8W+2QH');
  assert.ok(Math.abs(c.lat - 24.81506) < 0.0001);
  assert.strictEqual(coordsFromPlusCode('RH8W+2QH'), null);
});

test('whole-word city names', () => {
  assert.strictEqual(cityReference('thumbnail'), null);
  assert.deepStrictEqual(cityReference('Riyadh road, Jeddah'), [21.5433, 39.1728]);
});
