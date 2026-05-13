import { query  } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

class User {
  /**
   * Find user by ID (cached — 5min TTL)
   */
  static async findById(id) {
    return cache.getOrSet(`user:${id}:profile`, TTL.USER_PROFILE, async () => {
      const result = await query(
        'SELECT id, phone_number, name, email, profile_image_base64, preferred_currency, created_at, updated_at FROM users WHERE id = $1 AND deleted_at IS NULL',
        [id]
      );
      return result.rows[0] || null;
    });
  }

  /**
   * Batch find users by IDs (single query instead of N separate findById calls)
   * @param {string[]} ids - Array of user IDs
   * @returns {Object} - Map of userId → user object
   */
  static async findByIds(ids) {
    if (!ids || ids.length === 0) return {};
    const unique = [...new Set(ids)];
    const placeholders = unique.map((_, i) => `$${i + 1}`).join(', ');
    const result = await query(
      `SELECT id, phone_number, name, email, profile_image_base64, preferred_currency, created_at, updated_at
       FROM users WHERE id IN (${placeholders}) AND deleted_at IS NULL`,
      unique
    );
    const map = {};
    for (const row of result.rows) map[row.id] = row;
    return map;
  }

  /**
   * Find user by phone number
   * Uses normalized matching to handle different phone formats (+91, 91, spaces, etc.)
   */
  static async findByPhoneNumber(phoneNumber) {
    // Normalize the input phone number to last 10 digits
    const normalizedPhone = this.normalizePhoneForSearch(phoneNumber);

    const result = await query(
      `SELECT id, phone_number, name, email, profile_image_base64, preferred_currency, is_placeholder, created_at, updated_at
       FROM users
       WHERE RIGHT(REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g'), 10) = $1
       AND deleted_at IS NULL`,
      [normalizedPhone]
    );
    return result.rows[0] || null;
  }

  /**
   * Normalize phone number to consistent format for matching
   * Extracts last 10 digits (Indian phone numbers without country code)
   */
  static normalizePhoneForSearch(phoneNumber) {
    // Remove all non-digit characters
    const digitsOnly = phoneNumber.replace(/\D/g, '');

    // Get last 10 digits (handles +91, 91, 0 prefixes)
    if (digitsOnly.length >= 10) {
      return digitsOnly.slice(-10);
    }
    return digitsOnly;
  }

  /**
   * Find users by multiple phone numbers (bulk query for performance)
   * Uses WHERE IN clause to fetch all users in a single query
   * Normalizes phone numbers to match regardless of format (+91, 91, spaces, etc.)
   */
  static async findByPhoneNumbers(phoneNumbers) {
    if (!phoneNumbers || phoneNumbers.length === 0) {
      return [];
    }

    // Normalize input phone numbers to last 10 digits
    const normalizedPhones = phoneNumbers.map(p => this.normalizePhoneForSearch(p));

    // Create placeholders for parameterized query: $1, $2, $3, etc.
    const placeholders = normalizedPhones.map((_, i) => `$${i + 1}`).join(', ');

    // Use RIGHT() function to compare last 10 digits of stored phone numbers
    // This handles cases where DB has +91XXXXXXXXXX and query has just XXXXXXXXXX or vice versa
    // Exclude placeholder users - they are not actually registered
    const result = await query(
      `SELECT id, phone_number, name, email, profile_image_base64, preferred_currency, created_at, updated_at
       FROM users
       WHERE RIGHT(REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g'), 10) IN (${placeholders})
       AND (is_placeholder = FALSE OR is_placeholder IS NULL)
       AND deleted_at IS NULL`,
      normalizedPhones
    );

    return result.rows;
  }

  /**
   * Create new user
   */
  static async create(userData) {
    const { phoneNumber, name, email, profileImageBase64, preferredCurrency } = userData;
    const result = await query(
      `INSERT INTO users (phone_number, name, email, profile_image_base64, preferred_currency)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, phone_number, name, email, profile_image_base64, preferred_currency, created_at`,
      [phoneNumber, name, email || null, profileImageBase64 || null, preferredCurrency || 'INR']
    );
    return result.rows[0];
  }

  /**
   * Invalidate all cached data for a user
   */
  static invalidateUser(id) {
    cache.del(`user:${id}:profile`);
    cache.del(`auth:user:${id}`);
  }

  /**
   * Update user
   */
  static async update(id, userData) {
    const { name, email, profileImageBase64, preferredCurrency } = userData;
    const result = await query(
      `UPDATE users
       SET name = COALESCE($1, name),
           email = COALESCE($2, email),
           profile_image_base64 = COALESCE($3, profile_image_base64),
           preferred_currency = COALESCE($4, preferred_currency),
           updated_at = NOW()
       WHERE id = $5 AND deleted_at IS NULL
       RETURNING id, phone_number, name, email, profile_image_base64, preferred_currency, updated_at`,
      [name, email, profileImageBase64, preferredCurrency, id]
    );
    if (result.rows[0]) this.invalidateUser(id);
    return result.rows[0] || null;
  }

  /**
   * Soft delete user
   */
  static async delete(id) {
    const result = await query(
      'UPDATE users SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL RETURNING id',
      [id]
    );
    if (result.rows.length > 0) this.invalidateUser(id);
    return result.rows.length > 0;
  }

  /**
   * Check if user exists
   */
  static async exists(phoneNumber) {
    const result = await query(
      'SELECT id FROM users WHERE phone_number = $1 AND deleted_at IS NULL',
      [phoneNumber]
    );
    return result.rows.length > 0;
  }

  /**
   * Alias for findByPhoneNumber
   */
  static async findByPhone(phoneNumber) {
    return this.findByPhoneNumber(phoneNumber);
  }

  // =====================================================
  // PLACEHOLDER USER METHODS
  // =====================================================

  /**
   * Create a placeholder user for non-registered invites
   * This allows adding them to groups and expenses before they register
   * @param {Object} userData - User data
   * @returns {Object} - Created placeholder user
   */
  static async createPlaceholder(userData) {
    const { phoneNumber, name, email } = userData;

    // Check if user already exists (registered or placeholder)
    const existing = await this.findByPhoneNumber(phoneNumber);
    if (existing) {
      return existing;
    }

    const result = await query(
      `INSERT INTO users (phone_number, name, email, is_placeholder)
       VALUES ($1, $2, $3, TRUE)
       RETURNING id, phone_number, name, email, is_placeholder, created_at`,
      [phoneNumber, name, email || null]
    );
    return result.rows[0];
  }

  /**
   * Find placeholder user by phone number
   * @param {string} phoneNumber - Phone number
   * @returns {Object|null} - Placeholder user or null
   */
  static async findPlaceholderByPhone(phoneNumber) {
    const normalizedPhone = this.normalizePhoneForSearch(phoneNumber);

    const result = await query(
      `SELECT id, phone_number, name, email, is_placeholder, created_at, updated_at
       FROM users
       WHERE RIGHT(REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g'), 10) = $1
       AND is_placeholder = TRUE
       AND deleted_at IS NULL`,
      [normalizedPhone]
    );
    return result.rows[0] || null;
  }

  /**
   * Convert placeholder user to real user (when they register)
   * @param {string} phoneNumber - Phone number to find placeholder
   * @param {Object} userData - New user data
   * @returns {Object|null} - Updated user or null if no placeholder found
   */
  static async convertPlaceholderToReal(phoneNumber, userData) {
    const normalizedPhone = this.normalizePhoneForSearch(phoneNumber);
    const { name, email } = userData;

    const result = await query(
      `UPDATE users
       SET name = COALESCE($2, name),
           email = COALESCE($3, email),
           is_placeholder = FALSE,
           updated_at = NOW()
       WHERE RIGHT(REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g'), 10) = $1
       AND is_placeholder = TRUE
       AND deleted_at IS NULL
       RETURNING id, phone_number, name, email, is_placeholder, created_at, updated_at`,
      [normalizedPhone, name, email]
    );
    return result.rows[0] || null;
  }

  /**
   * Check if a phone number has a placeholder user
   * @param {string} phoneNumber - Phone number
   * @returns {boolean}
   */
  static async hasPlaceholder(phoneNumber) {
    const placeholder = await this.findPlaceholderByPhone(phoneNumber);
    return !!placeholder;
  }
}

export default User;
