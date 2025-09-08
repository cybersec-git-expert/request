import { createUserWithEmailAndPassword } from 'firebase/auth';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '../src/firebase/config.js';
import { signOut } from 'firebase/auth';

async function createSuperAdmin() {
  try {
    console.log('🚀 Setting up Super Admin for Request Marketplace...');
    
    // Prompt for admin credentials instead of hardcoding
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    const email = await new Promise(resolve => {
      rl.question('Enter super admin email: ', resolve);
    });
    
    const password = await new Promise(resolve => {
      rl.question('Enter super admin password (min 6 characters): ', resolve);
    });
    
    const name = await new Promise(resolve => {
      rl.question('Enter super admin display name: ', resolve);
    });
    
    rl.close();
    
    if (!email || !password || password.length < 6) {
      throw new Error('Email and password (min 6 chars) are required');
    }

    console.log('📧 Creating Firebase Auth user...');
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;

    console.log('📝 Creating admin document in Firestore...');
    await setDoc(doc(db, 'admin_users', user.uid), {
      name: name,
      email: email,
      role: 'super_admin',
      country: null, // Super admin has global access
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });

    // Sign out the created user
    await signOut(auth);

    console.log('✅ Super Admin created successfully!');
    console.log('');
    console.log('📋 Login Credentials:');
    console.log('   Email:', email);
    console.log('   Password: [HIDDEN FOR SECURITY]');
    console.log('');
    console.log('🔐 IMPORTANT: Keep these credentials secure!');
    console.log('');
    console.log('🌐 Access the admin panel at: http://localhost:5173');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating super admin:', error);
    
    if (error.code === 'auth/email-already-in-use') {
      console.log('');
      console.log('🔍 A super admin user with this email already exists.');
      console.log('📧 Try logging in with the existing credentials.');
      console.log('🔑 If you forgot the password, use the password reset feature in the admin panel.');
    }
    
    process.exit(1);
  }
}

// Create example country admin
async function createCountryAdmin() {
  try {
    console.log('');
    console.log('🌍 Creating Country Admin...');
    
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    const email = await new Promise(resolve => {
      rl.question('Enter country admin email: ', resolve);
    });
    
    const password = await new Promise(resolve => {
      rl.question('Enter country admin password: ', resolve);
    });
    
    const name = await new Promise(resolve => {
      rl.question('Enter country admin display name: ', resolve);
    });
    
    const country = await new Promise(resolve => {
      rl.question('Enter country name: ', resolve);
    });
    
    rl.close();
    
    if (!email || !password || !name || !country) {
      console.log('⚠️ Skipping country admin creation - missing required fields');
      return;
    }

    console.log(`🇺🇸 Creating Country Admin for ${country}...`);
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;

    await setDoc(doc(db, 'admin_users', user.uid), {
      displayName: name,
      email: email,
      role: 'country_admin',
      country: country,
      isActive: true,
      permissions: {
        paymentMethods: true,
        legalDocuments: true,
        businessManagement: true,
        driverManagement: true
      },
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });

    await signOut(auth);

    console.log('✅ Country Admin created successfully!');
    console.log('📧 Email:', email);
    console.log('🔑 Password: [HIDDEN FOR SECURITY]');
    console.log('🌍 Country:', country);

  } catch (error) {
    if (error.code !== 'auth/email-already-in-use') {
      console.error('❌ Error creating country admin:', error);
    }
  }
}

async function setupAdmins() {
  console.log('🎯 Request Marketplace Admin Setup');
  console.log('=====================================');
  console.log('This will create admin users for your system.');
  console.log('');
  
  try {
    await createSuperAdmin();
    
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    const createCountryAdmin = await new Promise(resolve => {
      rl.question('Do you want to create a country admin? (y/n): ', (answer) => {
        resolve(answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes');
      });
    });
    
    rl.close();
    
    if (createCountryAdmin) {
      await createCountryAdmin();
    }
    
    console.log('');
    console.log('🎉 Admin setup complete!');
    console.log('🚀 Start your admin panel: npm run dev');
    
  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  }
}

setupAdmins();
