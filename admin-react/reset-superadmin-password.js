import { initializeApp } from 'firebase/app';
import { getAuth, sendPasswordResetEmail } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyCtuD42SzwxKmSY5p-x5olFex2U_S9YrMk",
  authDomain: "request-marketplace.firebaseapp.com",
  projectId: "request-marketplace",
  storageBucket: "request-marketplace.firebasestorage.app",
  messagingSenderId: "355474518888",
  appId: "1:355474518888:web:7b3a7f6f7d7a8b0d8e8f9f"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

async function resetSuperAdminPassword() {
  try {
    console.log('🔐 Sending password reset email to superadmin@request.lk...');
    
    await sendPasswordResetEmail(auth, 'superadmin@request.lk');
    
    console.log('✅ Password reset email sent to superadmin@request.lk');
    console.log('📧 Check the email inbox for reset instructions');
    console.log('💡 After resetting, you can log in as the super admin');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code === 'auth/user-not-found') {
      console.log('🔍 The superadmin@request.lk user was not found in Firebase Auth');
      console.log('💡 This means the super admin account needs to be created in Firebase Auth');
    }
  }
  
  process.exit(0);
}

resetSuperAdminPassword();
