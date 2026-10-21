import Expense from '../models/Expense.js';
import Group from '../models/Group.js';
import User from '../models/User.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';
import { NotificationService } from '../services/notificationService.js';
import { query } from '../config/database.js';

/**
 * Expense comments, edit history / restore and category suggestions.
 * All of it requires current membership of the expense's group.
 */

const COMMENT_MAX = 1000;

/**
 * A snapshot's expense_date as YYYY-MM-DD. Revisions saved before the
 * snapshot stored it as text hold a UTC timestamp of local midnight
 * (e.g. 2026-10-19T18:30:00.000Z for 20 Oct in IST) — read those back in
 * the server's local time, which is how they were produced.
 */
function snapshotDate(value) {
  if (typeof value !== 'string' || !value.includes('T')) return value;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return undefined;
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
const COMMENTS_PER_MINUTE = 10;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The live expense, or a sent 404/403 (returns null). */
async function loadExpense(req, res) {
  // Malformed ids (here or in :commentId / :revisionId) are just "not found".
  const ids = [req.params.id, req.params.commentId, req.params.revisionId].filter((v) => v !== undefined);
  const expense = ids.every((v) => UUID_RE.test(v)) ? await Expense.findById(req.params.id) : null;
  if (!expense) {
    res.status(404).json({ success: false, error: 'Expense not found' });
    return null;
  }
  try {
    await GroupService.validateGroupAccess(expense.group_id, req.user.id);
  } catch (e) {
    if (e.message === 'User is not a member of this group') {
      res.status(403).json({ success: false, error: e.message });
      return null;
    }
    throw e;
  }
  return expense;
}

const commentJson = (c, viewerId) => ({
  id: c.id,
  body: c.body,
  createdAt: c.created_at,
  user: { id: c.user_id, name: c.name || 'Former member', profileImageBase64: c.profile_image_base64 || null },
  canDelete: c.user_id === viewerId,
});

/** GET /expenses/:id/comments — oldest first. */
const listComments = async (req, res, next) => {
  try {
    if (!(await loadExpense(req, res))) return;
    const { rows } = await query(
      `SELECT c.id, c.body, c.created_at, c.user_id, u.name, u.profile_image_base64
         FROM expense_comments c LEFT JOIN users u ON u.id = c.user_id
        WHERE c.expense_id = $1 AND c.deleted_at IS NULL
        ORDER BY c.created_at`,
      [req.params.id],
    );
    res.json({ success: true, data: rows.map((c) => commentJson(c, req.user.id)) });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /expenses/:id/comments { body }
 * Notifies everyone on the expense (payers + split) except the author.
 */
const addComment = async (req, res, next) => {
  try {
    const expense = await loadExpense(req, res);
    if (!expense) return;
    const body = String(req.body.body ?? '').trim();
    if (body.length === 0 || body.length > COMMENT_MAX) {
      return res.status(400).json({ success: false, error: `Comment must be 1–${COMMENT_MAX} characters` });
    }
    const recent = await query(
      `SELECT COUNT(*)::int AS n FROM expense_comments
        WHERE user_id = $1 AND created_at > NOW() - INTERVAL '1 minute'`,
      [req.user.id],
    );
    if (recent.rows[0].n >= COMMENTS_PER_MINUTE) {
      return res.status(429).json({ success: false, error: 'You are commenting too fast. Try again in a minute.' });
    }

    const { rows: [c] } = await query(
      `INSERT INTO expense_comments (expense_id, user_id, body) VALUES ($1, $2, $3)
       RETURNING id, body, created_at, user_id`,
      [expense.id, req.user.id, body],
    );
    const author = await User.findById(req.user.id);

    try {
      const group = await Group.findById(expense.group_id);
      const recipients = [...new Set([
        expense.paid_by,
        ...(expense.payers || []).map((p) => p.user_id),
        ...(expense.participants || []).map((p) => p.user_id),
      ])].filter((id) => id && id !== req.user.id);
      await NotificationService.sendToUsers(recipients, 'EXPENSE_COMMENT', {
        authorName: author?.name || 'Someone',
        description: expense.description,
        comment: body.length > 80 ? `${body.slice(0, 79)}…` : body,
        groupName: group?.name || '',
        groupId: expense.group_id,
      }, { groupId: expense.group_id, expenseId: expense.id });
    } catch (notifError) {
      console.error('[ExpenseExtras] comment notify failed:', notifError);
    }

    res.status(201).json({
      success: true,
      data: commentJson({ ...c, name: author?.name, profile_image_base64: author?.profile_image_base64 }, req.user.id),
    });
  } catch (error) {
    next(error);
  }
};

/** DELETE /expenses/:id/comments/:commentId — the author only. */
const deleteComment = async (req, res, next) => {
  try {
    if (!(await loadExpense(req, res))) return;
    const { rowCount } = await query(
      `UPDATE expense_comments SET deleted_at = NOW()
        WHERE id = $1 AND expense_id = $2 AND user_id = $3 AND deleted_at IS NULL`,
      [req.params.commentId, req.params.id, req.user.id],
    );
    if (rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Comment not found (only its author can delete it)' });
    }
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /expenses/:id/history — the expense before each edit, newest first.
 * → { revisions: [{ id, editedBy, createdAt, snapshot }], users: { id: name } }
 */
const getHistory = async (req, res, next) => {
  try {
    if (!(await loadExpense(req, res))) return;
    const { rows } = await query(
      `SELECT r.id, r.edited_by, r.created_at, r.snapshot, u.name AS editor_name
         FROM expense_revisions r LEFT JOIN users u ON u.id = r.edited_by
        WHERE r.expense_id = $1
        ORDER BY r.created_at DESC
        LIMIT 100`,
      [req.params.id],
    );
    // Names for everyone a snapshot mentions, including people who left.
    const ids = new Set();
    for (const r of rows) {
      if (r.snapshot.paid_by) ids.add(r.snapshot.paid_by);
      for (const p of [...(r.snapshot.participants || []), ...(r.snapshot.payers || [])]) ids.add(p.user_id);
    }
    const names = ids.size === 0 ? [] : (await query(
      'SELECT id, name FROM users WHERE id = ANY($1::uuid[])', [[...ids]],
    )).rows;
    res.json({
      success: true,
      data: {
        revisions: rows.map((r) => ({
          id: r.id,
          editedBy: r.edited_by ? { id: r.edited_by, name: r.editor_name || 'Former member' } : null,
          createdAt: r.created_at,
          snapshot: r.snapshot,
        })),
        users: Object.fromEntries(names.map((u) => [u.id, u.name])),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /expenses/:id/history/:revisionId/restore
 * Puts the expense back the way it was before that edit — through the same
 * edit path, so the current state becomes a revision too and everyone on
 * it is notified. Same permission as editing (a payer).
 */
const restoreRevision = async (req, res, next) => {
  try {
    const expense = await loadExpense(req, res);
    if (!expense) return;
    const payerIds = (expense.payers || []).map((p) => p.user_id);
    if (!payerIds.includes(req.user.id) && expense.paid_by !== req.user.id) {
      return res.status(403).json({ success: false, error: 'Only the person who paid can edit this expense' });
    }
    const group = await Group.findById(expense.group_id);
    if (group?.is_archived) {
      return res.status(409).json({
        success: false,
        code: 'GROUP_ARCHIVED',
        error: 'This group is archived. Unarchive it to add or change expenses.',
      });
    }
    const { rows: [rev] } = await query(
      'SELECT snapshot FROM expense_revisions WHERE id = $1 AND expense_id = $2',
      [req.params.revisionId, expense.id],
    );
    if (!rev) return res.status(404).json({ success: false, error: 'Version not found' });
    const snap = rev.snapshot;

    // People in that version must still be in the group (or already on
    // the expense today).
    const wanted = [...new Set([snap.paid_by, ...snap.participants.map((p) => p.user_id),
      ...snap.payers.map((p) => p.user_id)].filter(Boolean))];
    const allowed = new Set([expense.paid_by, ...payerIds, ...expense.participants.map((p) => p.user_id)]);
    const toCheck = wanted.filter((id) => !allowed.has(id));
    if (toCheck.length > 0) {
      const { rows } = await query(
        `SELECT user_id FROM group_members
          WHERE group_id = $1 AND deleted_at IS NULL AND user_id = ANY($2::uuid[])`,
        [expense.group_id, toCheck],
      );
      if (rows.length !== toCheck.length) {
        return res.status(409).json({
          success: false,
          code: 'MEMBER_LEFT',
          error: 'Someone in that version has left the group, so it can\'t be restored',
        });
      }
    }

    const restored = await Expense.edit(expense.id, {
      description: snap.description,
      amount: snap.amount,
      currency: snap.currency,
      category: snap.category,
      notes: snap.notes,
      expenseDate: snapshotDate(snap.expense_date),
      paidById: snap.paid_by,
      splitType: snap.split_type,
      splitMeta: snap.split_meta ?? null,
    }, {
      participants: snap.participants.map((p) => ({
        userId: p.user_id, amount: p.amount, percentage: p.percentage, shares: p.shares,
      })),
      payers: snap.payers.map((p) => ({ userId: p.user_id, amount: p.amount })),
      editorId: req.user.id,
    });

    Expense.invalidateGroupExpenses(expense.group_id);
    await GroupService.invalidateMemberDashboards(expense.group_id);
    const actor = await User.findById(req.user.id);
    await ActivityService.logExpenseUpdated(
      expense.id, expense.group_id, req.user.id, group?.name || '',
      restored.description, restored.amount, restored.currency,
    );
    try {
      await NotificationService.notifyExpenseChanged('EXPENSE_UPDATED', {
        groupId: expense.group_id,
        groupName: group?.name || 'your group',
        expense: restored,
        actorId: req.user.id,
        actorName: actor?.name || 'Someone',
        affectedUserIds: [...allowed, ...wanted],
      });
    } catch (notifError) {
      console.error('[ExpenseExtras] restore notify failed:', notifError);
    }
    res.json({ success: true, message: 'Expense restored', data: restored });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /expenses/category-suggestion?description=Swiggy
 * The category the caller last used for the same description (last year),
 * or null. The app only applies it when the user hasn't picked one.
 */
const suggestCategory = async (req, res, next) => {
  try {
    const description = String(req.query.description ?? '').trim().toLowerCase();
    if (description.length < 2) return res.json({ success: true, data: { category: null } });
    const { rows: [row] } = await query(
      `SELECT e.category
         FROM expenses e
         JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $1 AND gm.deleted_at IS NULL
        WHERE e.deleted_at IS NULL AND e.category IS NOT NULL AND e.category <> ''
          AND LOWER(TRIM(e.description)) = $2
          AND e.created_at > NOW() - INTERVAL '365 days'
          AND (e.paid_by = $1 OR EXISTS (
            SELECT 1 FROM expense_splits es WHERE es.expense_id = e.id AND es.user_id = $1))
        ORDER BY e.created_at DESC
        LIMIT 1`,
      [req.user.id, description],
    );
    res.json({ success: true, data: { category: row?.category ?? null } });
  } catch (error) {
    next(error);
  }
};

export default {
  listComments,
  addComment,
  deleteComment,
  getHistory,
  restoreRevision,
  suggestCategory,
};
