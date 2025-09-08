// Firebase Auth abstraction for admin-react
// Currently this app still references Firebase admin auth flows.
// Provide minimal implementations using firebase/app + firebase/auth.

import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, signOut, onAuthStateChanged } from 'firebase/auth';
import { getFirestore, doc, getDoc } from 'firebase/firestore';

const firebaseConfig = {
  // TODO: replace with real config or load from env
  projectId: 'request-marketplace'
};

let _app; let _auth; let _db;
function ensureInit() {
  if (!_app) {
    _app = initializeApp(firebaseConfig, 'admin-react');
    _auth = getAuth(_app);
    _db = getFirestore(_app);
  }
}

export async function signInAdmin(email, password) {
  ensureInit();
  const cred = await signInWithEmailAndPassword(_auth, email, password);
  const adminDoc = await getDoc(doc(_db, 'admin_users', cred.user.uid));
  if (!adminDoc.exists()) {
    await signOut(_auth);
    throw new Error('Not an admin user');
  }
  return { user: cred.user, adminData: adminDoc.data() };
}

export async function signOutAdmin() {
  ensureInit();
  await signOut(_auth);
}

export function onAdminAuthStateChanged(callback) {
  ensureInit();
  return onAuthStateChanged(_auth, async (user) => {
    if (!user) return callback({ user: null, adminData: null });
    try {
      const adminDoc = await getDoc(doc(_db, 'admin_users', user.uid));
      callback({ user, adminData: adminDoc.exists() ? adminDoc.data() : null });
    } catch (e) {
      console.error('Admin auth state fetch error', e);
      callback({ user, adminData: null });
    }
  });
}
