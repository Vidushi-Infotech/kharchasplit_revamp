import { query, transaction } from '../config/database.js';
import Expense from '../models/Expense.js';
import GroupService from './groupService.js';
import ActivityService from './activityService.js';
import { NotificationService } from './notificationService.js';
import { occurrenceDate, firstIndexOnOrAfter, todayIST } from '../utils/recurrence.js';
import { largestPayer } from '../utils/expenseInput.js';
import { logger } from '../utils/logger.js';

/**
 * Recurring expenses. A rule stores the expense to create (`template`) and
 * when; jobs/recurringExpenseJob.js calls runDue() daily.
 *
 * Safety rules:
 * - One expense per (rule, date): recurring_occurrences' primary key, in the
 *   same transaction as the expense — restarts and extra instances can't
 *   duplicate.
 * - At most MAX_CATCH_UP missed occurrences are created in one run (e.g.
 *   after downtime); if more are due the rule is paused and its creator
 *   asked to check — never a burst of surprise expenses.
 * - If the group is archived/deleted, or the creator or anyone in the
 *   template has left the group, the rule is paused and the creator told.
 *   The split is never changed silently.
 * - Resuming skips what was missed while paused.
 */
export const MAX_CATCH_UP = 3;

// Dates as text: pg turns DATE into a JS Date at local midnight.
const RULE_COLUMNS = `r.id, r.group_id, r.created_by, r.template, r.frequency,
  to_char(r.anchor_date, 'YYYY-MM-DD') AS anchor_date, r.next_index,
  to_char(r.next_run_date, 'YYYY-MM-DD') AS next_run_date,
  to_char(r.end_date, 'YYYY-MM-DD') AS end_date, r.paused, r.pause_reason,
  r.created_at, r.updated_at`;

export function ruleJson(r) {
  return {
    id: r.id,
    groupId: r.group_id,
    createdBy: r.created_by,
    template: r.template,
    frequency: r.frequency,
    anchorDate: r.anchor_date,
    nextDate: r.next_run_date,
    endDate: r.end_date,
    paused: r.paused,
    pauseReason: r.pause_reason,
    createdAt: r.created_at,
  };
}

/** The expense a rule creates, from a validated create/edit payload. */
export function templateFrom(p) {
  return {
    description: p.description,
    amount: Number(p.amount).toFixed(2),
    currency: p.currency || 'INR',
    category: p.category || null,
    notes: p.notes || null,
    splitType: p.splitType || 'equal',
    splitMeta: p.splitMeta ?? null,
    payers: p.payers.map((x) => ({ userId: x.userId, amount: Number(x.amount).toFixed(2) })),
    participants: p.participants.map((x) => ({
      userId: x.userId,
      amount: x.amount,
      percentage: x.percentage ?? null,
      shares: x.shares ?? null,
    })),
  };
}

export async function findRule(id) {
  const { rows: [r] } = await query(
    `SELECT ${RULE_COLUMNS} FROM recurring_rules r WHERE r.id = $1 AND r.deleted_at IS NULL`,
    [id],
  );
  return r || null;
}

export async function listGroupRules(groupId) {
  const { rows } = await query(
    `SELECT ${RULE_COLUMNS} FROM recurring_rules r
      WHERE r.group_id = $1 AND r.deleted_at IS NULL
      ORDER BY r.paused, r.next_run_date`,
    [groupId],
  );
  return rows;
}

/**
 * Create a rule plus its first occurrence (the expense being added now, on
 * `anchorDate`) in the caller's transaction.
 * @returns {Promise<{rule, expense}>}
 */
export async function insertRuleWithFirstExpense(client, { groupId, createdBy, template, frequency, anchorDate, endDate, expenseData }) {
  const { rows: [rule] } = await client.query(
    `INSERT INTO recurring_rules (group_id, created_by, template, frequency, anchor_date,
                                  next_index, next_run_date, end_date)
     VALUES ($1, $2, $3, $4, $5, 1, $6, $7)
     RETURNING id`,
    [groupId, createdBy, JSON.stringify(template), frequency, anchorDate,
      occurrenceDate(anchorDate, frequency, 1), endDate || null],
  );
  const expense = await Expense.insertWith(
    client,
    { ...expenseData, expenseDate: anchorDate, recurringRuleId: rule.id },
    template.participants,
    template.payers,
  );
  await client.query(
    'INSERT INTO recurring_occurrences (rule_id, occurrence_date, expense_id) VALUES ($1, $2, $3)',
    [rule.id, anchorDate, expense.id],
  );
  return { ruleId: rule.id, expense };
}

/** Why the rule can't create an expense right now, or null. */
export async function blocker(rule) {
  const { rows: [g] } = await query(
    'SELECT deleted_at, is_archived FROM groups WHERE id = $1',
    [rule.group_id],
  );
  if (!g || g.deleted_at) return 'the group was deleted';
  if (g.is_archived) return 'the group is archived';
  const people = [...new Set([
    ...rule.template.payers.map((p) => p.userId),
    ...rule.template.participants.map((p) => p.userId),
  ])];
  const { rows } = await query(
    `SELECT user_id FROM group_members
      WHERE group_id = $1 AND deleted_at IS NULL AND user_id = ANY($2::uuid[])`,
    [rule.group_id, [...people, rule.created_by].filter(Boolean)],
  );
  const members = new Set(rows.map((r) => r.user_id));
  if (!rule.created_by || !members.has(rule.created_by)) return 'its creator is no longer in the group';
  if (!people.every((id) => members.has(id))) return 'someone in it has left the group';
  return null;
}

async function groupName(groupId) {
  const { rows: [g] } = await query('SELECT name FROM groups WHERE id = $1', [groupId]);
  return g?.name || 'your group';
}

/** Pause a rule (and tell its creator why, unless it just ended). */
export async function pauseRule(rule, reason, { notify = true } = {}) {
  await query(
    `UPDATE recurring_rules SET paused = TRUE, pause_reason = $2, updated_at = NOW()
      WHERE id = $1 AND NOT paused`,
    [rule.id, reason],
  );
  if (!notify || !rule.created_by) return;
  try {
    await NotificationService.sendToUser(rule.created_by, 'RECURRING_PAUSED', {
      description: rule.template.description,
      groupName: await groupName(rule.group_id),
      reason,
      groupId: rule.group_id,
    }, { groupId: rule.group_id, recurringRuleId: rule.id });
  } catch (e) {
    logger.warn({ err: e.message }, '[recurring] pause notify failed');
  }
}

/**
 * Resume a paused rule from the next occurrence on or after today; what
 * was missed while paused is skipped. Returns the blocker text instead
 * when it still can't run.
 */
export async function resumeRule(rule, today = todayIST()) {
  const reason = await blocker(rule);
  if (reason) return reason;
  const n = Math.max(rule.next_index, firstIndexOnOrAfter(rule.anchor_date, rule.frequency, today));
  await query(
    `UPDATE recurring_rules
        SET paused = FALSE, pause_reason = NULL, next_index = $2, next_run_date = $3, updated_at = NOW()
      WHERE id = $1`,
    [rule.id, n, occurrenceDate(rule.anchor_date, rule.frequency, n)],
  );
  return null;
}

/** Create occurrence n. Returns the expense, or null if it already existed. */
async function createOccurrence(rule, n) {
  const date = occurrenceDate(rule.anchor_date, rule.frequency, n);
  const t = rule.template;
  return transaction(async (client) => {
    await client.query(
      `UPDATE recurring_rules SET next_index = $2, next_run_date = $3, updated_at = NOW()
        WHERE id = $1 AND next_index <= $4`,
      [rule.id, n + 1, occurrenceDate(rule.anchor_date, rule.frequency, n + 1), n],
    );
    const ins = await client.query(
      `INSERT INTO recurring_occurrences (rule_id, occurrence_date) VALUES ($1, $2)
       ON CONFLICT DO NOTHING RETURNING rule_id`,
      [rule.id, date],
    );
    if (ins.rowCount === 0) return null;
    const expense = await Expense.insertWith(client, {
      groupId: rule.group_id,
      description: t.description,
      amount: t.amount,
      currency: t.currency,
      category: t.category,
      notes: t.notes,
      paidById: largestPayer(t.payers),
      splitType: t.splitType,
      splitMeta: t.splitMeta,
      expenseDate: date,
      recurringRuleId: rule.id,
    }, t.participants, t.payers);
    await client.query(
      'UPDATE recurring_occurrences SET expense_id = $3 WHERE rule_id = $1 AND occurrence_date = $2',
      [rule.id, date, expense.id],
    );
    return expense;
  });
}

async function afterCreate(rule, expense) {
  Expense.invalidateGroupExpenses(rule.group_id);
  await GroupService.invalidateMemberDashboards(rule.group_id);
  const name = await groupName(rule.group_id);
  await ActivityService.logExpenseAdded(
    expense.id, rule.group_id, rule.created_by, name,
    expense.description, expense.amount, expense.currency,
  );
  try {
    // Automatic, so everyone hears — the creator included. Payers get no
    // "you owe" line (they paid for it).
    const payerIds = new Set(rule.template.payers.map((p) => p.userId));
    await NotificationService.notifyExpenseAdded(
      rule.group_id, expense, 'Recurring', name, expense.currency, null,
      rule.template.participants.filter((p) => !payerIds.has(p.userId)),
      'RECURRING_EXPENSE_ADDED',
    );
  } catch (e) {
    logger.warn({ err: e.message }, '[recurring] notify failed');
  }
}

/**
 * Create every occurrence due on or before `today` (India). Safe to run
 * repeatedly and concurrently.
 * @returns {Promise<{rules, created, paused}>}
 */
export async function runDue(today = todayIST()) {
  const { rows: rules } = await query(
    `SELECT ${RULE_COLUMNS} FROM recurring_rules r
      WHERE r.deleted_at IS NULL AND NOT r.paused AND r.next_run_date <= $1
      ORDER BY r.next_run_date
      LIMIT 500`,
    [today],
  );
  let created = 0;
  let paused = 0;
  for (const rule of rules) {
    try {
      const due = [];
      for (let n = rule.next_index; due.length <= MAX_CATCH_UP; n += 1) {
        const d = occurrenceDate(rule.anchor_date, rule.frequency, n);
        if (d > today || (rule.end_date && d > rule.end_date)) break;
        due.push(n);
      }
      if (due.length === 0) {
        // Past its end date: finished, nothing to tell anyone.
        if (rule.end_date && rule.next_run_date > rule.end_date) await pauseRule(rule, 'ended', { notify: false });
        continue;
      }
      const reason = await blocker(rule);
      if (reason) {
        await pauseRule(rule, reason);
        paused += 1;
        continue;
      }
      for (const n of due.slice(0, MAX_CATCH_UP)) {
        const expense = await createOccurrence(rule, n);
        if (expense) {
          created += 1;
          await afterCreate(rule, expense);
        }
      }
      if (due.length > MAX_CATCH_UP) {
        await pauseRule(rule, 'more occurrences were missed than can be added automatically. Check the group and resume');
        paused += 1;
      }
    } catch (e) {
      logger.error({ err: e, ruleId: rule.id }, '[recurring] rule failed');
    }
  }
  return { rules: rules.length, created, paused };
}
