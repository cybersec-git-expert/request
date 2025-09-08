import { initializeApp } from 'firebase/app';
import { getFirestore, doc, updateDoc, getDoc } from 'firebase/firestore';
import { getAuth, signInWithEmailAndPassword, signOut } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyCtuD42SzwxKmSY5p-x5olFex2U_S9YrMk",
  authDomain: "request-marketplace.firebaseapp.com",
  projectId: "request-marketplace",
  storageBucket: "request-marketplace.firebasestorage.app",
  messagingSenderId: "355474518888",
  appId: "1:355474518888:web:7b3a7f6f7d7a8b0d8e8f9f"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);

async function fixSuperAdminUID() {
  try {
    console.log('🔧 Fixing Super Admin UID...');
    
    // First, let's sign in as the super admin to get their UID
    console.log('🔐 Signing in as superadmin@request.lk...');
    const userCredential = await signInWithEmailAndPassword(auth, 'superadmin@request.lk', 'SuperAdmin@2024');
    const uid = userCredential.user.uid;
    console.log('✅ Super Admin UID:', uid);
    
    // Update the Firestore document with the correct UID
    const adminDocRef = doc(db, 'admin_users', '6ZlVBdijVfXpOgEp83E5AnHOUaH2');
    
    console.log('📝 Updating Firestore document with UID...');
    await updateDoc(adminDocRef, {
      uid: uid
    });
    
    console.log('✅ Super Admin UID updated successfully!');
    
    // Verify the update
    const updatedDoc = await getDoc(adminDocRef);
    if (updatedDoc.exists()) {
      const data = updatedDoc.data();
      console.log('🔍 Verified - Updated admin data:');
      console.log('   Name:', data.displayName);
      console.log('   Email:', data.email);
      console.log('   Role:', data.role);
      console.log('   UID:', data.uid);
    }
    
    // Sign out
    await signOut(auth);
    console.log('🔓 Signed out successfully');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code === 'auth/wrong-password') {
      console.log('💡 Try updating the password first or use the correct password');
    }
  }
  
  process.exit(0);
}

fixSuperAdminUID();
