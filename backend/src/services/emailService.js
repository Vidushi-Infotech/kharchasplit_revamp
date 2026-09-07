/**
 * EmailService — SMTP wrapper used by the email-invite fallback when
 * WATI / WhatsApp delivery isn't viable. Configured via the standard
 * SMTP_* env vars; safely no-ops with a clear error string when unset.
 *
 * This is *additive* to the WATI + Twilio flows — those services are still
 * the primary delivery path. EmailService only kicks in when the caller
 * explicitly hits the email-invite endpoint.
 */

import nodemailer from 'nodemailer';
import { logger } from '../utils/logger.js';

let _transporter = null;

/** Lazily build (and reuse) the nodemailer transporter. Returns null when SMTP isn't configured. */
function getTransporter() {
  if (_transporter) return _transporter;
  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASSWORD;
  if (!host || !user || !pass) return null;
  _transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465, // 465 = TLS direct; everything else uses STARTTLS
    auth: { user, pass },
  });
  return _transporter;
}

class EmailService {
  static isConfigured() {
    return !!(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASSWORD);
  }

  /**
   * Sends the "you were added to <group> by <inviter>" invite email.
   *
   * @param {Object} opts
   * @param {string} opts.toEmail        Recipient address.
   * @param {string} opts.recipientName  Used in the greeting (falls back to "there").
   * @param {string} opts.inviterName    Whose name is shown as the inviter.
   * @param {string} opts.groupName      Group display name.
   * @returns {Promise<{success: boolean, messageId?: string, error?: string}>}
   */
  static async sendInviteEmail({ toEmail, recipientName, inviterName, groupName }) {
    if (!toEmail || !toEmail.includes('@')) {
      return { success: false, error: 'A valid recipient email is required' };
    }
    const transporter = getTransporter();
    if (!transporter) {
      return {
        success: false,
        error: 'SMTP not configured — set SMTP_HOST / SMTP_USER / SMTP_PASSWORD in .env',
      };
    }

    const playStoreUrl =
      process.env.APP_PLAY_STORE_URL ||
      'https://play.google.com/store/apps/details?id=com.kharchasplit';
    const appStoreUrl =
      process.env.APP_APP_STORE_URL ||
      'https://apps.apple.com/app/kharchasplit/id000000000';
    // Universal landing page that sniffs the user-agent and redirects to
    // the right store (or deep-links into the app if installed). Falls back
    // to the Play Store link in dev.
    const universalUrl =
      process.env.APP_INSTALL_URL || playStoreUrl;

    const fromAddr = process.env.SMTP_FROM || 'noreply@kharchasplit.com';
    const safeRecipient = (recipientName || 'there').trim();
    const safeInviter = (inviterName || 'A friend').trim();
    const safeGroup = (groupName || 'a KharchaSplit group').trim();

    const subject = `${safeInviter} added you to "${safeGroup}" on KharchaSplit`;

    const text = [
      `Hi ${safeRecipient},`,
      ``,
      `${safeInviter} added you to the "${safeGroup}" group on KharchaSplit.`,
      `Install the app to view and split expenses with the group.`,
      ``,
      `Install: ${universalUrl}`,
      `Android (Play Store): ${playStoreUrl}`,
      `iPhone (App Store): ${appStoreUrl}`,
      ``,
      `— The KharchaSplit Team`,
    ].join('\n');

    const html = `
<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f5f7fa;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1a1f2e;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e6e9ef;">
            <tr>
              <td style="padding:28px 32px;background:#0d9d6f;color:#ffffff;">
                <div style="font-size:14px;letter-spacing:1.5px;opacity:0.85;">KHARCHASPLIT</div>
                <div style="font-size:22px;font-weight:700;margin-top:6px;">You've been invited to a group</div>
              </td>
            </tr>
            <tr>
              <td style="padding:28px 32px;">
                <p style="margin:0 0 12px;font-size:16px;">Hi ${escapeHtml(safeRecipient)},</p>
                <p style="margin:0 0 16px;font-size:16px;line-height:1.55;">
                  <strong>${escapeHtml(safeInviter)}</strong> added you to the
                  <strong>"${escapeHtml(safeGroup)}"</strong> group on KharchaSplit.
                </p>
                <p style="margin:0 0 24px;font-size:15px;line-height:1.55;color:#5a6478;">
                  Install the app to view shared expenses, see who owes what, and settle up — all in one place.
                </p>

                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                  <tr>
                    <td align="center" style="padding:0 6px;">
                      <a href="${universalUrl}" style="display:inline-block;padding:14px 28px;background:#0d9d6f;color:#ffffff;text-decoration:none;border-radius:8px;font-weight:600;font-size:15px;">
                        Install KharchaSplit
                      </a>
                    </td>
                  </tr>
                </table>

                <p style="margin:24px 0 12px;font-size:13px;color:#5a6478;text-align:center;">Or download directly:</p>
                <!--
                  Official badge URLs:
                    Google Play  — play.google.com/intl/en_us/badges (hosted by Google).
                    App Store    — tools.applemediaservices.com/api/badges (hosted by Apple).
                  Both render as PNGs in every email client and don't get blocked
                  the way generic image hosts can.
                -->
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                  <tr>
                    <td align="center" style="padding:4px 8px;vertical-align:middle;">
                      <a href="${playStoreUrl}" style="text-decoration:none;border:0;outline:none;">
                        <img
                          src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png"
                          alt="Get it on Google Play"
                          height="56"
                          style="height:56px;width:auto;display:block;border:0;outline:none;text-decoration:none;"
                        />
                      </a>
                    </td>
                    <td align="center" style="padding:4px 8px;vertical-align:middle;">
                      <a href="${appStoreUrl}" style="text-decoration:none;border:0;outline:none;">
                        <img
                          src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83"
                          alt="Download on the App Store"
                          height="40"
                          style="height:40px;width:auto;display:block;border:0;outline:none;text-decoration:none;"
                        />
                      </a>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 32px;background:#f5f7fa;color:#7a8499;font-size:12px;line-height:1.5;text-align:center;">
                You're receiving this because <strong>${escapeHtml(safeInviter)}</strong> entered your email
                while inviting you to a group. If this wasn't you, you can safely ignore this email.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`.trim();

    try {
      const info = await transporter.sendMail({
        from: fromAddr,
        to: toEmail,
        subject,
        text,
        html,
      });
      logger.info({ messageId: info.messageId, to: toEmail }, '[EmailService] invite sent');
      return { success: true, messageId: info.messageId };
    } catch (e) {
      logger.warn({ err: e, to: toEmail }, '[EmailService] sendMail failed');
      return { success: false, error: e.message || 'SMTP send failed' };
    }
  }

  /**
   * Sends a password-reset OTP email. The OTP is rendered prominently and
   * expires in `expiresInMinutes` (defaults to 10).
   *
   * @param {Object} opts
   * @param {string} opts.toEmail            Recipient address.
   * @param {string} opts.recipientName      Used in the greeting (falls back to "there").
   * @param {string} opts.otp                Numeric OTP (typically 6 digits).
   * @param {number} [opts.expiresInMinutes] OTP TTL in minutes for the copy line.
   * @returns {Promise<{success: boolean, messageId?: string, error?: string}>}
   */
  static async sendPasswordResetEmail({ toEmail, recipientName, otp, expiresInMinutes = 10 }) {
    if (!toEmail || !toEmail.includes('@')) {
      return { success: false, error: 'A valid recipient email is required' };
    }
    if (!otp) {
      return { success: false, error: 'OTP is required' };
    }
    const transporter = getTransporter();
    if (!transporter) {
      return {
        success: false,
        error: 'SMTP not configured — set SMTP_HOST / SMTP_USER / SMTP_PASSWORD in .env',
      };
    }

    const fromAddr = process.env.SMTP_FROM || 'noreply@kharchasplit.com';
    const safeRecipient = (recipientName || 'there').trim();
    const safeOtp = String(otp).trim();

    const subject = `Your KharchaSplit password reset code: ${safeOtp}`;

    const text = [
      `Hi ${safeRecipient},`,
      ``,
      `Your KharchaSplit password reset code is: ${safeOtp}`,
      ``,
      `This code expires in ${expiresInMinutes} minutes. Enter it in the app to set a new password.`,
      ``,
      `If you didn't request a password reset, you can safely ignore this email — your account stays unchanged.`,
      ``,
      `— The KharchaSplit Team`,
    ].join('\n');

    const html = `
<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f5f7fa;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1a1f2e;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e6e9ef;">
            <tr>
              <td style="padding:28px 32px;background:#0d9d6f;color:#ffffff;">
                <div style="font-size:14px;letter-spacing:1.5px;opacity:0.85;">KHARCHASPLIT</div>
                <div style="font-size:22px;font-weight:700;margin-top:6px;">Password reset code</div>
              </td>
            </tr>
            <tr>
              <td style="padding:28px 32px;">
                <p style="margin:0 0 12px;font-size:16px;">Hi ${escapeHtml(safeRecipient)},</p>
                <p style="margin:0 0 20px;font-size:15px;line-height:1.55;color:#5a6478;">
                  Use the code below to reset your KharchaSplit password. It expires in
                  <strong>${expiresInMinutes} minutes</strong>.
                </p>

                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 24px;">
                  <tr>
                    <td align="center" style="padding:18px 32px;background:#f1f8f5;border:1px solid #cfe8db;border-radius:10px;">
                      <div style="font-size:32px;font-weight:700;letter-spacing:8px;color:#0d9d6f;font-family:'SF Mono','Menlo','Consolas',monospace;">
                        ${escapeHtml(safeOtp)}
                      </div>
                    </td>
                  </tr>
                </table>

                <p style="margin:0 0 8px;font-size:14px;line-height:1.55;color:#5a6478;">
                  Enter this code in the app on the password reset screen, then choose a new password.
                </p>
                <p style="margin:0;font-size:13px;line-height:1.55;color:#7a8499;">
                  Didn't request a reset? You can safely ignore this email — your account stays unchanged.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 32px;background:#f5f7fa;color:#7a8499;font-size:12px;line-height:1.5;text-align:center;">
                For your security, never share this code with anyone — not even someone claiming to be from KharchaSplit.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`.trim();

    try {
      const info = await transporter.sendMail({
        from: fromAddr,
        to: toEmail,
        subject,
        text,
        html,
      });
      logger.info({ messageId: info.messageId, to: toEmail }, '[EmailService] password reset OTP sent');
      return { success: true, messageId: info.messageId };
    } catch (e) {
      logger.warn({ err: e, to: toEmail }, '[EmailService] password reset send failed');
      return { success: false, error: e.message || 'SMTP send failed' };
    }
  }
}

/** Minimal HTML escape — sufficient for names + group titles (no markup expected). */
/**
 * Email-address verification code. Same shape as the password-reset mail so
 * the app's OTP screen can reuse the same copy conventions.
 */
EmailService.sendEmailVerificationEmail = async function ({ toEmail, recipientName, otp, expiresInMinutes = 10 }) {
  if (!toEmail || !toEmail.includes('@')) {
    return { success: false, error: 'A valid recipient email is required' };
  }
  if (!otp) return { success: false, error: 'OTP is required' };
  const transporter = getTransporter();
  if (!transporter) {
    return {
      success: false,
      error: 'SMTP not configured — set SMTP_HOST / SMTP_USER / SMTP_PASSWORD in .env',
    };
  }

  const fromAddr = process.env.SMTP_FROM || 'noreply@kharchasplit.com';
  const safeRecipient = (recipientName || 'there').trim();
  const safeOtp = String(otp).trim();
  const subject = `Your KharchaSplit email verification code: ${safeOtp}`;

  const text = [
    `Hi ${safeRecipient},`,
    ``,
    `Your KharchaSplit email verification code is: ${safeOtp}`,
    ``,
    `This code expires in ${expiresInMinutes} minutes. Enter it in the app under Profile to confirm this address.`,
    ``,
    `If you didn't request this, you can safely ignore this email.`,
    ``,
    `— The KharchaSplit Team`,
  ].join('\n');

  const html = `
<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f5f7fa;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1a1f2e;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="padding:32px 16px;">
      <tr><td align="center">
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e6e9ef;">
          <tr><td style="padding:28px 32px;background:#0d9d6f;color:#ffffff;">
            <div style="font-size:14px;letter-spacing:1.5px;opacity:0.85;">KHARCHASPLIT</div>
            <div style="font-size:22px;font-weight:700;margin-top:6px;">Verify your email</div>
          </td></tr>
          <tr><td style="padding:28px 32px;">
            <p style="margin:0 0 12px;font-size:16px;">Hi ${escapeHtml(safeRecipient)},</p>
            <p style="margin:0 0 20px;font-size:15px;line-height:1.55;color:#5a6478;">
              Enter the code below in the app to confirm this email address. It expires in
              <strong>${expiresInMinutes} minutes</strong>.
            </p>
            <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 24px;">
              <tr><td align="center" style="padding:18px 32px;background:#f1f8f5;border:1px solid #cfe8db;border-radius:10px;">
                <div style="font-size:32px;font-weight:700;letter-spacing:8px;color:#0d9d6f;font-family:'SF Mono','Menlo','Consolas',monospace;">${escapeHtml(safeOtp)}</div>
              </td></tr>
            </table>
            <p style="margin:0;font-size:13px;line-height:1.55;color:#7a8499;">
              Didn't request this? You can safely ignore this email.
            </p>
          </td></tr>
          <tr><td style="padding:18px 32px;background:#f5f7fa;color:#7a8499;font-size:12px;line-height:1.5;text-align:center;">
            Never share this code with anyone — not even someone claiming to be from KharchaSplit.
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`.trim();

  try {
    const info = await transporter.sendMail({ from: fromAddr, to: toEmail, subject, text, html });
    logger.info({ messageId: info.messageId, to: toEmail }, '[EmailService] email verification OTP sent');
    return { success: true, messageId: info.messageId };
  } catch (e) {
    logger.warn({ err: e, to: toEmail }, '[EmailService] email verification send failed');
    return { success: false, error: e.message || 'SMTP send failed' };
  }
};

/**
 * Nudge for active users who never verified their address. No code inside:
 * the OTP flow is started from the app (Profile → Verify) so the code is
 * always fresh when it's needed.
 */
EmailService.sendEmailVerifyReminderEmail = async function ({ toEmail, recipientName, activityCount = 0, windowDays = 7 }) {
  if (!toEmail || !toEmail.includes('@')) {
    return { success: false, error: 'A valid recipient email is required' };
  }
  const transporter = getTransporter();
  if (!transporter) {
    return { success: false, error: 'SMTP not configured — set SMTP_HOST / SMTP_USER / SMTP_PASSWORD in .env' };
  }
  const fromAddr = process.env.SMTP_FROM || 'noreply@kharchasplit.com';
  const safeRecipient = (recipientName || 'there').trim();
  const subject = 'Verify your email on KharchaSplit';
  const usage = activityCount > 0
    ? `You've been busy on KharchaSplit this week (${activityCount} update${activityCount === 1 ? '' : 's'} in the last ${windowDays} days) — nice.`
    : `You've been using KharchaSplit recently — nice.`;

  const text = [
    `Hi ${safeRecipient},`,
    ``,
    usage,
    ``,
    `One small thing is still pending: this email address isn't verified yet. Verifying takes a minute and makes sure you can always recover your account and receive settlement reminders.`,
    ``,
    `How: open the app → Profile → tap "Not verified · Verify" → enter the 6-digit code we send you.`,
    ``,
    `If you don't want to verify, you can ignore this — we'll only remind you a couple more times.`,
    ``,
    `— The KharchaSplit Team`,
  ].join('\n');

  const html = `
<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f5f7fa;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1a1f2e;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="padding:32px 16px;">
      <tr><td align="center">
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e6e9ef;">
          <tr><td style="padding:28px 32px;background:#0d9d6f;color:#ffffff;">
            <div style="font-size:14px;letter-spacing:1.5px;opacity:0.85;">KHARCHASPLIT</div>
            <div style="font-size:22px;font-weight:700;margin-top:6px;">One small thing left</div>
          </td></tr>
          <tr><td style="padding:28px 32px;">
            <p style="margin:0 0 12px;font-size:16px;">Hi ${escapeHtml(safeRecipient)},</p>
            <p style="margin:0 0 16px;font-size:15px;line-height:1.55;color:#5a6478;">${escapeHtml(usage)}</p>
            <p style="margin:0 0 20px;font-size:15px;line-height:1.55;color:#5a6478;">
              Your email address <strong>${escapeHtml(toEmail)}</strong> isn't verified yet. It takes a minute and
              makes sure you can always recover your account and receive settlement reminders.
            </p>
            <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 20px;">
              <tr><td style="padding:14px 18px;background:#f1f8f5;border:1px solid #cfe8db;border-radius:10px;font-size:14px;line-height:1.6;color:#1a1f2e;">
                Open the app → <strong>Profile</strong> → tap <strong>Not verified · Verify</strong> → enter the 6-digit code.
              </td></tr>
            </table>
            <p style="margin:0;font-size:13px;line-height:1.55;color:#7a8499;">
              Don't want to verify? Ignore this email — we'll only remind you a couple more times.
            </p>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`.trim();

  try {
    const info = await transporter.sendMail({ from: fromAddr, to: toEmail, subject, text, html });
    logger.info({ messageId: info.messageId, to: toEmail }, '[EmailService] email verify reminder sent');
    return { success: true, messageId: info.messageId };
  } catch (e) {
    logger.warn({ err: e, to: toEmail }, '[EmailService] email verify reminder send failed');
    return { success: false, error: e.message || 'SMTP send failed' };
  }
};

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export default EmailService;
