import rateLimit from 'express-rate-limit';

/**
 * Targeted rate limits.
 *
 * The global IP limiter in server.js is intentionally generous (200/min) so
 * a household NAT or office Wi-Fi behind one public IP doesn't trip it. The
 * limiters below cover the two real abuse vectors:
 *
 *   1. OTP spam — keyed by phone number, not IP.
 *      Prevents an attacker from bombarding a victim's phone with SMS, and
 *      caps cost (each send is paid SMS once Twilio is wired).
 *
 *   2. Expense create flood — keyed by authenticated user.
 *      Bounds blast radius if a session token is leaked, and protects the
 *      DB from a runaway client.
 *
 * For multi-instance deploys, swap the in-memory store for `rate-limit-redis`
 * (constructor signature is identical — just pass `store: new RedisStore(...)`).
 */

const TOO_MANY_OTP = {
  success: false,
  error: 'Too many OTP requests for this number. Try again in a few minutes.',
};

const TOO_MANY_EXPENSES = {
  success: false,
  error: 'Too many expenses created in a short window. Slow down a moment.',
};

const TOO_MANY_LOGINS = {
  success: false,
  error: 'Too many login attempts. Try again in a few minutes.',
};

const TOO_MANY_RESETS = {
  success: false,
  error: 'Too many password reset requests for this email. Try again later.',
};

/**
 * 5 OTP requests per phone every 15 minutes. Keys on the *body* phone
 * number rather than IP so a real victim isn't locked out by an attacker
 * sharing their NAT.
 */
export const otpRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: TOO_MANY_OTP,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const phone = (req.body?.phoneNumber || '').toString().trim();
    // If phone is missing the validator will reject with 400; bucket those
    // by IP so we still throttle bare requests.
    return phone || `ip:${req.ip}`;
  },
});

/**
 * 10 login attempts per phone every 15 min. Keyed on the body phone number
 * so a victim of credential stuffing isn't locked out by an attacker on the
 * same NAT.
 */
export const loginRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: TOO_MANY_LOGINS,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const phone = (req.body?.phoneNumber || '').toString().trim();
    return phone || `ip:${req.ip}`;
  },
});

/**
 * 5 password-reset requests per email every 15 min. Email-keyed for the
 * same reason as the phone-keyed OTP limiter — fairness across users
 * behind a shared IP, and per-email cost cap for SMTP.
 */
export const passwordResetRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: TOO_MANY_RESETS,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const email = (req.body?.email || '').toString().trim().toLowerCase();
    return email || `ip:${req.ip}`;
  },
});

/**
 * 60 expense creates per authenticated user per minute. Generous for real
 * use (one bill = one POST), tight enough that a leaked token can't drain
 * the DB.
 */
export const expenseCreateRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  message: TOO_MANY_EXPENSES,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    // `authenticate` middleware should have populated req.user.id by now;
    // fall back to IP for the rare unauthenticated request.
    return req.user?.id ? `user:${req.user.id}` : `ip:${req.ip}`;
  },
});
