/**
 * Personal mode insights: turns per-day, per-category totals into the
 * month summary the app's Insights tab draws. Pure, so it's unit-tested
 * without a database (tests/personalSummary.test.js).
 */

/** How many months the trend covers, ending with the chosen month. */
export const TREND_MONTHS = 6;

/** 'YYYY-MM' → 'YYYY-MM' shifted by [delta] months. */
export function shiftMonth(month, delta) {
  const [y, m] = month.split('-').map(Number);
  const d = new Date(Date.UTC(y, m - 1 + delta, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

export function isMonthString(value) {
  return typeof value === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(value);
}

function daysIn(month) {
  const [y, m] = month.split('-').map(Number);
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

const round2 = (n) => Math.round(n * 100) / 100;

/**
 * rows: [{ kind: 'expense'|'income', category, day: 'YYYY-MM-DD', total }]
 * covering at least the trend window. Returns:
 * {
 *   month, previousMonth,
 *   spent, income, previousSpent, previousIncome,
 *   categories:       [{ category, amount, previousAmount }]  (spending, biggest first)
 *   incomeCategories: [{ category, amount }]                  (biggest first)
 *   daily:  [{ day, spent, income }]  one per day of the month
 *   trend:  [{ month, spent, income }] oldest first, TREND_MONTHS long
 * }
 */
export function buildPersonalSummary(rows, month) {
  const previousMonth = shiftMonth(month, -1);
  const trendMonths = [];
  for (let i = TREND_MONTHS - 1; i >= 0; i--) trendMonths.push(shiftMonth(month, -i));
  const trend = new Map(trendMonths.map((m) => [m, { month: m, spent: 0, income: 0 }]));

  const n = daysIn(month);
  const daily = Array.from({ length: n }, (_, i) => ({
    day: `${month}-${String(i + 1).padStart(2, '0')}`,
    spent: 0,
    income: 0,
  }));

  const spentBy = new Map();
  const prevSpentBy = new Map();
  const incomeBy = new Map();

  for (const r of rows) {
    const amount = Number(r.total) || 0;
    const rowMonth = r.day.slice(0, 7);
    const isIncome = r.kind === 'income';
    const category = r.category || (isIncome ? 'other_income' : 'other');
    const field = isIncome ? 'income' : 'spent';

    const t = trend.get(rowMonth);
    if (t) t[field] += amount;

    if (rowMonth === month) {
      daily[Number(r.day.slice(8, 10)) - 1][field] += amount;
      const by = isIncome ? incomeBy : spentBy;
      by.set(category, (by.get(category) || 0) + amount);
    } else if (rowMonth === previousMonth && !isIncome) {
      prevSpentBy.set(category, (prevSpentBy.get(category) || 0) + amount);
    }
  }

  const sum = (map) => [...map.values()].reduce((a, b) => a + b, 0);
  const categoryIds = new Set([...spentBy.keys(), ...prevSpentBy.keys()]);

  return {
    month,
    previousMonth,
    spent: round2(sum(spentBy)),
    income: round2(sum(incomeBy)),
    previousSpent: round2(sum(prevSpentBy)),
    previousIncome: round2(trend.get(previousMonth)?.income ?? 0),
    categories: [...categoryIds]
      .map((category) => ({
        category,
        amount: round2(spentBy.get(category) || 0),
        previousAmount: round2(prevSpentBy.get(category) || 0),
      }))
      .sort((a, b) => b.amount - a.amount || b.previousAmount - a.previousAmount),
    incomeCategories: [...incomeBy.entries()]
      .map(([category, amount]) => ({ category, amount: round2(amount) }))
      .sort((a, b) => b.amount - a.amount),
    daily: daily.map((d) => ({ ...d, spent: round2(d.spent), income: round2(d.income) })),
    trend: [...trend.values()].map((t) => ({
      ...t,
      spent: round2(t.spent),
      income: round2(t.income),
    })),
  };
}
