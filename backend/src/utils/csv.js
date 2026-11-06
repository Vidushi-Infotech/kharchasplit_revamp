/**
 * CSV for spreadsheet apps. Cells starting with = + - @ (or tab/CR) are
 * prefixed with ' so Excel / Sheets never run them as formulas (CSV
 * injection — descriptions are user input). A UTF-8 BOM makes Excel read
 * ₹ and non-English text correctly.
 */
export function csvCell(value) {
  if (value === null || value === undefined) return '';
  let s = String(value);
  if (/^[=+\-@\t\r]/.test(s) && !/^-?\d+(\.\d+)?$/.test(s)) s = `'${s}`;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCsv(header, rows) {
  return `﻿${[header, ...rows].map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n`;
}
