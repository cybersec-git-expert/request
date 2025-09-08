/**
 * Password generation utility for admin users
 */

// Generate a secure random password
export const generateSecurePassword = (length = 12) => {
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const numbers = '0123456789';
  const symbols = '!@#$%^&*';
  
  const allChars = lowercase + uppercase + numbers + symbols;
  let password = '';
  
  // Ensure at least one character from each category
  password += lowercase[Math.floor(Math.random() * lowercase.length)];
  password += uppercase[Math.floor(Math.random() * uppercase.length)];
  password += numbers[Math.floor(Math.random() * numbers.length)];
  password += symbols[Math.floor(Math.random() * symbols.length)];
  
  // Fill the rest randomly
  for (let i = 4; i < length; i++) {
    password += allChars[Math.floor(Math.random() * allChars.length)];
  }
  
  // Shuffle the password
  return password.split('').sort(() => 0.5 - Math.random()).join('');
};

// Generate admin credentials
export const generateAdminCredentials = (adminData) => {
  const password = generateSecurePassword();
  
  return {
    ...adminData,
    password,
    tempPassword: password // For display purposes
  };
};

// Email template for admin credentials
export const generateCredentialsEmail = (adminData, password) => {
  return {
    subject: `Admin Account Created - Request Marketplace`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #2563eb, #1e40af); color: white; padding: 30px; text-align: center;">
          <h1>🎯 Welcome to Request Marketplace Admin Panel</h1>
        </div>
        
        <div style="padding: 30px; background: #f8fafc;">
          <h2>Hello ${adminData.displayName || adminData.name}!</h2>
          
          <p>Your admin account has been created successfully. Here are your login credentials:</p>
          
          <div style="background: white; border: 1px solid #e5e7eb; border-radius: 8px; padding: 20px; margin: 20px 0;">
            <h3 style="color: #1f2937; margin-top: 0;">🔐 Login Credentials</h3>
            <p><strong>Email:</strong> ${adminData.email}</p>
            <p><strong>Password:</strong> <code style="background: #f3f4f6; padding: 4px 8px; border-radius: 4px; font-family: monospace;">${password}</code></p>
            <p><strong>Role:</strong> ${adminData.role === 'super_admin' ? 'Super Admin' : 'Country Admin'}</p>
            ${adminData.country ? `<p><strong>Country:</strong> ${adminData.country}</p>` : ''}
          </div>
          
          <div style="background: #fef3c7; border: 1px solid #f59e0b; border-radius: 8px; padding: 15px; margin: 20px 0;">
            <h4 style="color: #92400e; margin-top: 0;">🔒 Security Notice</h4>
            <ul style="margin: 0; color: #92400e;">
              <li>Please change your password after first login</li>
              <li>Do not share these credentials with anyone</li>
              <li>Use a secure connection (HTTPS) when accessing the admin panel</li>
            </ul>
          </div>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${process.env.NODE_ENV === 'production' ? 'https://admin.requestmarketplace.com' : 'http://localhost:5173'}" 
               style="background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
              🚀 Access Admin Panel
            </a>
          </div>
          
          <hr style="margin: 30px 0; border: none; border-top: 1px solid #e5e7eb;">
          
          <p style="color: #6b7280; font-size: 14px;">
            If you did not expect this email or have any questions, please contact the system administrator immediately.
          </p>
        </div>
        
        <div style="background: #1f2937; color: #d1d5db; padding: 20px; text-align: center; font-size: 12px;">
          <p>© 2025 Request Marketplace. All rights reserved.</p>
        </div>
      </div>
    `
  };
};

export default {
  generateSecurePassword,
  generateAdminCredentials,
  generateCredentialsEmail
};
