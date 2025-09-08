import 'package:flutter/material.dart';
import 'module_management_service.dart';
import '../widgets/coming_soon_widget.dart';

/// Service for gating features based on enabled modules
class FeatureGateService {
  static final FeatureGateService _instance = FeatureGateService._internal();
  factory FeatureGateService() => _instance;
  FeatureGateService._internal();

  static FeatureGateService get instance => _instance;

  /// Check if a specific module is enabled
  Future<bool> isModuleEnabled(BusinessModule module) async {
    final enabledModules =
        await ModuleManagementService.instance.getEnabledModules();
    return enabledModules.contains(module);
  }

  /// Check if driver registration should be available
  Future<bool> isDriverRegistrationEnabled() async {
    return await isModuleEnabled(BusinessModule.rideSharing);
  }

  /// Check if a business type should be available
  Future<bool> isBusinessTypeEnabled(String businessType) async {
    final enabledModules =
        await ModuleManagementService.instance.getEnabledModules();

    // Check each module's business types
    for (final module in enabledModules) {
      final config = ModuleManagementService.moduleConfigurations[module];
      if (config != null && config.businessTypes.contains(businessType)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a navigation feature should be available
  Future<bool> isNavigationFeatureEnabled(String feature) async {
    final enabledModules =
        await ModuleManagementService.instance.getEnabledModules();

    // Check each module's navigation features
    for (final module in enabledModules) {
      final config = ModuleManagementService.moduleConfigurations[module];
      if (config != null && config.navigationFeatures.contains(feature)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a menu feature should be available
  Future<bool> isMenuFeatureEnabled(String feature) async {
    final enabledModules =
        await ModuleManagementService.instance.getEnabledModules();

    // Check each module's menu features
    for (final module in enabledModules) {
      final config = ModuleManagementService.moduleConfigurations[module];
      if (config != null && config.menuFeatures.contains(feature)) {
        return true;
      }
    }
    return false;
  }

  /// Get filtered business types based on enabled modules
  Future<List<String>> getAvailableBusinessTypes() async {
    final enabledModules =
        await ModuleManagementService.instance.getEnabledModules();
    final Set<String> businessTypes = {};

    for (final module in enabledModules) {
      final config = ModuleManagementService.moduleConfigurations[module];
      if (config != null) {
        businessTypes.addAll(config.businessTypes);
      }
    }

    return businessTypes.toList();
  }

  /// Navigate to a feature or show coming soon if disabled
  Future<void> navigateOrShowComingSoon({
    required BuildContext context,
    required BusinessModule requiredModule,
    required String featureName,
    required String description,
    IconData? icon,
    VoidCallback? onEnabled,
  }) async {
    final isEnabled = await isModuleEnabled(requiredModule);

    if (isEnabled && onEnabled != null) {
      onEnabled();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ComingSoonWidget(
            title: featureName,
            description: description,
            icon: icon,
          ),
        ),
      );
    }
  }

  /// Show coming soon modal for disabled features
  Future<void> showComingSoonModal({
    required BuildContext context,
    required String featureName,
    required String description,
    IconData? icon,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ComingSoonWidget(
          title: featureName,
          description: description,
          icon: icon,
          showBackButton: false,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Gate a widget based on module availability
  Widget gateWidget({
    required BusinessModule requiredModule,
    required Widget enabledWidget,
    Widget? disabledWidget,
  }) {
    return FutureBuilder<bool>(
      future: isModuleEnabled(requiredModule),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Hide while loading
        }

        if (snapshot.data == true) {
          return enabledWidget;
        } else {
          return disabledWidget ?? const SizedBox.shrink();
        }
      },
    );
  }

  /// Get business type display name with availability
  Future<Map<String, dynamic>> getBusinessTypeInfo(String businessType) async {
    final isEnabled = await isBusinessTypeEnabled(businessType);

    final Map<String, String> typeNames = {
      'delivery': 'Delivery Services',
      'retail': 'Retail Store',
      'wholesale': 'Wholesale Business',
      'ecommerce': 'E-commerce Store',
      'restaurant': 'Restaurant',
      'service': 'Service Provider',
    };

    return {
      'name': typeNames[businessType] ?? businessType,
      'enabled': isEnabled,
      'comingSoon': !isEnabled,
    };
  }
}
