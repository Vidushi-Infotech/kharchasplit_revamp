import Group from '../models/Group.js';
import GroupService from '../services/groupService.js';
import { query } from '../config/database.js';
import {
  findRule, listGroupRules, ruleJson, templateFrom, pauseRule, resumeRule,
} from '../services/recurringService.js';
import { FREQUENCIES, isDateString, occurrenceDate } from '../utils/recurrence.js';
import { parsePayers, checkTotals, splitInput } from '../utils/expenseInput.js';

/**
 * Recurring expense rules. Any group member can see them; the creator or a
 * group admin can change, pause, resume or stop one. Stopping keeps the
 * expenses already created.
 */

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const forbidden = (res, msg) => res.status(403).json({ success: false, error: msg });

/** The rule if the caller may see it (and change it, with `manage`). */
async function loadRule(req, res, { manage = false } = {}) {
  const rule = UUID_RE.test(req.params.id) ? await findRule(req.params.id) : null;
  if (!rule) {
    res.status(404).json({ success: false, error: 'Recurring expense not found' });
    return null;
  }
  if (!(await Group.isMember(rule.group_id, req.user.id))) {
    forbidden(res, 'User is not a member of this group');
    return null;
  }
  if (manage && rule.created_by !== req.user.id && !(await Group.isAdmin(rule.group_id, req.user.id))) {
    forbidden(res, 'Only the person who set it up or a group admin can change it');
    return null;
  }
  return rule;
}

/** GET /groups/:id/recurring */
const listForGroup = async (req, res, next) => {
  try {
    await GroupService.validateGroupAccess(req.params.id, req.user.id);
    const rules = await listGroupRules(req.params.id);
    res.json({ success: true, data: rules.map(ruleJson) });
  } catch (error) {
    if (error.message === 'User is not a member of this group') return forbidden(res, error.message);
    next(error);
  }
};

/** GET /recurring/:id */
const getOne = async (req, res, next) => {
  try {
    const rule = await loadRule(req, res);
    if (rule) res.json({ success: true, data: ruleJson(rule) });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /recurring/:id — "this and future" edits.
 *   { template?: { description, amount, currency, category, notes,
 *                  splitType, splitMeta, payers, participants },
 *     frequency?, endDate? (null clears) }
 * Expenses already created are not touched.
 */
const update = async (req, res, next) => {
  try {
    const rule = await loadRule(req, res, { manage: true });
    if (!rule) return;
    const { template: t, frequency } = req.body;
    const sets = [];
    const params = [rule.id];
    const set = (sql, v) => { params.push(v); sets.push(`${sql} = $${params.length}`); };

    if (t !== undefined) {
      let payers;
      let split;
      try {
        if (typeof t?.description !== 'string' || !t.description.trim()) {
          return res.status(400).json({ success: false, error: 'template.description is required' });
        }
        payers = parsePayers(t.payers);
        checkTotals(t.amount, payers, t.participants);
        split = splitInput(t);
      } catch (e) {
        if (e.status === 400) return res.status(400).json({ success: false, code: e.code, error: e.message });
        throw e;
      }
      const people = [...new Set([...payers.map((p) => p.userId), ...t.participants.map((p) => p.userId)])];
      if (!people.every((id) => UUID_RE.test(String(id)))) {
        return res.status(400).json({ success: false, code: 'NOT_GROUP_MEMBER', error: 'Everyone on an expense must be a member of the group' });
      }
      const { rows } = await query(
        `SELECT user_id FROM group_members
          WHERE group_id = $1 AND deleted_at IS NULL AND user_id = ANY($2::uuid[])`,
        [rule.group_id, people],
      );
      if (rows.length !== people.length) {
        return res.status(400).json({ success: false, code: 'NOT_GROUP_MEMBER', error: 'Everyone on an expense must be a member of the group' });
      }
      set('template', JSON.stringify(templateFrom({
        ...t, splitType: split.splitType ?? t.splitType, splitMeta: split.splitMeta ?? null, payers,
      })));
    }

    if (frequency !== undefined && frequency !== rule.frequency) {
      if (!FREQUENCIES.includes(frequency)) {
        return res.status(400).json({ success: false, error: `frequency must be one of: ${FREQUENCIES.join(', ')}` });
      }
      // Keep the next date; the new rhythm starts from it.
      set('frequency', frequency);
      set('anchor_date', rule.next_run_date);
      set('next_index', 0);
    }

    if (req.body.endDate !== undefined) {
      const endDate = req.body.endDate;
      if (endDate !== null && (!isDateString(endDate) || endDate < rule.anchor_date)) {
        return res.status(400).json({ success: false, error: 'endDate must be a date after the first occurrence' });
      }
      set('end_date', endDate);
    }

    if (sets.length === 0) return res.json({ success: true, data: ruleJson(rule) });
    await query(`UPDATE recurring_rules SET ${sets.join(', ')}, updated_at = NOW() WHERE id = $1`, params);
    const updated = await findRule(rule.id);
    // A frequency change moved the anchor: keep next_run_date in step.
    if (updated.next_run_date !== occurrenceDate(updated.anchor_date, updated.frequency, updated.next_index)) {
      await query('UPDATE recurring_rules SET next_run_date = $2 WHERE id = $1',
        [rule.id, occurrenceDate(updated.anchor_date, updated.frequency, updated.next_index)]);
    }
    res.json({ success: true, data: ruleJson(await findRule(rule.id)) });
  } catch (error) {
    next(error);
  }
};

/** POST /recurring/:id/pause */
const pause = async (req, res, next) => {
  try {
    const rule = await loadRule(req, res, { manage: true });
    if (!rule) return;
    await pauseRule(rule, 'paused', { notify: false });
    res.json({ success: true, data: ruleJson(await findRule(rule.id)) });
  } catch (error) {
    next(error);
  }
};

/** POST /recurring/:id/resume — from the next date on or after today. */
const resume = async (req, res, next) => {
  try {
    const rule = await loadRule(req, res, { manage: true });
    if (!rule) return;
    const reason = await resumeRule(rule);
    if (reason) {
      return res.status(409).json({ success: false, code: 'CANNOT_RESUME', error: `Can't resume: ${reason}` });
    }
    res.json({ success: true, data: ruleJson(await findRule(rule.id)) });
  } catch (error) {
    next(error);
  }
};

/** DELETE /recurring/:id — stop repeating (created expenses stay). */
const stop = async (req, res, next) => {
  try {
    const rule = await loadRule(req, res, { manage: true });
    if (!rule) return;
    await query('UPDATE recurring_rules SET deleted_at = NOW() WHERE id = $1', [rule.id]);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};

export default { listForGroup, getOne, update, pause, resume, stop };
