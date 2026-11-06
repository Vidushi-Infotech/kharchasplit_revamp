// Unit tests for the pure parts of services/ledger.js.
// Run: npm run test:unit   (node's built-in runner, no DB needed)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { simplify, toPaise, fromPaise } from '../src/services/ledger.js';

const net = (obj) => new Map(Object.entries(obj));

/** Re-derive each user's net from the payments and compare. */
function assertSettles(input, payments) {
  const got = new Map();
  for (const p of payments) {
    const amt = toPaise(p.amount);
    assert.ok(amt > 0, 'every payment is positive');
    got.set(p.fromUserId, (got.get(p.fromUserId) || 0) - amt);
    got.set(p.toUserId, (got.get(p.toUserId) || 0) + amt);
  }
  for (const [u, p] of input) assert.equal(got.get(u) || 0, p, `net for ${u}`);
}

test('nothing owed → no payments', () => {
  assert.deepEqual(simplify(new Map()), []);
  assert.deepEqual(simplify(net({ a: 0, b: 0 })), []);
});

test('a single paisa is not dropped', () => {
  assert.deepEqual(simplify(net({ a: 1, b: -1 })), [{ fromUserId: 'b', toUserId: 'a', amount: '0.01' }]);
});

test('one creditor, several debtors', () => {
  const input = net({ a: 30000, b: -10000, c: -20000 });
  const out = simplify(input);
  assert.equal(out.length, 2);
  assertSettles(input, out);
});

test('ties are broken by user id, so output is stable', () => {
  const x = simplify(net({ b: 500, a: 500, d: -500, c: -500 }));
  const y = simplify(net({ c: -500, a: 500, d: -500, b: 500 }));
  assert.deepEqual(x, y);
  assert.deepEqual(x[0], { fromUserId: 'c', toUserId: 'a', amount: '5.00' });
});

test('random balanced inputs settle exactly in at most n-1 payments', () => {
  let seed = 7;
  const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
  for (let round = 0; round < 500; round++) {
    const n = 2 + Math.floor(rnd() * 9);
    const input = new Map();
    let sum = 0;
    for (let i = 0; i < n - 1; i++) {
      const p = Math.floor(rnd() * 2_000_000) - 1_000_000;
      input.set(`u${i}`, p);
      sum += p;
    }
    input.set(`u${n - 1}`, -sum);
    const out = simplify(input);
    assert.ok(out.length <= n - 1, `≤ ${n - 1} payments, got ${out.length}`);
    assertSettles(new Map([...input].filter(([, p]) => p !== 0)), out);
  }
});

test('paise conversion survives float noise', () => {
  assert.equal(toPaise(0.1 + 0.2), 30);
  assert.equal(toPaise('333.33'), 33333);
  assert.equal(fromPaise(33333), '333.33');
  assert.equal(fromPaise(5), '0.05');
});
