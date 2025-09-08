import { sendPasswordResetEmail } from 'firebase/auth';
import { auth } from '../src/firebase/config.js';

async function resetAdminPassword() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('❌ Usage: node scripts/reset-admin-password.js <email>');
    console.log('📧 Example: node scripts/reset-admin-password.js admin@example.com');
    process.exit(1);
  }
  
  const email = args[0];
  
  try {
    console.log(`🔄 Sending password reset email to: ${email}`);
    await sendPasswordResetEmail(auth, email);
    
    console.log('✅ Password reset email sent successfully!');
    console.log('📧 Check the email inbox for reset instructions');
    console.log('🔗 The user can click the link to set a new password');
    
  } catch (error) {
    console.error('❌ Error sending password reset email:', error.message);
    
    if (error.code === 'auth/user-not-found') {
      console.log('🚫 No user found with this email address');
    } else if (error.code === 'auth/invalid-email') {
      console.log('📧 Invalid email address format');
    }
    
    process.exit(1);
  }
  
  process.exit(0);
}

resetAdminPassword();
