import { test } from 'node:test';
import assert from 'node:assert/strict';
import { convertTotal, convertParts } from '../src/utils/fxConvert.js';

const sum = (xs) => xs.reduce((s, x) => s + Math.round(Number(x) * 100), 0);

test('parts always add up to the converted total, to the paisa', () => {
  const rate = 83.12345;
  const total = convertTotal(100, rate);
  assert.equal(total, '8312.35');
  const parts = convertParts([{ amount: 33.34 }, { amount: 33.33 }, { amount: 33.33 }], rate, total);
  assert.equal(sum(parts), Math.round(Number(total) * 100));
});

test('random amounts and rates never drift', () => {
  let seed = 7;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let n = 0; n < 500; n += 1) {
    const k = 1 + Math.floor(rnd() * 6);
    const paise = Array.from({ length: k }, () => 1 + Math.floor(rnd() * 500000));
    const parts = paise.map((p) => ({ amount: (p / 100).toFixed(2) }));
    const rate = (0.001 + rnd() * 400).toFixed(6);
    const total = convertTotal(paise.reduce((a, b) => a + b, 0) / 100, rate);
    const out = convertParts(parts, rate, total);
    assert.equal(sum(out), Math.round(Number(total) * 100), `case ${n}`);
    out.forEach((v, i) => assert.ok(Math.abs(Number(v) - Number(parts[i].amount) * rate) <= 0.01 + 1e-9, `part ${i} off`));
  }
});

test('rate 1 changes nothing', () => {
  assert.deepEqual(convertParts([{ amount: '10.00' }, { amount: '5.55' }], 1, '15.55'), ['10.00', '5.55']);
});
