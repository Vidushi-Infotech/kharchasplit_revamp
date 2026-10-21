/**
 * Notification email templates.
 *
 * Every template returns { subject, text, html } and is rendered through one
 * shared layout so the brand header, spacing and footer stay consistent.
 * NotificationService looks templates up by notification type (see the
 * `email` field in NOTIFICATION_TYPES) and hands the result to EmailOutbox.
 *
 * Templates receive `(data, recipient)` where `data` is the same payload the
 * push uses and `recipient` is { name, email }.
 */
import { formatMoney } from '../utils/currency.js';

const BRAND = '#0d9d6f';

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * Shared layout.
 *
 * @param {Object} o
 * @param {string}   o.heading     Title in the green header band.
 * @param {string}   o.greetingName
 * @param {string[]} o.paragraphs  Plain text; rendered escaped.
 * @param {string}   [o.highlight] Big centered value (an amount).
 * @param {Array<[string,string]>} [o.details] Label/value rows.
 * @param {Array<{title: string, rows: Array<[string,string]>}>} [o.sections]
 *        Titled label/value tables, rendered after `details`.
 * @param {string}   [o.footnote]  Small grey line under the body.
 * @param {string}   [o.footer]    Grey band at the bottom.
 */
export function renderLayout({ heading, greetingName, paragraphs = [], highlight, details = [], sections = [], footnote, footer }) {
  const name = (greetingName || 'there').trim() || 'there';

  const text = [
    `Hi ${name},`,
    '',
    ...paragraphs.flatMap((p) => [p, '']),
    ...(highlight ? [highlight, ''] : []),
    ...details.map(([k, v]) => `${k}: ${v}`),
    ...(details.length ? [''] : []),
    ...sections.flatMap((sec) => [sec.title, ...sec.rows.map(([k, v]) => `  ${k}: ${v}`), '']),
    ...(footnote ? [footnote, ''] : []),
    '— The KharchaSplit Team',
  ].join('\n');

  const paragraphHtml = paragraphs
    .map((p) => `<p style="margin:0 0 16px;font-size:15px;line-height:1.55;color:#5a6478;">${escapeHtml(p)}</p>`)
    .join('\n            ');

  const highlightHtml = highlight
    ? `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:4px auto 24px;">
              <tr><td align="center" style="padding:18px 32px;background:#f1f8f5;border:1px solid #cfe8db;border-radius:10px;">
                <div style="font-size:32px;font-weight:700;color:${BRAND};">${escapeHtml(highlight)}</div>
              </td></tr>
            </table>`
    : '';

  const rowsTable = (rows) => `<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="margin:0 0 20px;border:1px solid #e6e9ef;border-radius:10px;">
              ${rows
                .map(
                  ([k, v]) => `<tr>
                <td style="padding:10px 14px;font-size:13px;color:#7a8499;border-bottom:1px solid #f0f2f5;">${escapeHtml(k)}</td>
                <td style="padding:10px 14px;font-size:14px;color:#1a1f2e;border-bottom:1px solid #f0f2f5;text-align:right;">${escapeHtml(v)}</td>
              </tr>`,
                )
                .join('')}
            </table>`;

  const sectionsHtml = sections
    .map((sec) => `<p style="margin:0 0 8px;font-size:13px;font-weight:700;letter-spacing:0.4px;color:#5a6478;text-transform:uppercase;">${escapeHtml(sec.title)}</p>
            ${rowsTable(sec.rows)}`)
    .join('\n            ');

  const detailsHtml = details.length ? rowsTable(details) : '';

  const footnoteHtml = footnote
    ? `<p style="margin:0;font-size:13px;line-height:1.55;color:#7a8499;">${escapeHtml(footnote)}</p>`
    : '';

  const footerHtml = footer
    ? `<tr><td style="padding:18px 32px;background:#f5f7fa;color:#7a8499;font-size:12px;line-height:1.5;text-align:center;">${escapeHtml(footer)}</td></tr>`
    : '';

  const html = `
<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f5f7fa;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1a1f2e;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="padding:32px 16px;">
      <tr><td align="center">
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e6e9ef;">
          <tr><td style="padding:28px 32px;background:${BRAND};color:#ffffff;">
            <div style="font-size:14px;letter-spacing:1.5px;opacity:0.85;">KHARCHASPLIT</div>
            <div style="font-size:22px;font-weight:700;margin-top:6px;">${escapeHtml(heading)}</div>
          </td></tr>
          <tr><td style="padding:28px 32px;">
            <p style="margin:0 0 12px;font-size:16px;">Hi ${escapeHtml(name)},</p>
            ${paragraphHtml}
            ${highlightHtml}
            ${detailsHtml}
            ${sectionsHtml}
            ${footnoteHtml}
          </td></tr>
          ${footerHtml}
        </table>
      </td></tr>
    </table>
  </body>
</html>`.trim();

  return { text, html };
}

const OPT_OUT = 'You can turn off these emails in the app: Profile → Notifications → Email.';
const SECURITY_FOOTER = 'This is a security notice and is sent even if notification emails are turned off.';

function fmtWhen(iso) {
  const d = iso ? new Date(iso) : new Date();
  return d.toLocaleString('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Kolkata',
  }) + ' IST';
}

// =====================
// Money events
// =====================

export function settlementReceived(d, r) {
  const amount = formatMoney(d.amount, d.currencyCode);
  return {
    subject: `${d.fromUserName} paid you ${amount} on KharchaSplit`,
    ...renderLayout({
      heading: 'Payment received',
      greetingName: r.name,
      paragraphs: [`${d.fromUserName} paid you ${amount} in "${d.groupName}".`],
      highlight: amount,
      details: d.notes ? [['Note', d.notes]] : [],
      footnote: "The balance has been updated in the app. Open the group's Balances tab to see who has settled and who still owes.",
      footer: OPT_OUT,
    }),
  };
}

export function settlementDeleted(d, r) {
  const amount = formatMoney(d.amount, d.currencyCode);
  return {
    subject: `A ${amount} payment was deleted in "${d.groupName}"`,
    ...renderLayout({
      heading: 'Payment deleted',
      greetingName: r.name,
      paragraphs: [
        `${d.actorName} deleted a ${amount} payment from ${d.fromUserName} to ${d.toUserName} in "${d.groupName}".`,
        'The balance has been recalculated, so that amount now shows as owed again.',
      ],
      highlight: amount,
      footnote: "If this wasn't expected, talk to the people involved or check the group's activity in the app.",
      footer: OPT_OUT,
    }),
  };
}

export function settlementReminder(d, r) {
  const amount = formatMoney(d.amount, d.currencyCode);
  return {
    subject: `Reminder: you owe ${d.fromUserName} ${amount} in "${d.groupName}"`,
    ...renderLayout({
      heading: 'Time to settle up',
      greetingName: r.name,
      paragraphs: [d.auto === 'true'
        ? `Your balance with ${d.fromUserName} in "${d.groupName}" is still open.`
        : `${d.fromUserName} sent you a friendly reminder about your balance in "${d.groupName}".`],
      highlight: amount,
      footnote: 'Open the group in the app and tap Settle Up once you have paid. The balance updates for both of you right away.',
      footer: OPT_OUT,
    }),
  };
}

// =====================
// Group events
// =====================

export function groupDeleted(d, r) {
  return {
    subject: `"${d.groupName}" was deleted on KharchaSplit`,
    ...renderLayout({
      heading: 'Group deleted',
      greetingName: r.name,
      paragraphs: [
        `${d.actorName} deleted the group "${d.groupName}".`,
        'All balances in this group were settled before it was deleted, so nobody owes anything from it.',
      ],
      footnote: 'You can still download your own data from Profile → Security → Download your data.',
      footer: OPT_OUT,
    }),
  };
}

export function groupInvite(d, r) {
  return {
    subject: `${d.inviterName} added you to "${d.groupName}" on KharchaSplit`,
    ...renderLayout({
      heading: 'You were added to a group',
      greetingName: r.name,
      paragraphs: [
        `${d.inviterName} added you to "${d.groupName}".`,
        'Open the app to see the group, add shared expenses and keep track of who owes what.',
      ],
      footer: OPT_OUT,
    }),
  };
}

/** The removed member's own copy, including any balances written off. */
export function removedFromGroup(d, r) {
  const writeOffs = (d.writeOffs || []).map((w) => [
    w.youOwed ? `You owed ${w.otherName}` : `${w.otherName} owed you`,
    formatMoney(w.amount, d.currencyCode),
  ]);
  return {
    subject: `You were removed from "${d.groupName}"`,
    ...renderLayout({
      heading: 'Removed from group',
      greetingName: r.name,
      paragraphs: [
        `${d.actorName} removed you from "${d.groupName}".`,
        ...(writeOffs.length
          ? ['These open balances were written off when you were removed, so they no longer show in the app:']
          : ['You had no open balances in this group.']),
      ],
      details: writeOffs,
      footnote: writeOffs.length ? 'If you still want to settle any of these, do it directly with the person.' : undefined,
      footer: OPT_OUT,
    }),
  };
}

/** A member who lost (or was cleared of) a balance because someone was removed. */
export function balanceWrittenOff(d, r) {
  const amount = formatMoney(d.amount, d.currencyCode);
  const line = d.youOwed === 'true' || d.youOwed === true
    ? `You owed ${d.memberName} ${amount}. That amount has been cleared from your balance.`
    : `${d.memberName} owed you ${amount}. That amount has been written off and no longer shows as owed.`;
  return {
    subject: `${amount} written off in "${d.groupName}"`,
    ...renderLayout({
      heading: 'Balance written off',
      greetingName: r.name,
      paragraphs: [`${d.actorName} removed ${d.memberName} from "${d.groupName}" while a balance between you two was still open.`, line],
      highlight: amount,
      footnote: 'If this is not right, settle it directly with the person.',
      footer: OPT_OUT,
    }),
  };
}

/** Archived / completed group: one summary per member with their open balances. */
export function groupClosedSummary(d, r) {
  const verb = d.closeKind === 'completed' ? 'marked as complete' : 'archived';
  const rows = (d.balances || []).map((b) => [
    b.youOwe ? `You owe ${b.otherName}` : `${b.otherName} owes you`,
    formatMoney(b.amount, d.currencyCode),
  ]);
  return {
    subject: `"${d.groupName}" was ${verb} — your summary`,
    ...renderLayout({
      heading: d.closeKind === 'completed' ? 'Group completed' : 'Group archived',
      greetingName: r.name,
      paragraphs: [
        `${d.actorName} ${verb} "${d.groupName}".`,
        rows.length ? 'You still have open balances in this group:' : 'You are all settled up in this group.',
      ],
      details: [
        ['Total spent in group', formatMoney(d.totalSpent, d.currencyCode)],
        ...rows,
      ],
      footnote: rows.length ? 'You can still open the group in the app and settle up.' : undefined,
      footer: OPT_OUT,
    }),
  };
}

/** Weekly digest (opt-in). Amounts are pre-formatted by the job. */
export function weeklySummary(d, r) {
  return {
    subject: `Your KharchaSplit week: ${d.weekLabel}`,
    ...renderLayout({
      heading: 'Your week on KharchaSplit',
      greetingName: r.name,
      paragraphs: [
        `Here's what happened in your groups from ${d.weekLabel}.`,
        ...(d.balances.length ? [] : ['You are all settled up in every group. Nice.']),
      ],
      sections: [
        ...(d.stats.length ? [{ title: 'This week', rows: d.stats }] : []),
        ...(d.balances.length ? [{ title: 'Open balances right now', rows: d.balances }] : []),
      ],
      footnote: d.balances.length ? 'Open the app to settle up or send a reminder.' : undefined,
      footer: 'You get this because Weekly summary is on in Profile → Notifications. Turn it off there anytime.',
    }),
  };
}

// =====================
// Account
// =====================

export function welcome(d, r) {
  return {
    subject: 'Welcome to KharchaSplit',
    ...renderLayout({
      heading: 'Welcome to KharchaSplit',
      greetingName: r.name,
      paragraphs: [
        'Your account is ready. Create a group for your trip, flat or office lunches, add expenses as they happen, and KharchaSplit keeps track of who owes whom.',
        'When someone settles up with you, you get a notification and an email right away.',
      ],
      footnote: 'One more step: verify this email address (Profile → Verify) so you can always recover your account.',
      footer: OPT_OUT,
    }),
  };
}

// =====================
// Security events (always sent)
// =====================

export function newLogin(d, r) {
  const device = [d.deviceName, d.platform].filter(Boolean).join(' · ') || 'Unknown device';
  return {
    subject: 'New sign-in to your KharchaSplit account',
    ...renderLayout({
      heading: 'New sign-in',
      greetingName: r.name,
      paragraphs: ['Your KharchaSplit account was just signed in on a device we have not seen before.'],
      details: [
        ['Device', device],
        ['When', fmtWhen(d.at)],
        ...(d.ipAddress ? [['IP address', d.ipAddress]] : []),
      ],
      footnote: "If this was you, you don't need to do anything. If not, open the app → Profile → Security → Sign out everywhere, then reset your password.",
      footer: SECURITY_FOOTER,
    }),
  };
}

export function passwordChanged(d, r) {
  return {
    subject: 'Your KharchaSplit password was changed',
    ...renderLayout({
      heading: 'Password changed',
      greetingName: r.name,
      paragraphs: ['The password for your KharchaSplit account was just changed.'],
      details: [['When', fmtWhen(d.at)]],
      footnote: "If you did this, you're all set. If not, reset your password right away using \"Forgot password\" on the sign-in screen.",
      footer: SECURITY_FOOTER,
    }),
  };
}

export function accountDeleted(d, r) {
  return {
    subject: 'Your KharchaSplit account has been deleted',
    ...renderLayout({
      heading: 'Account deleted',
      greetingName: r.name,
      paragraphs: [
        'Your KharchaSplit account has been deleted as requested, and it can no longer be used to sign in.',
        'Thanks for using KharchaSplit.',
      ],
      details: [['When', fmtWhen(d.at)]],
      footnote: "If you didn't request this, reply to this email or contact support as soon as possible.",
      footer: SECURITY_FOOTER,
    }),
  };
}

export function sessionsRevoked(d, r) {
  return {
    subject: 'You were signed out of other devices',
    ...renderLayout({
      heading: 'Signed out everywhere',
      greetingName: r.name,
      paragraphs: [`Your KharchaSplit account was signed out of ${d.revokedCount} other session${Number(d.revokedCount) === 1 ? '' : 's'}.`],
      details: [['When', fmtWhen(d.at)]],
      footnote: "If you didn't do this, reset your password right away using \"Forgot password\" on the sign-in screen.",
      footer: SECURITY_FOOTER,
    }),
  };
}
