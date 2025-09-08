// Demo script showing how page management works for different user types
import { collection, addDoc, getDocs, query, where, serverTimestamp } from 'firebase/firestore';
import { db } from './src/firebase/config.js';

async function demonstratePageManagementFlow() {
  console.log('🎭 DEMONSTRATION: Page Management Permission Flow');
  console.log('================================================');
  
  try {
    // Get current admin users to understand the roles
    const adminQuery = collection(db, 'admin_users');
    const adminSnapshot = await getDocs(adminQuery);
    
    console.log('\n👥 Current Admin Users:');
    const admins = {};
    adminSnapshot.docs.forEach(doc => {
      const data = doc.data();
      admins[data.role] = {
        email: data.email,
        country: data.country,
        permissions: data.permissions
      };
      console.log(`   ${data.role}: ${data.email} (${data.country || 'Global'})`);
    });
    
    // Simulate creating pages as different user types
    console.log('\n🎯 SCENARIO 1: Super Admin Creates Global Page');
    console.log('===============================================');
    const superAdminPage = {
      title: 'Global Privacy Policy',
      slug: 'global-privacy-policy',
      type: 'centralized',
      category: 'legal',
      content: 'This privacy policy applies to all countries...',
      countries: ['global'],
      status: 'approved', // Super admin auto-approves
      requiresApproval: false,
      createdBy: 'superadmin_uid',
      createdAt: serverTimestamp(),
      isTemplate: false
    };
    
    console.log('✅ Super Admin Action:');
    console.log('   - Creates: Global Privacy Policy');
    console.log('   - Type: Centralized (affects ALL countries)'); 
    console.log('   - Status: Auto-approved (super admin privilege)');
    console.log('   - Can publish immediately: YES');
    console.log('   - Visible to: All countries when published');
    
    console.log('\n🎯 SCENARIO 2: Country Admin (LK) Creates Country Page');
    console.log('=====================================================');
    const countryPage = {
      title: 'Sri Lanka Payment Methods',
      slug: 'lk-payment-methods',
      type: 'country-specific',
      category: 'business',
      content: 'Payment methods available in Sri Lanka...',
      countries: ['LK'],
      status: 'draft', // Country admin starts with draft
      requiresApproval: true,
      createdBy: 'lk_admin_uid',
      createdAt: serverTimestamp(),
      isTemplate: false
    };
    
    console.log('✅ LK Country Admin Action:');
    console.log('   - Creates: Sri Lanka Payment Methods');
    console.log('   - Type: Country-specific (LK only)');
    console.log('   - Status: Draft → Pending (needs approval)');
    console.log('   - Can publish directly: NO');
    console.log('   - Visible to: Only LK users (when approved)');
    
    console.log('\n🎯 SCENARIO 3: Country Admin (LK) Creates Global Page');
    console.log('====================================================');
    const countryGlobalPage = {
      title: 'Universal Safety Guidelines',
      slug: 'universal-safety-guidelines', 
      type: 'centralized',
      category: 'info',
      content: 'Safety guidelines that should apply globally...',
      countries: ['global'],
      status: 'pending', // Country admin submits for approval
      requiresApproval: true,
      createdBy: 'lk_admin_uid',
      createdAt: serverTimestamp(),
      isTemplate: false
    };
    
    console.log('⚠️  LK Country Admin Action (Global Impact):');
    console.log('   - Creates: Universal Safety Guidelines');
    console.log('   - Type: Centralized (affects ALL countries)');
    console.log('   - Status: Draft → Pending (REQUIRES super admin approval)');
    console.log('   - Warning shown: "This affects all countries"');
    console.log('   - Can publish directly: NO');
    console.log('   - Next step: Super admin must review and approve');
    
    // Show the approval workflow
    console.log('\n🔄 APPROVAL WORKFLOW:');
    console.log('====================');
    console.log('1. Country Admin creates page → Status: Draft');
    console.log('2. Country Admin submits → Status: Pending');  
    console.log('3. Super Admin reviews → Can Approve/Reject');
    console.log('4. If approved → Status: Approved');
    console.log('5. Super Admin publishes → Status: Published (Live)');
    
    // Show what each user type can see
    console.log('\n👁️  VISIBILITY MATRIX:');
    console.log('======================');
    console.log('Super Admin can see:');
    console.log('  ✅ All pages from all countries');
    console.log('  ✅ All centralized/global pages'); 
    console.log('  ✅ All pending approvals');
    console.log('  ✅ Can edit/approve/publish any page');
    
    console.log('\nLK Country Admin can see:');
    console.log('  ✅ Pages created for Sri Lanka (LK)');
    console.log('  ✅ Centralized/global pages');
    console.log('  ✅ Templates they can customize');
    console.log('  ❌ Pages from other countries (US, UK, etc.)');
    console.log('  ❌ Cannot approve their own pages');
    
    console.log('\n🔐 PERMISSION CHECKS:');
    console.log('=====================');
    console.log('Before showing Page Management menu:');
    console.log('  ✓ Check: permissions.contentManagement === true');
    console.log('  ✓ Both super admin and country admin have this permission');
    
    console.log('\nBefore creating centralized page:');
    console.log('  ✓ Country admin gets warning about global impact');
    console.log('  ✓ Auto-sets requiresApproval = true for country admins');
    console.log('  ✓ Auto-sets requiresApproval = false for super admins');
    
    console.log('\nBefore approving pages:');
    console.log('  ✓ Check: isSuperAdmin === true');
    console.log('  ✓ Only super admins can approve/publish pages');
    
    console.log('\n📊 CURRENT DATABASE STATE:');
    console.log('==========================');
    const pagesQuery = collection(db, 'content_pages');
    const pagesSnapshot = await getDocs(pagesQuery);
    
    console.log(`Total pages in database: ${pagesSnapshot.size}`);
    
    const pagesByType = {};
    const pagesByStatus = {};
    
    pagesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      pagesByType[data.type] = (pagesByType[data.type] || 0) + 1;
      pagesByStatus[data.status] = (pagesByStatus[data.status] || 0) + 1;
    });
    
    console.log('\nPages by type:');
    Object.entries(pagesByType).forEach(([type, count]) => {
      console.log(`  ${type}: ${count} pages`);
    });
    
    console.log('\nPages by status:');
    Object.entries(pagesByStatus).forEach(([status, count]) => {
      console.log(`  ${status}: ${count} pages`);
    });
    
    console.log('\n✅ This demonstrates how country-specific permissions work!');
    console.log('   Country admins can contribute but super admin has final control.');
    
  } catch (error) {
    console.error('❌ Demo error:', error);
  }
}

// Run the demonstration
demonstratePageManagementFlow();
