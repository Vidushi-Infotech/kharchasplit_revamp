/**
 * Shared currency helpers for push bodies and emails. Previously each
 * notification helper carried its own copy of the symbol map.
 */
const CURRENCY_SYMBOLS = { INR: '₹', USD: '$', EUR: '€', GBP: '£' };

/** '₹' for 'INR'; unknown codes fall back to the code itself. */
export function currencySymbol(code) {
  if (!code) return '₹';
  return CURRENCY_SYMBOLS[code] || code;
}

/** '₹500.00' — amount may arrive as a NUMERIC string from Postgres. */
export function formatMoney(amount, code) {
  const sym = currencySymbol(code);
  const num = (Number(amount) || 0).toFixed(2);
  // Multi-letter fallbacks read better with a space ("AED 500.00").
  return sym.length > 1 ? `${sym} ${num}` : `${sym}${num}`;
}
