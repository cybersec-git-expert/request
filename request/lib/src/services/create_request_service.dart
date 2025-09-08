import 'package:flutter/material.dart';
import '../services/module_management_service.dart';
import '../widgets/coming_soon_widget.dart';

class RequestTypeOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String requestType;
  final BusinessModule module;
  final bool isEnabled;
  final VoidCallback? onTap;

  const RequestTypeOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.requestType,
    required this.module,
    required this.isEnabled,
    this.onTap,
  });

  RequestTypeOption copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    Color? color,
    String? requestType,
    BusinessModule? module,
    bool? isEnabled,
    VoidCallback? onTap,
  }) {
    return RequestTypeOption(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      requestType: requestType ?? this.requestType,
      module: module ?? this.module,
      isEnabled: isEnabled ?? this.isEnabled,
      onTap: onTap ?? this.onTap,
    );
  }
}

class CreateRequestService {
  static final CreateRequestService _instance =
      CreateRequestService._internal();
  factory CreateRequestService() => _instance;
  CreateRequestService._internal();

  static CreateRequestService get instance => _instance;

  final ModuleManagementService _moduleService =
      ModuleManagementService.instance;

  // All available request types with their configurations
  final List<RequestTypeOption> _allRequestTypes = [
    RequestTypeOption(
      id: 'item',
      title: 'Item Request',
      description: 'Request for products or items',
      icon: Icons.shopping_bag,
      color: Colors.orange,
      requestType: 'item',
      module: BusinessModule.itemRequest,
      isEnabled: false, // Will be updated dynamically
    ),
    RequestTypeOption(
      id: 'service',
      title: 'Service Request',
      description: 'Request for services',
      icon: Icons.build,
      color: Colors.blue,
      requestType: 'service',
      module: BusinessModule.serviceRequest,
      isEnabled: false,
    ),
    RequestTypeOption(
      id: 'rental',
      title: 'Rental Request',
      description: 'Rent vehicles, equipment, or items',
      icon: Icons.key,
      color: Colors.purple,
      requestType: 'rental',
      module: BusinessModule.rentalRequest,
      isEnabled: false,
    ),
    RequestTypeOption(
      id: 'delivery',
      title: 'Delivery Request',
      description: 'Request for delivery services',
      icon: Icons.local_shipping,
      color: Colors.green,
      requestType: 'delivery',
      module: BusinessModule.deliveryRequest,
      isEnabled: false,
    ),
    RequestTypeOption(
      id: 'ride',
      title: 'Ride Request',
      description: 'Request for transportation',
      icon: Icons.directions_car,
      color: Colors.yellow[700]!,
      requestType: 'ride',
      module: BusinessModule.rideSharing,
      isEnabled: false,
    ),
    RequestTypeOption(
      id: 'price',
      title: 'Price Request',
      description: 'Request price quotes for items or services',
      icon: Icons.trending_up,
      color: Colors.indigo,
      requestType: 'price',
      module: BusinessModule.priceRequest,
      isEnabled: false,
    ),
  ];

  /// Get all request type options with their enabled status
  Future<List<RequestTypeOption>> getRequestTypeOptions() async {
    final enabledModules = await _moduleService.getEnabledModules();

    return _allRequestTypes.map((option) {
      return option.copyWith(
        isEnabled: enabledModules.contains(option.module),
      );
    }).toList();
  }

  /// Get only enabled request type options
  Future<List<RequestTypeOption>> getEnabledRequestTypeOptions() async {
    final options = await getRequestTypeOptions();
    return options.where((option) => option.isEnabled).toList();
  }

  /// Get a specific request type option by ID
  Future<RequestTypeOption?> getRequestTypeOption(String id) async {
    final options = await getRequestTypeOptions();
    try {
      return options.firstWhere((option) => option.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if a specific request type is enabled
  Future<bool> isRequestTypeEnabled(String requestType) async {
    return await _moduleService.isRequestTypeEnabled(requestType);
  }

  /// Navigate to create request screen or show coming soon
  Future<void> navigateToCreateRequest({
    required BuildContext context,
    required String requestType,
    Map<String, dynamic>? initialData,
  }) async {
    final isEnabled = await isRequestTypeEnabled(requestType);

    if (!isEnabled) {
      // Show coming soon screen
      final option = await getRequestTypeOption(requestType);
      if (option != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ComingSoonWidget(
              title: option.title,
              description:
                  '${option.description}\n\nThis service is not available in your region yet.',
              icon: option.icon,
            ),
          ),
        );
      }
      return;
    }

    // Navigate to appropriate create request screen
    switch (requestType.toLowerCase()) {
      case 'item':
        _navigateToItemRequest(context, initialData);
        break;
      case 'service':
        _navigateToServiceRequest(context, initialData);
        break;
      case 'rental':
      case 'rent':
        _navigateToRentalRequest(context, initialData);
        break;
      case 'delivery':
        _navigateToDeliveryRequest(context, initialData);
        break;
      case 'ride':
        _navigateToRideRequest(context, initialData);
        break;
      case 'price':
        _navigateToPriceRequest(context, initialData);
        break;
      default:
        _showUnknownRequestTypeError(context, requestType);
    }
  }

  void _navigateToItemRequest(
      BuildContext context, Map<String, dynamic>? initialData) {
    // TODO: Navigate to item request creation screen
    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreateItemRequestScreen(initialData: initialData)));
    _showNotImplementedMessage(context, 'Item Request');
  }

  void _navigateToServiceRequest(
      BuildContext context, Map<String, dynamic>? initialData) {
    // TODO: Navigate to service request creation screen
    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreateServiceRequestScreen(initialData: initialData)));
    _showNotImplementedMessage(context, 'Service Request');
  }

  void _navigateToRentalRequest(
      BuildContext context, Map<String, dynamic>? initialData) {
    // TODO: Navigate to rental request creation screen
    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreateRentalRequestScreen(initialData: initialData)));
    _showNotImplementedMessage(context, 'Rental Request');
  }

  void _navigateToDeliveryRequest(
      BuildContext context, Map<String, dynamic>? initialData) {
    // TODO: Navigate to delivery request creation screen
    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreateDeliveryRequestScreen(initialData: initialData)));
    _showNotImplementedMessage(context, 'Delivery Request');
  }

  void _navigateToRideRequest(
      BuildContext context, Map<String, dynamic>? initialData) {
    // TODO: Navigate to ride request creation screen
    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreateRideRequestScreen(initialData: initialData)));
    _showNotImplementedMessage(context, 'Ride Request');
  }

  void _navigateToPriceRequest(
      BuildContext context, Map<String, dynamic>? initialData) {
    // TODO: Navigate to price request creation screen
    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreatePriceRequestScreen(initialData: initialData)));
    _showNotImplementedMessage(context, 'Price Request');
  }

  void _showUnknownRequestTypeError(BuildContext context, String requestType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unknown request type: $requestType'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showNotImplementedMessage(BuildContext context, String requestType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$requestType creation screen is not implemented yet'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

/// Widget for displaying request type options in a grid or list
class RequestTypeOptionsWidget extends StatelessWidget {
  final bool showDisabled;
  final Function(RequestTypeOption) onOptionTap;

  const RequestTypeOptionsWidget({
    Key? key,
    this.showDisabled = true,
    required this.onOptionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RequestTypeOption>>(
      future: showDisabled
          ? CreateRequestService.instance.getRequestTypeOptions()
          : CreateRequestService.instance.getEnabledRequestTypeOptions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading request types: ${snapshot.error}'),
          );
        }

        final options = snapshot.data ?? [];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return RequestTypeOptionCard(
              option: option,
              onTap: () => onOptionTap(option),
            );
          },
        );
      },
    );
  }
}

/// Individual request type option card
class RequestTypeOptionCard extends StatelessWidget {
  final RequestTypeOption option;
  final VoidCallback onTap;

  const RequestTypeOptionCard({
    Key? key,
    required this.option,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: option.isEnabled ? 4 : 1,
      child: InkWell(
        onTap: option.isEnabled ? onTap : () => _showComingSoonMessage(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: option.isEnabled ? null : Colors.grey[100],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                option.icon,
                size: 40,
                color: option.isEnabled ? option.color : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                option.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: option.isEnabled ? option.color : Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                option.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: option.isEnabled
                          ? Colors.grey[600]
                          : Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!option.isEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${option.title} is coming soon to your region!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
