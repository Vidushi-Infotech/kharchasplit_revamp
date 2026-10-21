import { test } from 'node:test';
import assert from 'node:assert/strict';
import { csvCell, toCsv } from '../src/utils/csv.js';

test('quotes, commas and newlines are escaped', () => {
  assert.equal(csvCell('Dinner, drinks'), '"Dinner, drinks"');
  assert.equal(csvCell('He said "hi"'), '"He said ""hi"""');
  assert.equal(csvCell('a\nb'), '"a\nb"');
  assert.equal(csvCell(null), '');
});

test('formulas are neutralised, numbers are not', () => {
  assert.equal(csvCell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
  assert.equal(csvCell('@SUM(A1)'), "'@SUM(A1)");
  assert.equal(csvCell('-250.50'), '-250.50');
  assert.equal(csvCell(-12), '-12');
});

test('has a BOM and CRLF rows', () => {
  assert.equal(toCsv(['a', 'b'], [[1, 'x']]), '﻿a,b\r\n1,x\r\n');
});
