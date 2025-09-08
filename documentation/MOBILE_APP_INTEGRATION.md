# 📱 Mobile App Module Integration Guide

## Overview
This guide shows how to integrate the dynamic module system into your React Native/Flutter mobile app.

## API Integration

### 1. Get Country Modules Configuration

**Endpoint:** `GET /getCountryModules/{countryCode}`

**Example Request:**
```javascript
// Get modules for Sri Lanka
const response = await fetch('https://YOUR-PROJECT.cloudfunctions.net/getCountryModules/LK');
const data = await response.json();

console.log(data);
// Response:
{
  "success": true,
  "countryCode": "LK",
  "modules": {
    "item": true,
    "service": true,
    "rent": false,
    "delivery": false,
    "ride": false,
    "price": false
  },
  "coreDependencies": {
    "payment": true,
    "messaging": true,
    "location": true,
    "driver": false
  },
  "moduleDetails": {
    "item": {
      "id": "item",
      "name": "Item Marketplace",
      "description": "Buy and sell items - electronics, furniture, clothing, etc.",
      "icon": "🛍️",
      "color": "#FF6B35",
      "features": ["Product listings", "Categories & subcategories", ...]
    },
    "service": {
      "id": "service", 
      "name": "Service Marketplace",
      "description": "Find and offer services - cleaning, repairs, tutoring, etc.",
      "icon": "🔧",
      "color": "#4ECDC4",
      "features": ["Service listings", "Professional profiles", ...]
    }
  },
  "enabledModules": ["item", "service"],
  "timestamp": "2025-08-14T10:30:00Z"
}
```

### 2. React Native Implementation

```javascript
// hooks/useCountryModules.js
import { useState, useEffect } from 'react';

export const useCountryModules = (countryCode) => {
  const [modules, setModules] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchModules = async () => {
      try {
        setLoading(true);
        const response = await fetch(
          `https://YOUR-PROJECT.cloudfunctions.net/getCountryModules/${countryCode}`
        );
        const data = await response.json();
        
        if (data.success) {
          setModules(data);
        } else {
          setError(data.error);
        }
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    if (countryCode) {
      fetchModules();
    }
  }, [countryCode]);

  return { modules, loading, error };
};
```

### 3. Dynamic Home Screen

```javascript
// screens/HomeScreen.js
import React from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { useCountryModules } from '../hooks/useCountryModules';

const HomeScreen = ({ navigation, userCountry = 'LK' }) => {
  const { modules, loading, error } = useCountryModules(userCountry);

  if (loading) return <Text>Loading modules...</Text>;
  if (error) return <Text>Error: {error}</Text>;

  const renderModuleCard = (moduleId) => {
    const moduleInfo = modules.moduleDetails[moduleId];
    
    return (
      <TouchableOpacity 
        key={moduleId}
        style={[styles.moduleCard, { borderColor: moduleInfo.color }]}
        onPress={() => navigation.navigate(`${moduleId}Stack`)}
      >
        <Text style={styles.moduleIcon}>{moduleInfo.icon}</Text>
        <Text style={styles.moduleName}>{moduleInfo.name}</Text>
        <Text style={styles.moduleDesc}>{moduleInfo.description}</Text>
      </TouchableOpacity>
    );
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>Welcome to Request Marketplace</Text>
      <Text style={styles.subtitle}>Available Services in {userCountry}</Text>
      
      <View style={styles.modulesGrid}>
        {modules.enabledModules.map(renderModuleCard)}
      </View>
    </ScrollView>
  );
};
```

### 4. Dynamic Navigation

```javascript
// navigation/AppNavigator.js
import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useCountryModules } from '../hooks/useCountryModules';

// Import all possible screens
import ItemListScreen from '../screens/item/ItemListScreen';
import ServiceListScreen from '../screens/service/ServiceListScreen';
import RentalListScreen from '../screens/rent/RentalListScreen';
import DeliveryScreen from '../screens/delivery/DeliveryScreen';
import RideScreen from '../screens/ride/RideScreen';
import PriceScreen from '../screens/price/PriceScreen';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

const DynamicTabNavigator = ({ userCountry = 'LK' }) => {
  const { modules, loading } = useCountryModules(userCountry);

  if (loading || !modules) {
    return <LoadingScreen />;
  }

  return (
    <Tab.Navigator>
      <Tab.Screen name="Home" component={HomeScreen} />
      
      {/* Dynamic tabs based on enabled modules */}
      {modules.modules.item && (
        <Tab.Screen 
          name="Items" 
          component={ItemListScreen}
          options={{
            tabBarIcon: ({ color }) => <Text style={{ color }}>🛍️</Text>
          }}
        />
      )}
      
      {modules.modules.service && (
        <Tab.Screen 
          name="Services" 
          component={ServiceListScreen}
          options={{
            tabBarIcon: ({ color }) => <Text style={{ color }}>🔧</Text>
          }}
        />
      )}
      
      {modules.modules.rent && (
        <Tab.Screen 
          name="Rentals" 
          component={RentalListScreen}
          options={{
            tabBarIcon: ({ color }) => <Text style={{ color }}>📅</Text>
          }}
        />
      )}
      
      {modules.modules.delivery && (
        <Tab.Screen 
          name="Delivery" 
          component={DeliveryScreen}
          options={{
            tabBarIcon: ({ color }) => <Text style={{ color }}>📦</Text>
          }}
        />
      )}
      
      {modules.modules.ride && (
        <Tab.Screen 
          name="Ride" 
          component={RideScreen}
          options={{
            tabBarIcon: ({ color }) => <Text style={{ color }}>🚗</Text>
          }}
        />
      )}
      
      {modules.modules.price && (
        <Tab.Screen 
          name="Prices" 
          component={PriceScreen}
          options={{
            tabBarIcon: ({ color }) => <Text style={{ color }}>💰</Text>
          }}
        />
      )}
    </Tab.Navigator>
  );
};
```

### 5. Module-Specific Features

```javascript
// components/ModuleFeatures.js
import React from 'react';
import { View, Text } from 'react-native';

export const ConditionalFeature = ({ moduleId, feature, children, userCountry }) => {
  const { modules } = useCountryModules(userCountry);
  
  if (!modules?.modules[moduleId]) {
    return null; // Module not enabled
  }
  
  const moduleDetails = modules.moduleDetails[moduleId];
  const hasFeature = moduleDetails?.features.includes(feature);
  
  return hasFeature ? children : null;
};

// Usage example:
const ItemDetailScreen = ({ userCountry }) => {
  return (
    <ScrollView>
      <Text>Item Details</Text>
      
      {/* Only show wishlist if item module supports it */}
      <ConditionalFeature 
        moduleId="item" 
        feature="Wishlist" 
        userCountry={userCountry}
      >
        <WishlistButton />
      </ConditionalFeature>
      
      {/* Only show reviews if item module supports it */}
      <ConditionalFeature 
        moduleId="item" 
        feature="Reviews & ratings" 
        userCountry={userCountry}
      >
        <ReviewsSection />
      </ConditionalFeature>
    </ScrollView>
  );
};
```

## Flutter Implementation

```dart
// services/module_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ModuleService {
  static const String baseUrl = 'https://YOUR-PROJECT.cloudfunctions.net';

  static Future<CountryModules?> getCountryModules(String countryCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getCountryModules/$countryCode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return CountryModules.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching modules: $e');
      return null;
    }
  }
}

// models/country_modules.dart
class CountryModules {
  final bool success;
  final String countryCode;
  final Map<String, bool> modules;
  final Map<String, bool> coreDependencies;
  final Map<String, ModuleDetail> moduleDetails;
  final List<String> enabledModules;

  CountryModules({
    required this.success,
    required this.countryCode,
    required this.modules,
    required this.coreDependencies,
    required this.moduleDetails,
    required this.enabledModules,
  });

  factory CountryModules.fromJson(Map<String, dynamic> json) {
    return CountryModules(
      success: json['success'],
      countryCode: json['countryCode'],
      modules: Map<String, bool>.from(json['modules']),
      coreDependencies: Map<String, bool>.from(json['coreDependencies']),
      moduleDetails: (json['moduleDetails'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, ModuleDetail.fromJson(value))),
      enabledModules: List<String>.from(json['enabledModules']),
    );
  }
}
```

## Implementation Steps

1. **Deploy Firebase Functions** - Deploy the Cloud Functions to handle module configuration API
2. **Update Mobile App** - Integrate the module fetching logic
3. **Dynamic Navigation** - Update your navigation to show/hide tabs based on enabled modules
4. **Conditional Features** - Wrap module-specific features in conditional components
5. **Testing** - Test with different country configurations

## Benefits

- ✅ **Country-Specific Features** - Each country can have different modules enabled
- ✅ **Easy Rollouts** - Enable new modules without app updates
- ✅ **A/B Testing** - Test new modules in specific countries
- ✅ **Reduced App Size** - Only load code for enabled modules
- ✅ **Admin Control** - Non-technical admins can control features

This system allows you to have one mobile app codebase that dynamically adapts to different country requirements! 🌍
