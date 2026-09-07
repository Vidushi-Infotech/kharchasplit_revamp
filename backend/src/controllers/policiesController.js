/**
 * Static legal text served as structured sections so the client can render
 * with its own typography. Bump `version` and `lastUpdatedAt` when the text
 * changes — the client can use that to prompt re-acceptance later.
 */

const PRIVACY_POLICY = {
  title: 'Privacy Policy',
  version: '3.3.3',
  lastUpdatedAt: '2026-06-24',
  intro:
    'KharchaSplit ("the app") helps you split and track expenses with friends and groups. '
    + 'This policy explains what we collect, why, and how you stay in control.',
  sections: [
    {
      heading: 'What we collect',
      paragraphs: [
        'Account info: your phone number, name, and (optionally) email and profile photo.',
        'Activity in the app: the groups you create or join, the expenses you add, settlements, and your wallet sources for personal expenses.',
        'Device session info: the device name, OS version, app version, and IP address of every signed-in session — so you can see and revoke them in Active Sessions.',
        'Diagnostic info: occasional anonymized error reports that help us fix crashes.',
      ],
    },
    {
      heading: 'How we use it',
      paragraphs: [
        'To run the core features: showing your balances, syncing expenses across devices, sending notifications you opted into.',
        'To keep your account secure: detecting suspicious sign-ins and letting you sign out remotely.',
        'To improve the product: aggregated, non-identifying usage signals.',
        'We do not sell your data. We do not show ads.',
      ],
    },
    {
      heading: 'Who can see what',
      paragraphs: [
        'Group members see expenses, splits, and balances within groups you share with them.',
        'Personal expenses are visible only to you.',
        'Your phone number is shared with people who already have it in their contacts (so they can find and invite you).',
      ],
    },
    {
      heading: 'Your controls',
      paragraphs: [
        'Edit profile: change your name, email, or photo from Profile → Edit profile.',
        'Notifications: granular toggles in Profile → Notifications.',
        'Active sessions: see and sign out individual devices in Profile → Security → Active sessions.',
        'Download a copy of your data: Profile → Security → Download your data.',
        'Delete account: Profile → Security → Delete account permanently removes your account and all expense history.',
      ],
    },
    {
      heading: 'Data retention',
      paragraphs: [
        'Expense history is kept for as long as you have an account.',
        'Sign-in sessions expire after 30 days of inactivity. Revoked sessions are deleted immediately.',
        'When you delete your account, all your data is removed within 30 days.',
      ],
    },
    {
      heading: 'Contact',
      paragraphs: [
        'Questions or requests about your data? Email privacy@kharchasplit.app.',
      ],
    },
  ],
};

const TERMS = {
  title: 'Terms of Service',
  version: '3.3.3',
  lastUpdatedAt: '2026-06-24',
  intro:
    'By using KharchaSplit, you agree to these terms. They are short, written in plain language, and apply to everyone.',
  sections: [
    {
      heading: 'Your account',
      paragraphs: [
        'You are responsible for the activity on your account. Keep your phone number secure.',
        'Use the app for personal expense splitting only — not for commercial transactions or anything illegal.',
      ],
    },
    {
      heading: 'Content',
      paragraphs: [
        'You own the expense data, notes, and photos you add. By using the app you grant us a license to store and process that content to provide the service.',
        'Don\'t add content that is offensive, harasses others, or violates someone else\'s rights.',
      ],
    },
    {
      heading: 'Service',
      paragraphs: [
        'We work hard to keep the app online but can\'t guarantee 100% uptime.',
        'We may update or change features. We\'ll notify you of major changes.',
      ],
    },
    {
      heading: 'Termination',
      paragraphs: [
        'You can delete your account anytime.',
        'We can suspend or terminate accounts that violate these terms.',
      ],
    },
    {
      heading: 'Contact',
      paragraphs: [
        'Questions about these terms? Email support@kharchasplit.app.',
      ],
    },
  ],
};

const getPrivacy = (_req, res) => {
  res.json({ success: true, data: PRIVACY_POLICY });
};

const getTerms = (_req, res) => {
  res.json({ success: true, data: TERMS });
};

export default { getPrivacy, getTerms };
