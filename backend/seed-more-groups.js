// Appends more dummy groups + expenses for the test user (+919999988888).
// Safe to re-run — won't touch existing data. Run from backend/:
//   node seed-more-groups.js

const BASE = 'http://localhost:3000/api/v1';
const TEST_PHONE = '+919999988888';

async function api(path, opts = {}, token) {
  const res = await fetch(`${BASE}${path}`, {
    method: opts.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = { raw: text }; }
  if (!res.ok) {
    throw new Error(`${opts.method || 'GET'} ${path} → ${res.status}: ${JSON.stringify(json)}`);
  }
  return json;
}

function eqSplits(participants, amount) {
  const share = Math.round((amount / participants.length) * 100) / 100;
  let assigned = 0;
  return participants.map((u, i) => {
    const a = i === participants.length - 1
      ? Math.round((amount - assigned) * 100) / 100
      : share;
    assigned += a;
    return { userId: u.userId, amount: a };
  });
}

async function ensureUser(phone, name) {
  try {
    const r = await api('/auth/register', {
      method: 'POST',
      body: { phoneNumber: phone, name },
    });
    return { userId: r.data.user.id, name, phone };
  } catch (_) {
    const r2 = await api('/auth/simple-login', {
      method: 'POST',
      body: { phoneNumber: phone },
    });
    return { userId: r2.data.user.id, name, phone };
  }
}

async function main() {
  console.log(`\n→ Logging in as ${TEST_PHONE}…`);
  const login = await api('/auth/simple-login', {
    method: 'POST',
    body: { phoneNumber: TEST_PHONE },
  });
  const token = login.data.accessToken;
  const me = login.data.user;
  console.log(`✓ Logged in as ${me.name}`);

  // Make sure all dummy users exist (idempotent)
  const userDefs = [
    { phone: '+918888880001', name: 'Rohan Mehta' },
    { phone: '+918888880002', name: 'Priya Sharma' },
    { phone: '+918888880003', name: 'Aman Verma' },
    { phone: '+918888880004', name: 'Neha Kapoor' },
    { phone: '+918888880005', name: 'Vikram Singh' },
    { phone: '+918888880006', name: 'Ananya Iyer' },
    { phone: '+918888880007', name: 'Karan Joshi' },
  ];
  const users = {};
  for (const u of userDefs) {
    users[u.phone] = await ensureUser(u.phone, u.name);
    console.log(`✓ User: ${u.name}`);
  }

  // Five new groups, each with a distinct cast and vibe
  const groupSpecs = [
    {
      name: 'Weekend Brunch 🥞',
      members: [
        users['+918888880001'],
        users['+918888880004'],
        users['+918888880006'],
      ],
      expenses: [
        { description: 'Pancakes & coffee', category: 'Food', amount: 1450, paidByPhone: '+918888880001', daysAgo: 0 },
        { description: 'Boozy mimosas', category: 'Food', amount: 900, paidByPhone: '+918888880004', daysAgo: 0 },
      ],
    },
    {
      name: 'Diwali Gifts 🪔',
      members: [
        users['+918888880002'],
        users['+918888880003'],
        users['+918888880005'],
        users['+918888880007'],
      ],
      expenses: [
        { description: 'Sweet boxes (Mithai)', category: 'Shopping', amount: 3600, paidByPhone: me.phoneNumber, daysAgo: 4 },
        { description: 'Diyas & decoration', category: 'Shopping', amount: 1200, paidByPhone: '+918888880005', daysAgo: 4 },
        { description: 'Cracker pack', category: 'Shopping', amount: 800, paidByPhone: '+918888880007', daysAgo: 4 },
      ],
    },
    {
      name: 'Gym Membership 🏋️',
      members: [users['+918888880001']],
      expenses: [
        { description: 'Quarterly fee', category: 'Health', amount: 6000, paidByPhone: me.phoneNumber, daysAgo: 7 },
        { description: 'Protein shake order', category: 'Health', amount: 1850, paidByPhone: '+918888880001', daysAgo: 5 },
      ],
    },
    {
      name: 'Movie Nights 🎬',
      members: [
        users['+918888880002'],
        users['+918888880006'],
      ],
      expenses: [
        { description: 'Tickets — Dune 3', category: 'Entertainment', amount: 750, paidByPhone: me.phoneNumber, daysAgo: 1 },
        { description: 'Popcorn & drinks', category: 'Food', amount: 480, paidByPhone: '+918888880006', daysAgo: 1 },
      ],
    },
    {
      name: 'Bangalore Hackathon 💻',
      members: [
        users['+918888880003'],
        users['+918888880005'],
        users['+918888880007'],
      ],
      expenses: [
        { description: 'Airbnb (3 nights)', category: 'Travel', amount: 9800, paidByPhone: '+918888880005', daysAgo: 6 },
        { description: 'Uber pool — venue runs', category: 'Transport', amount: 620, paidByPhone: me.phoneNumber, daysAgo: 6 },
        { description: 'Midnight Maggi', category: 'Food', amount: 320, paidByPhone: '+918888880007', daysAgo: 5 },
      ],
    },
  ];

  me.phoneNumber = me.phoneNumber || TEST_PHONE; // safety

  for (const spec of groupSpecs) {
    console.log(`\n→ Creating "${spec.name}"…`);
    const created = await api('/groups', {
      method: 'POST',
      body: {
        name: spec.name,
        currency: 'INR',
        members: spec.members.map(m => ({
          userId: m.userId,
          name: m.name,
          phoneNumber: m.phone,
        })),
      },
    }, token);
    const groupId = created.data.id;
    console.log(`✓ ${spec.name} → ${groupId}`);

    const pool = [{ userId: me.id, name: me.name }, ...spec.members];

    for (const ex of spec.expenses) {
      const date = new Date();
      date.setDate(date.getDate() - ex.daysAgo);

      const paidBy = ex.paidByPhone === me.phoneNumber || ex.paidByPhone === TEST_PHONE
        ? me.id
        : users[ex.paidByPhone].userId;

      try {
        await api('/expenses', {
          method: 'POST',
          body: {
            groupId,
            description: ex.description,
            amount: ex.amount,
            currency: 'INR',
            category: ex.category,
            paidById: paidBy,
            splitType: 'equal',
            participants: eqSplits(pool, ex.amount),
            expenseDate: date.toISOString(),
          },
        }, token);
        console.log(`  • ${ex.description}: ₹${ex.amount}`);
      } catch (e) {
        console.error(`  ✗ ${ex.description}: ${e.message}`);
      }
    }
  }

  console.log(`\n✓ Done. Pull-to-refresh in the app.`);
}

main().catch((e) => {
  console.error('\n✗ Failed:', e.message);
  process.exit(1);
});
