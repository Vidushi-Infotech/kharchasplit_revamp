/**
 * Quick standalone smoke test for WATI integration.
 *
 * Usage:
 *   cd backend && node scripts/test-wati-invite.js <phoneNumber> [recipientName] [inviterName]
 *
 * Sends a single MARKETING template ("kharchasplit_invitation") via WATI.
 * Loads env from backend/.env. Will print the WATI response verbatim.
 */
import 'dotenv/config';
import WatiService from '../src/services/watiService.js';

const phone = process.argv[2];
const recipientName = process.argv[3] || 'Friend';
const inviterName = process.argv[4] || 'Shoaib';

if (!phone) {
  console.error('Usage: node scripts/test-wati-invite.js <phoneNumber> [recipientName] [inviterName]');
  process.exit(2);
}

console.log('--- WATI smoke test ---');
console.log('  WATI_API_URL      :', process.env.WATI_API_URL || '(not set)');
console.log('  WATI_API_TOKEN    :', (process.env.WATI_API_TOKEN || '').slice(0, 24) + '…');
console.log('  WATI_TEMPLATE_NAME:', process.env.WATI_TEMPLATE_NAME || '(default)');
console.log('  recipient phone   :', phone);
console.log('  recipient name    :', recipientName);
console.log('  inviter name      :', inviterName);
console.log('-----------------------');

try {
  const result = await WatiService.sendInviteMessage(
    phone,
    recipientName,
    inviterName,
    null,
  );
  console.log('\nResult:');
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.success ? 0 : 1);
} catch (err) {
  console.error('\nThrew:', err);
  process.exit(1);
}
