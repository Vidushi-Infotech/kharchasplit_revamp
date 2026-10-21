import { query } from '../config/database.js';
import Group from '../models/Group.js';
import GroupService from '../services/groupService.js';
import { getRate, FxUnavailableError } from '../services/fxService.js';
import { isDateString, todayIST } from '../utils/recurrence.js';
import { toCsv } from '../utils/csv.js';

/** GET /fx/rate?from=USD&to=INR&date=YYYY-MM-DD → { rate, date } */
const fxRate = async (req, res, next) => {
  try {
    const from = String(req.query.from || '').toUpperCase();
    const to = String(req.query.to || '').toUpperCase();
    const today = todayIST();
    let date = isDateString(req.query.date) ? req.query.date : today;
    if (date > today) date = today;
    if (!/^[A-Z]{3}$/.test(from) || !/^[A-Z]{3}$/.test(to)) {
      return res.status(400).json({ success: false, error: 'from and to must be 3-letter currency codes' });
    }
    res.json({ success: true, data: { from, to, ...(await getRate(from, to, date)) } });
  } catch (error) {
    if (error instanceof FxUnavailableError) {
      return res.status(503).json({ success: false, code: error.code, error: error.message });
    }
    next(error);
  }
};

/**
 * GET /search?q=… — the caller's expenses (description / notes), groups
 * and friends matching q (case-insensitive, 2+ characters), 20 of each.
 */
const search = async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    if (q.length < 2) return res.json({ success: true, data: { expenses: [], groups: [], friends: [] } });
    if (q.length > 100) return res.status(400).json({ success: false, error: 'Search text is too long' });
    const like = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const me = req.user.id;

    const [expenses, groups, friends] = await Promise.all([
      query(
        `SELECT e.id, e.description, e.amount, e.currency, e.category,
                to_char(e.expense_date, 'YYYY-MM-DD') AS expense_date,
                e.group_id, g.name AS group_name, g.kind AS group_kind
           FROM expenses e
           JOIN groups g ON g.id = e.group_id AND g.deleted_at IS NULL
           JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $1 AND gm.deleted_at IS NULL
          WHERE e.deleted_at IS NULL
            AND (e.description ILIKE $2 OR e.notes ILIKE $2)
          ORDER BY e.expense_date DESC, e.created_at DESC
          LIMIT 20`,
        [me, like],
      ),
      query(
        `SELECT g.id, g.name, g.currency, g.is_archived
           FROM groups g
           JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1 AND gm.deleted_at IS NULL
          WHERE g.deleted_at IS NULL AND g.kind = 'group' AND g.name ILIKE $2
          ORDER BY g.updated_at DESC
          LIMIT 20`,
        [me, like],
      ),
      query(
        `SELECT DISTINCT u.id, u.name, u.profile_image_base64
           FROM group_members me
           JOIN group_members other ON other.group_id = me.group_id
                                   AND other.user_id <> me.user_id AND other.deleted_at IS NULL
           JOIN groups g ON g.id = me.group_id AND g.deleted_at IS NULL
           JOIN users u ON u.id = other.user_id AND u.deleted_at IS NULL
          WHERE me.user_id = $1 AND me.deleted_at IS NULL AND u.name ILIKE $2
          LIMIT 20`,
        [me, like],
      ),
    ]);

    res.json({
      success: true,
      data: {
        expenses: expenses.rows.map((e) => ({
          id: e.id,
          description: e.description,
          amount: Number(e.amount),
          currency: e.currency,
          category: e.category,
          date: e.expense_date,
          groupId: e.group_id,
          groupName: e.group_name,
          isDirect: e.group_kind === 'direct',
        })),
        groups: groups.rows.map((g) => ({ id: g.id, name: g.name, currency: g.currency, isArchived: !!g.is_archived })),
        friends: friends.rows.map((f) => ({ id: f.id, name: f.name, profileImageBase64: f.profile_image_base64 || null })),
      },
    });
  } catch (error) {
    next(error);
  }
};

const sendCsv = (res, filename, csv) => {
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.send(csv);
};

const safeName = (s) => String(s || 'export').replace(/[^\w-]+/g, '_').slice(0, 40);

/**
 * GET /groups/:id/export.csv — every expense of the group, one row each:
 * who paid how much and each member's share.
 */
const groupCsv = async (req, res, next) => {
  try {
    const { id } = req.params;
    await GroupService.validateGroupAccess(id, req.user.id);
    const group = await Group.findById(id);
    // Everyone in the group or on any of its expenses; names as the group
    // knows them (placeholders have no user name).
    const { rows: members } = await query(
      `SELECT u.id,
              COALESCE(NULLIF(u.name, ''), MAX(gm.name), 'Former member') AS name
         FROM users u
         LEFT JOIN group_members gm ON gm.group_id = $1 AND gm.user_id = u.id
        WHERE u.id IN (SELECT user_id FROM group_members WHERE group_id = $1)
           OR u.id IN (SELECT es.user_id FROM expense_splits es JOIN expenses e ON e.id = es.expense_id WHERE e.group_id = $1)
        GROUP BY u.id, u.name
        ORDER BY 2`,
      [id],
    );
    const { rows: expenses } = await query(
      `SELECT e.id, to_char(e.expense_date, 'YYYY-MM-DD') AS date, e.description, e.category,
              e.amount, e.currency, e.original_amount, e.original_currency, e.notes,
              (SELECT string_agg(COALESCE(u.name, '?') || ' ' || ep.amount, '; ' ORDER BY ep.amount DESC)
                 FROM expense_payers ep LEFT JOIN users u ON u.id = ep.user_id
                WHERE ep.expense_id = e.id) AS payers,
              pu.name AS paid_by_name
         FROM expenses e
         LEFT JOIN users pu ON pu.id = e.paid_by
        WHERE e.group_id = $1 AND e.deleted_at IS NULL
        ORDER BY e.expense_date, e.created_at`,
      [id],
    );
    const { rows: splits } = await query(
      `SELECT es.expense_id, es.user_id, es.amount
         FROM expense_splits es JOIN expenses e ON e.id = es.expense_id
        WHERE e.group_id = $1 AND e.deleted_at IS NULL AND es.deleted_at IS NULL`,
      [id],
    );
    const share = new Map(splits.map((s) => [`${s.expense_id}:${s.user_id}`, s.amount]));
    const header = ['Date', 'Description', 'Category', 'Amount', 'Currency', 'Original amount',
      'Original currency', 'Paid by', ...members.map((m) => `${m.name} share`), 'Notes'];
    const rows = expenses.map((e) => [
      e.date, e.description, e.category, e.amount, e.currency, e.original_amount, e.original_currency,
      e.payers || (e.paid_by_name ? `${e.paid_by_name} ${e.amount}` : ''),
      ...members.map((m) => share.get(`${e.id}:${m.id}`) ?? ''),
      e.notes,
    ]);
    sendCsv(res, `kharchasplit_${safeName(group?.name)}_${todayIST()}.csv`, toCsv(header, rows));
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({ success: false, error: error.message });
    }
    next(error);
  }
};

/**
 * GET /users/:id/expenses.csv — every expense the user is on, across
 * groups: what they paid and their share.
 */
const myExpensesCsv = async (req, res, next) => {
  try {
    if (req.params.id !== req.user.id) {
      return res.status(403).json({ success: false, error: 'You can only export your own expenses' });
    }
    const { rows } = await query(
      `SELECT to_char(e.expense_date, 'YYYY-MM-DD') AS date,
              CASE WHEN g.kind = 'direct' THEN 'Non-group expenses' ELSE g.name END AS group_name,
              e.description, e.category, e.amount, e.currency,
              COALESCE((SELECT ep.amount FROM expense_payers ep WHERE ep.expense_id = e.id AND ep.user_id = $1),
                       CASE WHEN e.paid_by = $1 THEN e.amount ELSE 0 END) AS you_paid,
              COALESCE((SELECT es.amount FROM expense_splits es
                         WHERE es.expense_id = e.id AND es.user_id = $1 AND es.deleted_at IS NULL), 0) AS your_share
         FROM expenses e
         JOIN groups g ON g.id = e.group_id AND g.deleted_at IS NULL
        WHERE e.deleted_at IS NULL
          AND (e.paid_by = $1
               OR EXISTS (SELECT 1 FROM expense_payers ep WHERE ep.expense_id = e.id AND ep.user_id = $1)
               OR EXISTS (SELECT 1 FROM expense_splits es WHERE es.expense_id = e.id AND es.user_id = $1 AND es.deleted_at IS NULL))
        ORDER BY e.expense_date, e.created_at`,
      [req.user.id],
    );
    const header = ['Date', 'Group', 'Description', 'Category', 'Amount', 'Currency', 'You paid', 'Your share'];
    sendCsv(res, `kharchasplit_my_expenses_${todayIST()}.csv`,
      toCsv(header, rows.map((r) => [r.date, r.group_name, r.description, r.category, r.amount, r.currency, r.you_paid, r.your_share])));
  } catch (error) {
    next(error);
  }
};

export default { fxRate, search, groupCsv, myExpensesCsv };
