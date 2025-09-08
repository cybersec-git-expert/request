const twilio = require('twilio');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const axios = require('axios');
const database = require('./database');
const crypto = require('crypto');

/**
 * 📱 SMS Service - Multi-provider SMS management system
 * Supports Twilio, AWS SNS, Vonage, and Local providers
 */
class SMSService {
  constructor() {
    this.providers = {
      twilio: TwilioProvider,
      aws: AWSSNSProvider,
      vonage: VonageProvider,
      local: LocalProvider,
      hutch_mobile: HutchMobileProvider
    };
  this.supportedProviders = new Set(Object.keys(this.providers));
  }

  /**
   * Backward compatible provider lookup used by some older routes.
   * Prefer getSMSConfig() elsewhere.
   */
  async getActiveProvider(countryCode) {
    try {
      const cfg = await this.getSMSConfig(countryCode || 'LK');
      return { provider: cfg.provider, config: cfg.config || {} };
    } catch (e) {
      console.warn('[SMS] getActiveProvider fallback to dev due to missing config:', e?.message || e);
      return { provider: 'dev', config: {} };
    }
  }

  /**
   * Get SMS configuration for a country (from sms_provider_configs table)
   */
  async getSMSConfig(countryCode) {
    try {
      // Handle phone codes by converting them to country codes
      const actualCountryCode = this.phoneCodeToCountryCode(countryCode);
      
      const result = await database.query(
        'SELECT * FROM sms_provider_configs WHERE country_code = $1 AND is_active = true',
        [actualCountryCode]
      );

      if (result.rows.length === 0) {
        throw new Error(`No active SMS provider configuration found for country: ${countryCode}. Please contact your country admin to set up SMS services.`);
      }

      return result.rows[0];
    } catch (error) {
      console.error('Error getting SMS config:', error);
      throw error;
    }
  }

  /**
   * Send a plain text message using the active provider for diagnostics/admin tests.
   */
  async sendText(countryCode, phoneNumber, message) {
    // Convert phone codes to country codes
    const cc = this.phoneCodeToCountryCode(countryCode || this.detectCountry(phoneNumber));
    const config = await this.getSMSConfig(cc);
    let providerName = config.provider;
    const Provider = this.providers[providerName];
    if (!Provider) throw new Error(`Unsupported provider: ${providerName}`);
    const provider = new Provider(this.formatProviderConfig(config));
    try {
      return await provider.sendSMS(phoneNumber, message);
    } catch (e) {
      const fb = config.config && config.config.fallbackProvider;
      if (fb && this.providers[fb]) {
        const Fallback = this.providers[fb];
        const fallback = new Fallback(this.formatProviderConfig({ provider: fb, config: config.config.fallbackConfig || config.config }));
        return await fallback.sendSMS(phoneNumber, message);
      }
      throw e;
    }
  }

  /**
   * Convert phone codes to country codes (mobile apps might send phone codes)
   */
  phoneCodeToCountryCode(code) {
    const phoneCodeMap = {
      '+94': 'LK',  // Sri Lanka
      '+91': 'IN',  // India
      '+1': 'US',   // USA
      '+44': 'UK',  // UK
      '+971': 'AE', // UAE
    };
    
    // If it's already a country code (2-letter), return as is
    if (code && code.length === 2 && !code.startsWith('+')) {
      return code;
    }
    
    // If it's a phone code, convert it
    if (phoneCodeMap[code]) {
      return phoneCodeMap[code];
    }
    
    // Default to Sri Lanka if no mapping found (most users are from LK)
    return 'LK';
  }

  /**
   * Detect country from phone number
   */
  detectCountry(phoneNumber) {
    const cleanPhone = phoneNumber.replace(/[^\d+]/g, '');
    
    // Extract phone code from number
    if (cleanPhone.startsWith('+94')) return 'LK'; // Sri Lanka
    if (cleanPhone.startsWith('+91')) return 'IN'; // India
    if (cleanPhone.startsWith('+1')) return 'US';   // USA
    if (cleanPhone.startsWith('+44')) return 'UK';  // UK
    if (cleanPhone.startsWith('+971')) return 'AE'; // UAE
    
    return 'LK'; // Default to Sri Lanka
  }

  /**
   * Send OTP via SMS
   */
  async sendOTP(phoneNumber, countryCode = null) {
    try {
      // Auto-detect country if not provided
      if (!countryCode) {
        countryCode = this.detectCountry(phoneNumber);
      }

      // Convert phone codes to country codes (in case mobile app sends phone codes like +94)
      countryCode = this.phoneCodeToCountryCode(countryCode);

      // Check rate limiting
      await this.checkRateLimit(phoneNumber);

      // Get SMS configuration
      const config = await this.getSMSConfig(countryCode);
      
      // Generate OTP
      const otp = this.generateOTP();
      const otpId = this.generateOTPId();
      
      // Get provider instance
      const Provider = this.providers[config.provider];
      if (!Provider) {
        throw new Error(`Unsupported provider: ${config.provider}`);
      }

      const provider = new Provider(this.formatProviderConfig(config));
      
      // Prepare message
      const message = `Your Request Marketplace verification code is: ${otp}. Valid for 5 minutes.`;
      
      // Send SMS
      let usedProvider = config.provider;
      let smsResult;
      try {
        smsResult = await provider.sendSMS(phoneNumber, message);
      } catch (e) {
        const fb = config.config && config.config.fallbackProvider;
        if (fb && this.providers[fb]) {
          const Fallback = this.providers[fb];
          const fallback = new Fallback(this.formatProviderConfig({ provider: fb, config: config.config.fallbackConfig || config.config }));
          smsResult = await fallback.sendSMS(phoneNumber, message);
          usedProvider = fb;
        } else {
          throw e;
        }
      }
      
      // Store OTP in database
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes
      await database.query(`
        INSERT INTO phone_otp_verifications 
        (otp_id, phone, otp, country_code, expires_at, attempts, max_attempts, created_at, provider_used)
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), $8)
      `, [otpId, phoneNumber, otp, countryCode, expiresAt, 0, 3, usedProvider]);

      // Update cost tracking
  await this.updateCostTracking(countryCode, usedProvider, smsResult.cost);

      console.log(`📱 OTP sent to ${phoneNumber} via ${config.provider}`);

      return {
        success: true,
        otpId,
        otpToken: otpId, // Add otpToken for Flutter app compatibility
        expiresIn: 300, // 5 minutes
  provider: usedProvider,
        message: 'OTP sent successfully'
      };

    } catch (error) {
      console.error('SMS sending failed:', error);
      throw error;
    }
  }

  /**
   * Verify OTP code
   */
  async verifyOTP(phoneNumber, otp, otpId = null) {
    try {
      let query = `
        SELECT * FROM phone_otp_verifications 
        WHERE phone = $1 AND otp = $2 AND expires_at > NOW() AND verified = false
      `;
      const params = [phoneNumber, otp];

      if (otpId) {
        query += ' AND otp_id = $3';
        params.push(otpId);
      }

      query += ' ORDER BY created_at DESC LIMIT 1';

      const result = await database.query(query, params);

      if (result.rows.length === 0) {
        // Increment attempts for all non-expired OTPs
        await database.query(`
          UPDATE phone_otp_verifications 
          SET attempts = attempts + 1 
          WHERE phone = $1 AND expires_at > NOW() AND verified = false
        `, [phoneNumber]);
        
        throw new Error('Invalid or expired OTP');
      }

      const otpRecord = result.rows[0];

      // Check attempt limit
      if (otpRecord.attempts >= otpRecord.max_attempts) {
        throw new Error('Maximum OTP attempts exceeded');
      }

      // Mark OTP as verified
      await database.query(`
        UPDATE phone_otp_verifications 
        SET verified = true, verified_at = NOW() 
        WHERE id = $1
      `, [otpRecord.id]);

      console.log(`✅ OTP verified for ${phoneNumber}`);

      return {
        success: true,
        verified: true,
        message: 'OTP verified successfully',
        provider: otpRecord.provider_used || 'unknown'
      };

    } catch (error) {
      console.error('OTP verification failed:', error);
      throw error;
    }
  }

  /**
   * Generate 6-digit OTP
   */
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * Generate unique OTP ID
   */
  generateOTPId() {
    return `otp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Check rate limiting
   */
  async checkRateLimit(phoneNumber) {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    
    const result = await database.query(`
      SELECT COUNT(*) as count 
      FROM phone_otp_verifications 
      WHERE phone = $1 AND created_at > $2
    `, [phoneNumber, oneHourAgo]);

    const count = parseInt(result.rows[0].count);
    
    // Increased limit for development and testing (was 3, now 10)
    if (count >= 10) {
      throw new Error('Too many OTP requests. Please try again later.');
    }
  }

  /**
   * Update cost tracking
   */
  async updateCostTracking(countryCode, provider, cost) {
    try {
      const currentMonth = new Date().getMonth() + 1;
      const currentYear = new Date().getFullYear();

      await database.query(`
        INSERT INTO sms_analytics 
        (country_code, provider, cost, success, month, year, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, NOW())
      `, [countryCode, provider, cost, true, currentMonth, currentYear]);

      // Update monthly totals in sms_configurations
      await database.query(`
        UPDATE sms_configurations 
        SET 
          total_sms_sent = COALESCE(total_sms_sent, 0) + 1,
          total_cost = COALESCE(total_cost, 0) + $2,
          updated_at = NOW()
        WHERE country_code = $1
      `, [countryCode, cost]);

    } catch (error) {
      console.error('Error updating cost tracking:', error);
    }
  }

  /**
   * Format provider configuration for the specific provider
   */
  formatProviderConfig(config) {
    // The config.config field contains the provider-specific configuration
    const providerConfig = config.config;
    
    switch (config.provider) {
    case 'hutch_mobile':
      return {
        hutchMobileConfig: providerConfig
      };
    case 'twilio':
      return {
        twilioConfig: providerConfig
      };
    case 'aws':
      return {
        awsConfig: providerConfig
      };
    case 'vonage':
      return {
        vonageConfig: providerConfig
      };
    case 'local':
      return {
        localConfig: providerConfig
      };
    default:
      throw new Error(`Unknown provider: ${config.provider}`);
    }
  }

  /**
   * Test SMS provider
   */
  async testProvider(countryCode, provider, testNumber) {
    try {
      const config = await this.getSMSConfig(countryCode);
      const Provider = this.providers[provider];
      
      if (!Provider) {
        throw new Error(`Unsupported provider: ${provider}`);
      }

      const providerInstance = new Provider(this.formatProviderConfig(config));
      const testMessage = `Test SMS from Request Marketplace - ${new Date().toISOString()}`;
      
      const result = await providerInstance.sendSMS(testNumber, testMessage);
      
      return {
        success: true,
        provider,
        messageId: result.messageId,
        cost: result.cost,
        timestamp: new Date()
      };

    } catch (error) {
      return {
        success: false,
        provider,
        error: error.message,
        timestamp: new Date()
      };
    }
  }
}

/**
 * 📞 Twilio Provider
 */
class TwilioProvider {
  constructor(config) {
    const twilioConfig = config.twilioConfig;
    if (!twilioConfig) {
      throw new Error('Twilio configuration not found');
    }
    
    this.client = twilio(twilioConfig.accountSid, twilioConfig.authToken);
    this.fromNumber = twilioConfig.fromNumber;
  }

  async sendSMS(to, message) {
    try {
      const result = await this.client.messages.create({
        body: message,
        from: this.fromNumber,
        to: to
      });

      return {
        success: true,
        messageId: result.sid,
        cost: 0.0075, // Estimated cost
        provider: 'twilio'
      };
    } catch (error) {
      throw new Error(`Twilio SMS failed: ${error.message}`);
    }
  }
}

/**
 * ☁️ AWS SNS Provider
 */
class AWSSNSProvider {
  constructor(config) {
    const awsConfig = config.awsConfig;
    if (!awsConfig) {
      throw new Error('AWS SNS configuration not found');
    }

    this.sns = new SNSClient({
      region: awsConfig.region || process.env.AWS_REGION || 'us-east-1',
      // Use default credential provider chain (IAM role, env, shared config)
    });
  }

  async sendSMS(to, message) {
    try {
      const params = {
        Message: message,
        PhoneNumber: to,
        MessageAttributes: {
          'AWS.SNS.SMS.SMSType': {
            DataType: 'String',
            StringValue: 'Transactional'
          }
        }
      };

      const result = await this.sns.send(new PublishCommand(params));

      return {
        success: true,
        messageId: result.MessageId,
        cost: 0.0075, // Estimated cost
        provider: 'aws'
      };
    } catch (error) {
      throw new Error(`AWS SNS failed: ${error.message}`);
    }
  }
}

/**
 * 📞 Vonage Provider
 */
class VonageProvider {
  constructor(config) {
    const vonageConfig = config.vonageConfig;
    if (!vonageConfig) {
      throw new Error('Vonage configuration not found');
    }

    this.apiKey = vonageConfig.apiKey;
    this.apiSecret = vonageConfig.apiSecret;
    this.brandName = vonageConfig.brandName || 'RequestApp';
  }

  async sendSMS(to, message) {
    try {
      const response = await axios.post('https://rest.nexmo.com/sms/json', {
        api_key: this.apiKey,
        api_secret: this.apiSecret,
        to: to.replace('+', ''),
        from: this.brandName,
        text: message
      });

      if (response.data.messages[0].status === '0') {
        return {
          success: true,
          messageId: response.data.messages[0]['message-id'],
          cost: 0.005, // Estimated cost
          provider: 'vonage'
        };
      } else {
        throw new Error(response.data.messages[0]['error-text']);
      }
    } catch (error) {
      throw new Error(`Vonage SMS failed: ${error.message}`);
    }
  }
}

/**
 * 🏠 Local Provider
 */
class LocalProvider {
  constructor(config) {
    const localConfig = config.localConfig;
    if (!localConfig) {
      throw new Error('Local provider configuration not found');
    }

    this.logOnly = localConfig.logOnly || false;
    this.endpoint = localConfig.endpoint;
    this.apiKey = localConfig.apiKey;
    this.method = localConfig.method || 'POST';
  }

  async sendSMS(to, message) {
    try {
      if (this.logOnly) {
        // Log-only mode for testing
        console.log('📱 LOCAL SMS PROVIDER (LOG ONLY)');
        console.log(`📞 To: ${to}`);
        console.log(`💬 Message: ${message}`);
        console.log(`⏰ Time: ${new Date().toISOString()}`);
        console.log('✅ SMS would be sent successfully in production');
        
        return {
          success: true,
          messageId: `local_log_${Date.now()}`,
          cost: 0.003,
          provider: 'local',
          mode: 'log_only'
        };
      }

      // Real HTTP endpoint mode
      if (!this.endpoint) {
        throw new Error('Local provider endpoint not configured');
      }

      const response = await axios({
        method: this.method,
        url: this.endpoint,
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json'
        },
        data: {
          to: to,
          message: message,
          from: 'RequestApp'
        }
      });

      return {
        success: true,
        messageId: response.data.messageId || Date.now().toString(),
        cost: 0.003,
        provider: 'local'
      };
    } catch (error) {
      throw new Error(`Local provider SMS failed: ${error.message}`);
    }
  }
}

/**
 * 🇱🇰 Hutch Mobile Provider (Sri Lanka)
 * Uses Hutch WebbSMS API with authentication flow
 */
class HutchMobileProvider {
  constructor(config) {
    const hutchConfig = config.hutchMobileConfig;
    if (!hutchConfig) {
      throw new Error('Hutch Mobile provider configuration not found');
    }
    // Mode: 'oauth' (bsms.hutch.lk) or 'webb' (webbsms.hutch.lk)
    this.mode = (hutchConfig.mode || 'oauth').toLowerCase();

    // Common config
    this.username = hutchConfig.username;
    this.password = hutchConfig.password;
    this.senderId = hutchConfig.senderId || hutchConfig.mask || 'ALPHABET';

    // OAuth (Bulk SMS) endpoints and state
    this.oauthBase = hutchConfig.oauthBase || 'https://bsms.hutch.lk';
    this._accessToken = null;
    this._refreshToken = null;
    this._accessExp = 0; // epoch seconds

    // WebbSMS (legacy GET) endpoints and options
    this.apiBaseUrl = hutchConfig.apiUrl || 'https://webbsms.hutch.lk/';
    this.messageType = hutchConfig.messageType || 'text';
    this.toFormatPreference = hutchConfig.toFormatPreference || ['94', '0', 'local'];
    this.successIndicators = (hutchConfig.successIndicators || ['success','submitted','ok','message sent','successful']).map(s => s.toLowerCase());
    this.paramNames = {
      username: 'username',
      password: 'password',
      to: 'to',
      message: 'text',     // many gateways expect 'text'
      senderId: 'from',    // many gateways expect 'from'
      messageType: '',     // optional; include only if set in config
      ...(hutchConfig.paramNames || {})
    };
    this.extraParams = hutchConfig.extraParams || {};

    if (!this.username || !this.password) {
      throw new Error('Hutch Mobile username and password are required');
    }
  }

  // ---- OAuth helpers ----
  decodeExp(token) {
    try {
      const parts = token.split('.');
      if (parts.length < 2) return 0;
      const json = Buffer.from(parts[1], 'base64').toString('utf8');
      const payload = JSON.parse(json);
      return payload.exp || 0;
    } catch { return 0; }
  }

  async oauthLogin() {
    const url = `${this.oauthBase}/api/login`;
    const res = await axios.post(url, { username: this.username, password: this.password }, {
      headers: { 'Content-Type': 'application/json', 'Accept': '*/*', 'X-API-VERSION': 'v1' }, timeout: 15000
    });
    this._accessToken = res.data?.accessToken;
    this._refreshToken = res.data?.refreshToken;
    this._accessExp = this._accessToken ? this.decodeExp(this._accessToken) : 0;
    if (!this._accessToken) throw new Error('Hutch OAuth login failed: no accessToken');
  }

  async oauthRefresh() {
    if (!this._refreshToken) return this.oauthLogin();
    const url = `${this.oauthBase}/api/token/accessToken`;
    const res = await axios.get(url, {
      headers: { 'Content-Type': 'application/json', 'Accept': '*/*', 'X-API-VERSION': 'v1', 'Authorization': `Bearer ${this._refreshToken}` }, timeout: 15000
    });
    this._accessToken = res.data?.accessToken;
    this._accessExp = this._accessToken ? this.decodeExp(this._accessToken) : 0;
    if (!this._accessToken) throw new Error('Hutch OAuth refresh failed: no accessToken');
  }

  async ensureAccessToken() {
    const now = Math.floor(Date.now() / 1000);
    if (!this._accessToken || (this._accessExp && now >= this._accessExp - 30)) {
      if (this._refreshToken) await this.oauthRefresh(); else await this.oauthLogin();
    }
  }

  formatTo94(num) {
    const digits = String(num || '').replace(/[^\d]/g, '');
    let local9 = digits;
    if (local9.startsWith('94')) local9 = local9.substring(2);
    if (local9.startsWith('0')) local9 = local9.substring(1);
    if (local9.length > 9) local9 = local9.slice(-9);
    return `94${local9}`;
  }

  async sendSMS(to, message) {
    const original = to;
    try {
      if (this.mode === 'oauth') {
        // OAuth Bulk SMS flow
        await this.ensureAccessToken();
        const toParam = this.formatTo94(to);
        const body = {
          campaignName: 'Request OTP',
          mask: this.senderId,
          numbers: toParam,
          content: message
        };
        const url = `${this.oauthBase}/api/sendsms`;
        let response;
        try {
          response = await axios.post(url, body, {
            headers: { 'Content-Type': 'application/json', 'Accept': '*/*', 'X-API-VERSION': 'v1', 'Authorization': `Bearer ${this._accessToken}` },
            timeout: 15000
          });
        } catch (err) {
          // If unauthorized, try refreshing once then retry
          if (err.response && err.response.status === 401) {
            await this.oauthRefresh();
            response = await axios.post(url, body, {
              headers: { 'Content-Type': 'application/json', 'Accept': '*/*', 'X-API-VERSION': 'v1', 'Authorization': `Bearer ${this._accessToken}` },
              timeout: 15000
            });
          } else {
            throw err;
          }
        }
        const serverRef = response.data?.serverRef;
        if (serverRef) {
          return { success: true, messageId: String(serverRef), cost: 0.50, provider: 'hutch_mobile', response: { serverRef, phone: toParam } };
        }
        throw new Error(`Hutch OAuth send returned no serverRef: ${JSON.stringify(response.data).slice(0,200)}`);
      }

      // WebbSMS fallback (legacy GET)
      // Prepare number variants to try: 94XXXXXXXXX, 0XXXXXXXXX, XXXXXXXXX
      const digits = to.replace(/[^\d]/g, '');
      let local9 = digits;
      if (local9.startsWith('94')) local9 = local9.substring(2);
      if (local9.startsWith('0')) local9 = local9.substring(1);
      if (local9.length > 9) local9 = local9.slice(-9);

      const variants = {
        '94': `94${local9}`,
        '0': `0${local9}`,
        'local': `${local9}`
      };

      const order = Array.isArray(this.toFormatPreference) ? this.toFormatPreference : ['94','0','local'];
      let lastSnippet = '';

      for (const fmt of order) {
        const toParam = variants[fmt];
        console.log(`📱 Hutch try format=${fmt} to=${toParam} (from ${original})`);

        // Query with configurable param names and extra params
        const baseParams = {
          [this.paramNames.username]: this.username,
          [this.paramNames.password]: this.password,
          [this.paramNames.to]: toParam,
          [this.paramNames.message]: message,
          [this.paramNames.senderId]: this.senderId,
          ...this.extraParams
        };
        if (this.paramNames.messageType) {
          baseParams[this.paramNames.messageType] = this.messageType;
        }
        const params = new URLSearchParams(baseParams);

        const fullUrl = `${this.apiBaseUrl}?${params.toString()}`;
  console.log(`📱 Hutch URL: ${this.apiBaseUrl}?${this.paramNames.username}=${this.username}&${this.paramNames.to}=${toParam}&${this.paramNames.message}=[HIDDEN]&${this.paramNames.senderId}=${this.senderId}`);

  const response = await axios.get(fullUrl, {
          timeout: 15000,
          headers: { 'User-Agent': 'Request-Marketplace-SMS/1.0' }
        });

        const body = typeof response.data === 'string' ? response.data : JSON.stringify(response.data);
        const bodyLower = body.toLowerCase();
        const snippet = body.substring(0, 200);
        console.log('📱 Hutch status:', response.status, 'snippet:', snippet.replace(/\s+/g, ' ').trim());

  // Treat as success only on clear positive indicators
  const indicatorHit = this.successIndicators.some(ind => bodyLower.includes(ind));
  const codePattern = /(status|result|code)\s*[-:=]?\s*(0|200|ok|success)/i;
  const isSuccess = response.status === 200 && (indicatorHit || codePattern.test(body));
        if (isSuccess) {
          return {
            success: true,
            messageId: `hutch_${Date.now()}_${toParam}`,
            cost: 0.50,
            provider: 'hutch_mobile',
            response: { status: 'sent', phone: toParam, snippet, timestamp: new Date().toISOString() }
          };
        }
        lastSnippet = snippet;
        console.warn(`⚠️ Hutch attempt with format=${fmt} did not confirm success.`);
      }

  throw new Error(`Hutch did not confirm success. Last response: ${lastSnippet}`);
    } catch (error) {
      console.error('❌ Hutch Mobile SMS Error:', error.response?.data || error.message);
      throw new Error(`Hutch Mobile SMS failed: ${error.response?.status || error.message}`);
    }
  }
}

module.exports = new SMSService();
