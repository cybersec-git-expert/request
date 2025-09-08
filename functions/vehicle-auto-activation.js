const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Auto-activate new vehicle types for all existing countries
 * Triggers when a new vehicle type is created
 */
exports.autoActivateVehicleTypes = functions.firestore
  .document('vehicle_types/{vehicleId}')
  .onCreate(async (snap, context) => {
    try {
      const vehicleId = context.params.vehicleId;
      const vehicleData = snap.data();
      
      console.log(`🚗 New vehicle type created: ${vehicleData.name} (${vehicleId})`);
      
      // Only auto-activate if the vehicle is marked as active
      if (!vehicleData.isActive) {
        console.log('⏸️ Vehicle is not active, skipping auto-activation');
        return;
      }
      
      // Get all existing country vehicle configurations
      const countryVehiclesSnapshot = await db.collection('country_vehicles').get();
      
      if (countryVehiclesSnapshot.empty) {
        console.log('ℹ️ No country vehicle configurations found');
        return;
      }
      
      console.log(`🌍 Found ${countryVehiclesSnapshot.docs.length} countries to update`);
      
      // Update each country to include the new vehicle type
      const batch = db.batch();
      let updateCount = 0;
      
      countryVehiclesSnapshot.docs.forEach(doc => {
        const countryData = doc.data();
        const currentVehicles = countryData.enabledVehicles || [];
        
        // Only add if not already present
        if (!currentVehicles.includes(vehicleId)) {
          const updatedVehicles = [...currentVehicles, vehicleId];
          
          batch.update(doc.ref, {
            enabledVehicles: updatedVehicles,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: 'auto-activation-system',
            autoActivationLog: admin.firestore.FieldValue.arrayUnion({
              vehicleId: vehicleId,
              vehicleName: vehicleData.name,
              addedAt: admin.firestore.FieldValue.serverTimestamp(),
              reason: 'new-vehicle-auto-activation'
            })
          });
          
          updateCount++;
          console.log(`✅ Queued ${countryData.countryCode} for vehicle activation`);
        } else {
          console.log(`ℹ️ ${countryData.countryCode} already has vehicle ${vehicleId}`);
        }
      });
      
      if (updateCount > 0) {
        await batch.commit();
        console.log(`🎉 Successfully activated vehicle "${vehicleData.name}" for ${updateCount} countries`);
      } else {
        console.log('ℹ️ No countries needed updates');
      }
      
    } catch (error) {
      console.error('❌ Error in autoActivateVehicleTypes:', error);
      throw error;
    }
  });

/**
 * Auto-setup country vehicles when a new country configuration is created
 * Triggers when a new country document is created in country_modules or similar
 */
exports.autoSetupCountryVehicles = functions.firestore
  .document('country_modules/{countryCode}')
  .onCreate(async (snap, context) => {
    try {
      const countryCode = context.params.countryCode;
      const countryData = snap.data();
      
      console.log(`🌍 New country configuration created: ${countryCode}`);
      
      // Check if country_vehicles document already exists
      const existingVehiclesDoc = await db.collection('country_vehicles')
        .where('countryCode', '==', countryCode)
        .limit(1)
        .get();
      
      if (!existingVehiclesDoc.empty) {
        console.log(`ℹ️ Country vehicles already configured for ${countryCode}`);
        return;
      }
      
      // Get all active vehicle types
      const activeVehiclesSnapshot = await db.collection('vehicle_types')
        .where('isActive', '==', true)
        .get();
      
      if (activeVehiclesSnapshot.empty) {
        console.log('⚠️ No active vehicle types found');
        return;
      }
      
      const activeVehicleIds = activeVehiclesSnapshot.docs.map(doc => doc.id);
      console.log(`🚗 Found ${activeVehicleIds.length} active vehicle types to enable`);
      
      // Create country vehicles document with all active vehicles enabled
      await db.collection('country_vehicles').add({
        countryCode: countryCode,
        countryName: countryData.countryName || countryCode,
        enabledVehicles: activeVehicleIds,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'auto-setup-system',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: 'auto-setup-system',
        autoSetupLog: {
          setupAt: admin.firestore.FieldValue.serverTimestamp(),
          vehiclesEnabled: activeVehicleIds.length,
          reason: 'new-country-auto-setup'
        }
      });
      
      console.log(`🎉 Auto-setup completed for ${countryCode} with ${activeVehicleIds.length} vehicles`);
      
    } catch (error) {
      console.error('❌ Error in autoSetupCountryVehicles:', error);
      throw error;
    }
  });

/**
 * Log vehicle activation/deactivation changes for audit trail
 */
exports.logVehicleChanges = functions.firestore
  .document('country_vehicles/{docId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      
      const beforeVehicles = before.enabledVehicles || [];
      const afterVehicles = after.enabledVehicles || [];
      
      // Find changes
      const added = afterVehicles.filter(id => !beforeVehicles.includes(id));
      const removed = beforeVehicles.filter(id => !afterVehicles.includes(id));
      
      if (added.length === 0 && removed.length === 0) {
        return; // No vehicle changes
      }
      
      console.log(`🔄 Vehicle changes for ${after.countryCode}:`);
      if (added.length > 0) console.log(`  ➕ Added: ${added.join(', ')}`);
      if (removed.length > 0) console.log(`  ➖ Removed: ${removed.join(', ')}`);
      
      // Log to audit collection
      await db.collection('vehicle_audit_log').add({
        countryCode: after.countryCode,
        action: 'vehicle_update',
        vehiclesAdded: added,
        vehiclesRemoved: removed,
        beforeCount: beforeVehicles.length,
        afterCount: afterVehicles.length,
        updatedBy: after.updatedBy || 'unknown',
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
    } catch (error) {
      console.error('❌ Error in logVehicleChanges:', error);
    }
  });
