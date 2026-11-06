import PersonalAccount from '../models/PersonalAccount.js';

const notFound = (res) =>
  res.status(404).json({ success: false, error: 'Account not found' });

/** GET /personal-accounts → the caller's accounts with their balances. */
const list = async (req, res, next) => {
  try {
    res.json({ success: true, data: await PersonalAccount.listForUser(req.user.id) });
  } catch (error) {
    next(error);
  }
};

/** POST /personal-accounts { name, type, balance } */
const create = async (req, res, next) => {
  try {
    const { name, type, balance } = req.body;
    const account = await PersonalAccount.create(req.user.id, { name, type, balance });
    res.status(201).json({ success: true, data: account });
  } catch (error) {
    next(error);
  }
};

/** PUT /personal-accounts/:id { name?, balance? } */
const update = async (req, res, next) => {
  try {
    const { name, balance } = req.body;
    const account = await PersonalAccount.update(req.user.id, req.params.id, { name, balance });
    if (!account) return notFound(res);
    res.json({ success: true, data: account });
  } catch (error) {
    next(error);
  }
};

/** DELETE /personal-accounts/:id — archives; entries keep it in history. */
const archive = async (req, res, next) => {
  try {
    if (!(await PersonalAccount.archive(req.user.id, req.params.id))) return notFound(res);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /personal-accounts/import { accounts: [{ key, name, type, balance }],
 * links: { expenseId: key } } — moves the phone-only wallet to the server
 * once; then returns the accounts.
 */
const importWallet = async (req, res, next) => {
  try {
    const { accounts = [], links = {} } = req.body;
    const { imported } = await PersonalAccount.importWallet(req.user.id, accounts, links);
    res.json({
      success: true,
      imported,
      data: await PersonalAccount.listForUser(req.user.id),
    });
  } catch (error) {
    next(error);
  }
};

/** GET /personal-accounts/transfers?accountId=&limit= */
const listTransfers = async (req, res, next) => {
  try {
    const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 50, 1), 200);
    const data = await PersonalAccount.listTransfers(req.user.id, {
      accountId: req.query.accountId || null,
      limit,
    });
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

/** POST /personal-accounts/transfers { fromAccountId, toAccountId, amount, note?, date? } */
const createTransfer = async (req, res, next) => {
  try {
    const { fromAccountId, toAccountId, amount, note, date } = req.body;
    if (fromAccountId === toAccountId) {
      return res.status(400).json({ success: false, error: 'Pick two different accounts' });
    }
    const [from, to] = await Promise.all([
      PersonalAccount.find(req.user.id, fromAccountId),
      PersonalAccount.find(req.user.id, toAccountId),
    ]);
    if (!from || !to) return notFound(res);
    const transfer = await PersonalAccount.createTransfer(req.user.id, {
      fromAccountId, toAccountId, amount, note, date,
    });
    res.status(201).json({ success: true, data: transfer });
  } catch (error) {
    next(error);
  }
};

/** DELETE /personal-accounts/transfers/:id */
const deleteTransfer = async (req, res, next) => {
  try {
    if (!(await PersonalAccount.deleteTransfer(req.user.id, req.params.id))) {
      return res.status(404).json({ success: false, error: 'Transfer not found' });
    }
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};

export default {
  list, create, update, archive, importWallet, listTransfers, createTransfer, deleteTransfer,
};
