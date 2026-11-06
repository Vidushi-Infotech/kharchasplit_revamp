import PersonalBill from '../models/PersonalBill.js';
import PersonalAccount from '../models/PersonalAccount.js';

const notFound = (res) => res.status(404).json({ success: false, error: 'Bill not found' });

/** 404s unless [accountId] is empty or one of the caller's accounts. */
const accountMissing = async (req, res, accountId) => {
  if (!accountId) return false;
  if (await PersonalAccount.find(req.user.id, accountId)) return false;
  res.status(404).json({ success: false, error: 'Account not found' });
  return true;
};

/** GET /personal-bills → bills by next due date, with status. */
const list = async (req, res, next) => {
  try {
    res.json({ success: true, data: await PersonalBill.listForUser(req.user.id) });
  } catch (error) {
    next(error);
  }
};

/** POST /personal-bills { name, amount, category?, accountId?, frequency, dueDate, remindDays? } */
const create = async (req, res, next) => {
  try {
    if (await accountMissing(req, res, req.body.accountId)) return;
    res.status(201).json({ success: true, data: await PersonalBill.create(req.user.id, req.body) });
  } catch (error) {
    next(error);
  }
};

/** PUT /personal-bills/:id — any of the create fields. */
const update = async (req, res, next) => {
  try {
    if (await accountMissing(req, res, req.body.accountId)) return;
    const bill = await PersonalBill.update(req.user.id, req.params.id, req.body);
    if (!bill) return notFound(res);
    res.json({ success: true, data: bill });
  } catch (error) {
    next(error);
  }
};

/** DELETE /personal-bills/:id — archives; past payments stay. */
const archive = async (req, res, next) => {
  try {
    if (!(await PersonalBill.archive(req.user.id, req.params.id))) return notFound(res);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};

/** POST /personal-bills/:id/pay { amount?, accountId?, date? } */
const pay = async (req, res, next) => {
  try {
    const { amount, accountId, date } = req.body;
    if (await accountMissing(req, res, accountId)) return;
    const result = await PersonalBill.pay(req.user.id, req.params.id, { amount, accountId, date });
    if (!result) return notFound(res);
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
};

/** POST /personal-bills/:id/skip */
const skip = async (req, res, next) => {
  try {
    const bill = await PersonalBill.skip(req.user.id, req.params.id);
    if (!bill) return notFound(res);
    res.json({ success: true, data: bill });
  } catch (error) {
    next(error);
  }
};

/** GET /personal-bills/:id/payments */
const payments = async (req, res, next) => {
  try {
    if (!(await PersonalBill.find(req.user.id, req.params.id))) return notFound(res);
    res.json({ success: true, data: await PersonalBill.payments(req.user.id, req.params.id) });
  } catch (error) {
    next(error);
  }
};

export default { list, create, update, archive, pay, skip, payments };
