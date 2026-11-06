import { test } from 'node:test';
import assert from 'node:assert/strict';
import { compareVersions, parseVersion, isClientAtLeast, enabledFeatures } from '../src/utils/appVersion.js';

const req = (v) => ({ get: () => v });

test('parses versions with or without a build number', () => {
  assert.deepEqual(parseVersion('3.4.0+25'), [3, 4, 0]);
  assert.equal(parseVersion('3.4'), null);
  assert.equal(parseVersion(undefined), null);
});

test('compares numerically, not as strings', () => {
  assert.ok(compareVersions('3.10.0', '3.9.9') > 0);
  assert.equal(compareVersions('3.4.0+25', '3.4.0'), 0);
  assert.ok(compareVersions('garbage', '0.0.1') < 0);
});

test('a request without a version header counts as an old build', () => {
  assert.equal(isClientAtLeast(req(undefined), '1.0.0'), false);
  assert.equal(isClientAtLeast(req('3.6.1'), '3.6.0'), true);
  assert.equal(isClientAtLeast(req('3.5.9'), '3.6.0'), false);
});

test('feature list ignores blanks and whitespace', () => {
  process.env.FEATURES = ' multiPayer, ,upiPay ';
  assert.deepEqual(enabledFeatures(), ['multiPayer', 'upiPay']);
  delete process.env.FEATURES;
  assert.deepEqual(enabledFeatures(), []);
});
