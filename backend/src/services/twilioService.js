import twilio from 'twilio';

/**
 * Thin wrapper around Twilio Verify. Lazily instantiates the client so a
 * missing TWILIO_ACCOUNT_SID doesn't crash the server at import time — it
 * just makes sendVerification/checkVerification reject.
 */

let _client;
function getClient() {
  if (_client) return _client;
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  if (!sid || !token) {
    throw new Error('Twilio not configured: missing TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN');
  }
  _client = twilio(sid, token);
  return _client;
}

function getVerifyService() {
  const id = process.env.TWILIO_VERIFY_SERVICE_SID;
  if (!id) {
    throw new Error('Twilio Verify Service not configured: missing TWILIO_VERIFY_SERVICE_SID');
  }
  return getClient().verify.v2.services(id);
}

export const TwilioService = {
  /**
   * Trigger an SMS verification for the given E.164 phone number.
   * Returns { status: 'pending' | 'approved' | ..., sid }.
   */
  async sendVerification(phoneNumber) {
    const result = await getVerifyService().verifications.create({
      to: phoneNumber,
      channel: 'sms',
    });
    return { status: result.status, sid: result.sid };
  },

  /**
   * Check a code submitted by the user. Returns true iff Twilio reports
   * the verification as approved.
   */
  async checkVerification(phoneNumber, code) {
    const result = await getVerifyService().verificationChecks.create({
      to: phoneNumber,
      code,
    });
    return { approved: result.status === 'approved', status: result.status };
  },

  /** Sugar for callers who want to know if Twilio is set up at all. */
  isConfigured() {
    return Boolean(
      process.env.TWILIO_ACCOUNT_SID &&
        process.env.TWILIO_AUTH_TOKEN &&
        process.env.TWILIO_VERIFY_SERVICE_SID,
    );
  },
};

export default TwilioService;
