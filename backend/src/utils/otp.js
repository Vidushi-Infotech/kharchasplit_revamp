import crypto from 'crypto';

/**
 * Generate a numeric OTP of the given length.
 */
const generateOTP = (length = 6) => {
  // crypto.randomInt, not Math.random: codes must not be guessable.
  let otp = '';
  for (let i = 0; i < length; i++) {
    otp += String(crypto.randomInt(0, 10));
  }
  return otp;
};

/**
 * Build the OTP expiry timestamp (default 10 minutes from now).
 */
const getOTPExpiry = (minutes = 10) => {
  const expiry = new Date();
  expiry.setMinutes(expiry.getMinutes() + minutes);
  return expiry;
};

export {
  generateOTP,
  getOTPExpiry,
};
