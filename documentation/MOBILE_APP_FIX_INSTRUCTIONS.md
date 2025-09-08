# 🔧 Mobile App Fix Instructions

## The Problem
Your mobile app is showing all 6 modules (Item, Service, Delivery, Rental, Ride, Price) instead of only the 3 enabled modules for Sri Lanka.

## The Solution
Your mobile app needs to fetch the module configuration from Firestore instead of showing hardcoded modules.

## Current Sri Lanka Configuration
Based on your admin panel settings:
- ✅ **Item Request** - ENABLED
- ✅ **Service Request** - ENABLED  
- ✅ **Rental Request** - ENABLED
- ❌ **Delivery Request** - DISABLED
- ❌ **Ride Request** - DISABLED
- ❌ **Price Request** - DISABLED

## Changes Needed in Your Mobile App

### 1. Add Firestore Module Fetching
```javascript
// Add this function to your mobile app
const getCountryModules = async (countryCode) => {
  const docRef = doc(db, 'country_modules', countryCode.toUpperCase());
  const docSnapshot = await getDoc(docRef);
  
  if (!docSnapshot.exists()) {
    // Return defaults if no config found
    return {
      item: true,
      service: true,
      rent: false,
      delivery: false,
      ride: false,
      price: false
    };
  }
  
  return docSnapshot.data().modules;
};
```

### 2. Update Your Create Request Screen
Instead of:
```javascript
// ❌ WRONG - Shows all modules hardcoded
const allModules = [
  { id: 'item', name: 'Item Request', ... },
  { id: 'service', name: 'Service Request', ... },
  { id: 'delivery', name: 'Delivery Request', ... },
  { id: 'rent', name: 'Rental Request', ... },
  { id: 'ride', name: 'Ride Request', ... },
  { id: 'price', name: 'Price Request', ... }
];
```

Do this:
```javascript
// ✅ CORRECT - Only shows enabled modules
const [enabledModules, setEnabledModules] = useState({});

useEffect(() => {
  const loadModules = async () => {
    const modules = await getCountryModules('LK');
    setEnabledModules(modules);
  };
  loadModules();
}, []);

// Only render enabled modules
{enabledModules.item && <ItemRequestOption />}
{enabledModules.service && <ServiceRequestOption />}
{enabledModules.rent && <RentalRequestOption />}
{enabledModules.delivery && <DeliveryRequestOption />}
{enabledModules.ride && <RideRequestOption />}
{enabledModules.price && <PriceRequestOption />}
```

### 3. Test the Configuration
1. Open: http://localhost:3000/test-modules.html
2. This will show you exactly what your mobile app should display
3. Only enabled modules should be visible

### 4. Implementation Priority
1. **High Priority**: Update the Create Request screen to use dynamic modules
2. **Medium Priority**: Update navigation tabs to hide disabled modules
3. **Low Priority**: Add module feature toggles throughout the app

## Expected Result
After implementing this fix:
- Sri Lanka users will see only 3 request types (Item, Service, Rental)
- Other countries can have different module configurations
- No app update needed when admin changes module settings

## Testing
1. Admin enables "Delivery" module for Sri Lanka
2. Mobile app should automatically show "Delivery Request" option
3. Admin disables "Rental" module for Sri Lanka  
4. Mobile app should automatically hide "Rental Request" option

Your mobile app will become truly dynamic and country-specific! 🌍
