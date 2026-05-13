// Seeds dummy data for the test user (+919999988888).
// Run from backend/: `node seed-test-data.js`

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
  // Last participant absorbs rounding so the splits sum to amount exactly.
  let assigned = 0;
  return participants.map((u, i) => {
    const a = i === participants.length - 1
      ? Math.round((amount - assigned) * 100) / 100
      : share;
    assigned += a;
    return { userId: u.userId, amount: a };
  });
}

async function ensureMember(groupId, token, name, phone) {
  try {
    const result = await api(`/groups/${groupId}/members`, {
      method: 'POST',
      body: { userId: phone, name, phoneNumber: phone },
    }, token);
    return result;
  } catch (e) {
    // If already exists, try registering separately
    if (String(e.message).includes('already')) {
      console.log(`  (member ${name} already in group, skipping)`);
      return null;
    }
    throw e;
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
  console.log(`✓ Logged in as ${me.name} (${me.id})`);

  // --- Register dummy users so they have real IDs ---
  const dummyUsers = [
    { phone: '+918888880001', name: 'Rohan Mehta' },
    { phone: '+918888880002', name: 'Priya Sharma' },
    { phone: '+918888880003', name: 'Aman Verma' },
  ];
  const users = { [me.id]: { userId: me.id, name: me.name } };
  for (const u of dummyUsers) {
    try {
      const r = await api('/auth/register', {
        method: 'POST',
        body: { phoneNumber: u.phone, name: u.name },
      });
      users[u.phone] = { userId: r.data.user.id, name: u.name, phone: u.phone };
      console.log(`✓ Created ${u.name}`);
    } catch (e) {
      // Probably exists — fetch via simple-login to grab the id
      const r2 = await api('/auth/simple-login', {
        method: 'POST',
        body: { phoneNumber: u.phone },
      });
      users[u.phone] = { userId: r2.data.user.id, name: u.name, phone: u.phone };
      console.log(`✓ Found existing ${u.name}`);
    }
  }

  // --- Create groups ---
  const groupSpecs = [
    {
      name: 'Goa Trip 🏖️',
      members: [users['+918888880001'], users['+918888880002']],
    },
    {
      name: 'Roommates 🏠',
      members: [users['+918888880003']],
    },
    {
      name: 'Office Lunch 🍱',
      members: [users['+918888880002']],
    },
  ];

  const groups = [];
  for (const spec of groupSpecs) {
    console.log(`\n→ Creating group "${spec.name}"…`);
    const r = await api('/groups', {
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
    const groupId = r.data.id;
    console.log(`✓ Created ${spec.name} → ${groupId}`);

    // Build the participant pool (self + members)
    const pool = [{ userId: me.id, name: me.name }, ...spec.members];
    groups.push({ id: groupId, name: spec.name, members: pool });
  }

  // --- Create expenses per group ---
  const today = new Date();
  const daysAgo = (n) => {
    const d = new Date(today);
    d.setDate(d.getDate() - n);
    return d.toISOString();
  };

  const expenseSpecs = [
    // Goa Trip
    {
      groupIdx: 0,
      description: 'Beach resort booking',
      category: 'Travel',
      amount: 12000,
      paidBy: me.id,
      date: daysAgo(2),
    },
    {
      groupIdx: 0,
      description: 'Cab to airport',
      category: 'Transport',
      amount: 1800,
      paidBy: users['+918888880001'].userId,
      date: daysAgo(2),
    },
    {
      groupIdx: 0,
      description: 'Dinner at seafood place',
      category: 'Food',
      amount: 3200,
      paidBy: users['+918888880002'].userId,
      date: daysAgo(1),
    },
    // Roommates
    {
      groupIdx: 1,
      description: 'Weekly groceries',
      category: 'Groceries',
      amount: 1450,
      paidBy: users['+918888880003'].userId,
      date: daysAgo(3),
    },
    {
      groupIdx: 1,
      description: 'Electricity bill',
      category: 'Utilities',
      amount: 2200,
      paidBy: me.id,
      date: daysAgo(0),
    },
    // Office Lunch
    {
      groupIdx: 2,
      description: 'Team lunch — Indian',
      category: 'Food',
      amount: 850,
      paidBy: me.id,
      date: daysAgo(0),
    },
  ];

  for (const ex of expenseSpecs) {
    const group = groups[ex.groupIdx];
    const participants = eqSplits(group.members, ex.amount);
    try {
      await api('/expenses', {
        method: 'POST',
        body: {
          groupId: group.id,
          description: ex.description,
          amount: ex.amount,
          currency: 'INR',
          category: ex.category,
          paidById: ex.paidBy,
          splitType: 'equal',
          participants,
          expenseDate: ex.date,
        },
      }, token);
      console.log(`  • ${ex.description}: ₹${ex.amount}`);
    } catch (e) {
      console.error(`  ✗ ${ex.description}: ${e.message}`);
    }
  }

  console.log(`\n✓ Seed complete. Pull-to-refresh in the app to see it.`);
}

main().catch((e) => {
  console.error('\n✗ Seed failed:', e.message);
  process.exit(1);
});
