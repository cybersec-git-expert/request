// Currency service for proper formatting based on country
export class CurrencyService {
  static countryToCurrency = {
    'LK': { code: 'LKR', symbol: 'Rs', name: 'Sri Lankan Rupee' },
    'IN': { code: 'INR', symbol: '₹', name: 'Indian Rupee' },
    'US': { code: 'USD', symbol: '$', name: 'US Dollar' },
    'UK': { code: 'GBP', symbol: '£', name: 'British Pound' },
    'AU': { code: 'AUD', symbol: 'A$', name: 'Australian Dollar' },
    'CA': { code: 'CAD', symbol: 'C$', name: 'Canadian Dollar' },
    'EU': { code: 'EUR', symbol: '€', name: 'Euro' },
    'SG': { code: 'SGD', symbol: 'S$', name: 'Singapore Dollar' },
    'MY': { code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit' },
    'TH': { code: 'THB', symbol: '฿', name: 'Thai Baht' },
    'PH': { code: 'PHP', symbol: '₱', name: 'Philippine Peso' },
    'ID': { code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah' },
    'BD': { code: 'BDT', symbol: '৳', name: 'Bangladeshi Taka' },
    'PK': { code: 'PKR', symbol: 'Rs', name: 'Pakistani Rupee' },
    'NP': { code: 'NPR', symbol: 'Rs', name: 'Nepalese Rupee' },
    'AE': { code: 'AED', symbol: 'د.إ', name: 'UAE Dirham' },
    'SA': { code: 'SAR', symbol: 'ر.س', name: 'Saudi Riyal' },
    'QA': { code: 'QAR', symbol: 'ر.ق', name: 'Qatari Riyal' },
    'KW': { code: 'KWD', symbol: 'د.ك', name: 'Kuwaiti Dinar' },
    'OM': { code: 'OMR', symbol: 'ر.ع.', name: 'Omani Rial' },
    'BH': { code: 'BHD', symbol: '.د.ب', name: 'Bahraini Dinar' }
  };

  static getCountryCurrency(countryCode) {
    return this.countryToCurrency[countryCode] || { code: 'USD', symbol: '$', name: 'US Dollar' };
  }

  static formatCurrency(amount, currency, countryCode = null) {
    if (!amount && amount !== 0) return 'N/A';

    // If countryCode is provided, use country's default currency
    let currencyInfo = null;
    if (countryCode) {
      currencyInfo = this.getCountryCurrency(countryCode);
    } else if (currency) {
      // Try to find currency info by currency code
      currencyInfo = Object.values(this.countryToCurrency).find(c => c.code === currency);
    }

    if (!currencyInfo) {
      currencyInfo = { code: currency || 'USD', symbol: currency || '$', name: currency || 'USD' };
    }

    const numAmount = parseFloat(amount);
    if (isNaN(numAmount)) return 'Invalid Amount';

    // Format the number with appropriate decimal places
    const formattedAmount = this.formatNumber(numAmount);
    
    return `${currencyInfo.symbol} ${formattedAmount}`;
  }

  static formatNumber(amount) {
    if (amount >= 10000000) {
      // 10M+: show in millions with 1 decimal place
      return (amount / 1000000).toFixed(1) + 'M';
    } else if (amount >= 1000000) {
      // 1M+: show in millions with 2 decimal places
      return (amount / 1000000).toFixed(2) + 'M';
    } else if (amount >= 100000) {
      // 100K+: show in thousands with no decimals
      return (amount / 1000).toFixed(0) + 'K';
    } else if (amount >= 10000) {
      // 10K+: show in thousands with 1 decimal place
      return (amount / 1000).toFixed(1) + 'K';
    } else {
      // Less than 10K: show full number with thousands separators
      return amount.toLocaleString();
    }
  }

  static convertCurrency(amount, fromCurrency, toCurrency, exchangeRates = null) {
    // Basic currency conversion - in a real app, you'd use live exchange rates
    if (!exchangeRates) {
      // Default exchange rates (you should replace this with a real service)
      exchangeRates = {
        'USD': 1.0,
        'LKR': 320.0,
        'INR': 83.0,
        'GBP': 0.79,
        'EUR': 0.92,
        'AUD': 1.52,
        'CAD': 1.37,
        'SGD': 1.35,
        'MYR': 4.72,
        'THB': 36.0,
        'PHP': 56.0,
        'IDR': 15800,
        'BDT': 110.0,
        'PKR': 280.0,
        'NPR': 133.0,
        'AED': 3.67,
        'SAR': 3.75,
        'QAR': 3.64,
        'KWD': 0.31,
        'OMR': 0.38,
        'BHD': 0.38
      };
    }

    const fromRate = exchangeRates[fromCurrency] || 1;
    const toRate = exchangeRates[toCurrency] || 1;
    
    // Convert to USD first, then to target currency
    const usdAmount = amount / fromRate;
    return usdAmount * toRate;
  }

  static getBudgetRanges(countryCode) {
    const currency = this.getCountryCurrency(countryCode);
    
    // Define budget ranges based on currency
    switch (currency.code) {
      case 'LKR':
        return [
          { label: 'Under Rs 5,000', min: 0, max: 5000 },
          { label: 'Rs 5,000 - 10,000', min: 5000, max: 10000 },
          { label: 'Rs 10,000 - 25,000', min: 10000, max: 25000 },
          { label: 'Rs 25,000 - 50,000', min: 25000, max: 50000 },
          { label: 'Rs 50,000 - 100,000', min: 50000, max: 100000 },
          { label: 'Over Rs 100,000', min: 100000, max: null }
        ];
      case 'USD':
        return [
          { label: 'Under $100', min: 0, max: 100 },
          { label: '$100 - 250', min: 100, max: 250 },
          { label: '$250 - 500', min: 250, max: 500 },
          { label: '$500 - 1,000', min: 500, max: 1000 },
          { label: '$1,000 - 2,500', min: 1000, max: 2500 },
          { label: 'Over $2,500', min: 2500, max: null }
        ];
      case 'INR':
        return [
          { label: 'Under ₹5,000', min: 0, max: 5000 },
          { label: '₹5,000 - 15,000', min: 5000, max: 15000 },
          { label: '₹15,000 - 30,000', min: 15000, max: 30000 },
          { label: '₹30,000 - 50,000', min: 30000, max: 50000 },
          { label: '₹50,000 - 1,00,000', min: 50000, max: 100000 },
          { label: 'Over ₹1,00,000', min: 100000, max: null }
        ];
      default:
        return [
          { label: 'Under $100', min: 0, max: 100 },
          { label: '$100 - 250', min: 100, max: 250 },
          { label: '$250 - 500', min: 250, max: 500 },
          { label: '$500 - 1,000', min: 500, max: 1000 },
          { label: '$1,000 - 2,500', min: 1000, max: 2500 },
          { label: 'Over $2,500', min: 2500, max: null }
        ];
    }
  }
}

export default CurrencyService;
