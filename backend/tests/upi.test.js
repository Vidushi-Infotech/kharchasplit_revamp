import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeUpiId } from '../src/utils/upi.js';

test('normalises valid VPAs', () => {
  assert.equal(normalizeUpiId(' Asha.K@OKHDFCBANK '), 'asha.k@okhdfcbank');
  assert.equal(normalizeUpiId('9876543210@ybl'), '9876543210@ybl');
  assert.equal(normalizeUpiId('first_last-1@paytm'), 'first_last-1@paytm');
});

test('empty input clears the UPI ID', () => {
  assert.equal(normalizeUpiId(''), null);
  assert.equal(normalizeUpiId('   '), null);
  assert.equal(normalizeUpiId(null), null);
});

test('rejects malformed VPAs with a 400', () => {
  for (const bad of ['asha', '@ybl', 'asha@', 'a@ybl', 'asha@@ybl', 'asha@1bank', 'as ha@ybl', `${'a'.repeat(99)}@ybl`]) {
    assert.throws(() => normalizeUpiId(bad), (e) => e.status === 400, bad);
  }
});
