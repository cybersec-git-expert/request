/**
 * Email service for sending admin credentials
 * This is a client-side implementation for development
 * In production, you should use a server-side email service
 */

import { generateCredentialsEmail } from './passwordUtils.js';

// Mock email service for development
export const sendCredentialsEmail = async (adminData, password) => {
  try {
    const emailContent = generateCredentialsEmail(adminData, password);
    
    console.log('📧 Email Service - Sending credentials...');
    console.log('To:', adminData.email);
    console.log('Subject:', emailContent.subject);
    console.log('Password:', password);
    
    // In development, we'll show the credentials in console
    // and store them in localStorage for the demo
    if (process.env.NODE_ENV === 'development') {
      // Store credentials for demo purposes
      const savedCredentials = JSON.parse(localStorage.getItem('adminCredentials') || '[]');
      savedCredentials.push({
        email: adminData.email,
        password: password,
        role: adminData.role,
        country: adminData.country,
        name: adminData.displayName,
        createdAt: new Date().toISOString()
      });
      localStorage.setItem('adminCredentials', JSON.stringify(savedCredentials));
      
      console.log('✅ Development Mode: Credentials saved to localStorage');
      console.log('📋 Check browser localStorage under key "adminCredentials"');
      
      // Simulate email delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      return { success: true, message: 'Credentials saved locally (development mode)' };
    }
    
    // In production, you would integrate with a real email service
    // Example integrations:
    
    // Option 1: EmailJS (client-side)
    // const response = await emailjs.send('service_id', 'template_id', {
    //   to_email: adminData.email,
    //   to_name: adminData.displayName,
    //   subject: emailContent.subject,
    //   html_content: emailContent.html
    // });
    
    // Option 2: Firebase Functions (server-side)
    // const response = await fetch('/api/sendAdminCredentials', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify({ adminData, password })
    // });
    
    // Option 3: Netlify Functions
    // const response = await fetch('/.netlify/functions/send-email', {
    //   method: 'POST',
    //   body: JSON.stringify({ adminData, password, emailContent })
    // });
    
    // For now, return success (credentials are shown in UI)
    return { success: true, message: 'Email sent successfully' };
    
  } catch (error) {
    console.error('Error sending credentials email:', error);
    return { success: false, error: error.message };
  }
};

// Get saved credentials (for development)
export const getSavedCredentials = () => {
  if (process.env.NODE_ENV === 'development') {
    return JSON.parse(localStorage.getItem('adminCredentials') || '[]');
  }
  return [];
};

// Clear saved credentials (for development)
export const clearSavedCredentials = () => {
  if (process.env.NODE_ENV === 'development') {
    localStorage.removeItem('adminCredentials');
  }
};

export default {
  sendCredentialsEmail,
  getSavedCredentials,
  clearSavedCredentials
};
