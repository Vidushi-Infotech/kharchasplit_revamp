/**
 * WATI Service - WhatsApp Business API Integration
 * Sends automated WhatsApp messages via WATI API
 */

class WatiService {
  // Use getters to read env vars at runtime (not at class definition time)
  static get WATI_API_URL() {
    return process.env.WATI_API_URL || '';
  }

  static get WATI_API_TOKEN() {
    return process.env.WATI_API_TOKEN || '';
  }

  static get WATI_TEMPLATE_NAME() {
    return process.env.WATI_TEMPLATE_NAME || 'kharchasplit_expense_notification';
  }

  /**
   * Normalize phone number to international format without + prefix
   * WATI expects: 919876543210 (without +)
   * @param {string} phoneNumber - Phone number in any format
   * @returns {string} - Normalized phone number
   */
  static normalizePhoneNumber(phoneNumber) {
    // Remove all non-digit characters
    let cleaned = phoneNumber.replace(/\D/g, '');

    // If starts with +, it's already been removed by replace
    // If it's a 10-digit Indian number, add 91
    if (cleaned.length === 10) {
      cleaned = '91' + cleaned;
    }
    // If it starts with 0, remove it and add 91
    else if (cleaned.startsWith('0') && cleaned.length === 11) {
      cleaned = '91' + cleaned.substring(1);
    }
    // If it already has country code (12 digits starting with 91), keep it
    // Otherwise, assume it's correct

    return cleaned;
  }

  /**
   * Send WhatsApp template message via WATI
   * @param {string} phoneNumber - Recipient phone number
   * @param {string} recipientName - Name of the recipient
   * @param {string} inviterName - Name of the person inviting
   * @param {string} groupName - Optional group name for context
   * @returns {Promise<{success: boolean, messageId?: string, error?: string}>}
   */
  static async sendInviteMessage(phoneNumber, recipientName, inviterName, groupName = null) {
    try {
      if (!this.WATI_API_URL || !this.WATI_API_TOKEN) {
        console.error('[WatiService] WATI credentials not configured');
        return {
          success: false,
          error: 'WATI not configured',
        };
      }

      const normalizedPhone = this.normalizePhoneNumber(phoneNumber);
      console.log(`[WatiService] Sending invite to ${normalizedPhone} (original: ${phoneNumber})`);

      // Prepare template parameters
      // Template uses: {{1}} = recipient name, {{2}} = inviter name
      const parameters = [
        { name: '1', value: recipientName || 'Friend' },
        { name: '2', value: inviterName || 'A friend' },
      ];

      const requestBody = {
        template_name: this.WATI_TEMPLATE_NAME,
        broadcast_name: `kharchasplit_invite_${Date.now()}`,
        parameters: parameters,
      };

      const url = `${this.WATI_API_URL}/api/v1/sendTemplateMessage?whatsappNumber=${normalizedPhone}`;
      const bodyJson = JSON.stringify(requestBody);

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.WATI_API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: bodyJson,
      });

      const responseText = await response.text();
      // Only log verbose details in development (JSON.stringify with pretty-print blocks event loop)
      if (process.env.NODE_ENV !== 'production') {
        console.log(`[WatiService] ${response.status} ${normalizedPhone}:`, responseText.substring(0, 200));
      }

      let responseData;
      try {
        responseData = JSON.parse(responseText);
      } catch (e) {
        responseData = { raw: responseText };
      }

      if (response.ok && responseData.result !== false) {
        console.log(`[WatiService] Message sent successfully to ${normalizedPhone}`);
        return {
          success: true,
          messageId: responseData.messageId || responseData.id || 'sent',
          response: responseData,
        };
      } else {
        console.error('[WatiService] Failed to send message:', responseData);
        return {
          success: false,
          error: responseData.message || responseData.info || 'Failed to send WhatsApp message',
          response: responseData,
        };
      }
    } catch (error) {
      console.error('[WatiService] Error sending WhatsApp message:', error);
      return {
        success: false,
        error: error.message || 'Network error',
      };
    }
  }

  /**
   * Send bulk invite messages
   * @param {Array<{phoneNumber: string, name: string}>} recipients - Array of recipients
   * @param {string} inviterName - Name of the person inviting
   * @returns {Promise<{success: number, failed: number, results: Array}>}
   */
  static async sendBulkInvites(recipients, inviterName) {
    const results = [];
    let success = 0;
    let failed = 0;

    for (const recipient of recipients) {
      // Add delay between messages to avoid rate limiting
      if (results.length > 0) {
        await new Promise(resolve => setTimeout(resolve, 1000)); // 1 second delay
      }

      const result = await this.sendInviteMessage(
        recipient.phoneNumber,
        recipient.name,
        inviterName
      );

      results.push({
        phoneNumber: recipient.phoneNumber,
        name: recipient.name,
        ...result,
      });

      if (result.success) {
        success++;
      } else {
        failed++;
      }
    }

    return { success, failed, results };
  }

  /**
   * Check if WATI is configured and ready
   * @returns {boolean}
   */
  static isConfigured() {
    return !!(this.WATI_API_URL && this.WATI_API_TOKEN);
  }

  /**
   * Test WATI connection by getting account info
   * @returns {Promise<{success: boolean, error?: string}>}
   */
  static async testConnection() {
    try {
      if (!this.isConfigured()) {
        return { success: false, error: 'WATI not configured' };
      }

      const url = `${this.WATI_API_URL}/api/v1/getContacts`;

      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.WATI_API_TOKEN}`,
        },
      });

      if (response.ok) {
        return { success: true };
      } else {
        const data = await response.json().catch(() => ({}));
        return { success: false, error: data.message || 'Connection failed' };
      }
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
}

export default WatiService;
