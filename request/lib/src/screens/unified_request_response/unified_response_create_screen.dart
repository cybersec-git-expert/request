import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../widgets/glass_page.dart';
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart';
import '../../services/centralized_request_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/user_registration_service.dart';
import '../../widgets/image_upload_widget.dart';
import '../../utils/currency_helper.dart';
import '../../widgets/accurate_location_picker_widget.dart';
import '../../services/country_service.dart';
import '../../utils/module_field_localizer.dart';

class UnifiedResponseCreateScreen extends StatefulWidget {
  final RequestModel request;

  const UnifiedResponseCreateScreen({super.key, required this.request});

  @override
  State<UnifiedResponseCreateScreen> createState() =>
      _UnifiedResponseCreateScreenState();
}

class _UnifiedResponseCreateScreenState
    extends State<UnifiedResponseCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final CentralizedRequestService _requestService = CentralizedRequestService();
  final EnhancedUserService _userService = EnhancedUserService();

  // Common controllers
  final _messageController = TextEditingController();
  final _priceController = TextEditingController();

  // Item response controllers
  final _offerPriceController = TextEditingController();
  final _itemConditionController = TextEditingController();
  final _offerDescriptionController = TextEditingController();
  final _deliveryCostController = TextEditingController();
  final _estimatedDeliveryController = TextEditingController();
  final _warrantyController = TextEditingController();

  // Service response controllers
  final _estimatedCostController = TextEditingController();
  final _timeframeController = TextEditingController();
  final _solutionDescriptionController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  // Rental response controllers
  final _rentalPriceController = TextEditingController();
  final _rentalItemConditionController = TextEditingController();
  final _rentalDescriptionController = TextEditingController();
  final _securityDepositController = TextEditingController();

  // Delivery response controllers
  final _deliveryFeeController = TextEditingController();
  final _estimatedPickupTimeController = TextEditingController();
  final _estimatedDropoffTimeController = TextEditingController();
  final _packageSizeController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  final _deliveryNotesController = TextEditingController();

  // Ride response controllers
  final _fareController = TextEditingController();
  final _routeDescriptionController = TextEditingController();
  final _driverNotesController = TextEditingController();

  // State variables
  String _selectedDeliveryMethod = 'User pickup';
  String _selectedPriceType = 'Fixed Price';
  String _selectedRentalPeriod = 'day';
  String _selectedPickupDeliveryOption = 'User picks up';
  String _selectedVehicleType = 'Car';
  String _selectedCurrency = 'LKR';
  DateTime? _availableFrom;
  DateTime? _availableUntil;
  List<String> _uploadedImages = [];
  bool _isLoading = false;
  // Location fields
  final _locationAddressController = TextEditingController();
  double? _locationLat;
  double? _locationLon;

  @override
  void dispose() {
    _locationAddressController.dispose();
    _messageController.dispose();
    _priceController.dispose();
    _offerPriceController.dispose();
    _itemConditionController.dispose();
    _offerDescriptionController.dispose();
    _deliveryCostController.dispose();
    _estimatedDeliveryController.dispose();
    _warrantyController.dispose();
    _estimatedCostController.dispose();
    _timeframeController.dispose();
    _solutionDescriptionController.dispose();
    _hourlyRateController.dispose();
    _rentalPriceController.dispose();
    _rentalItemConditionController.dispose();
    _rentalDescriptionController.dispose();
    _securityDepositController.dispose();
    _deliveryFeeController.dispose();
    _estimatedPickupTimeController.dispose();
    _estimatedDropoffTimeController.dispose();
    _packageSizeController.dispose();
    _specialInstructionsController.dispose();
    _deliveryNotesController.dispose();
    _fareController.dispose();
    _routeDescriptionController.dispose();
    _driverNotesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  int? _parseDateToMillis(String input) {
    if (input.isEmpty) return null;
    try {
      final dateParts = input.split('-');
      if (dateParts.length != 3) return null;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      return DateTime(year, month, day).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  // Async role validation using UserRegistrationService for better cache management
  Future<String?> _validateUserRoleAsync(UserModel user) async {
    switch (widget.request.type) {
      case RequestType.delivery:
        try {
          // Clear cache to get fresh data for delivery requests
          UserRegistrationService.instance.clearCache();

          // Get current registrations
          final registrations =
              await UserRegistrationService.instance.getUserRegistrations();

          if (registrations == null) {
            return 'delivery_business_required';
          }

          // Check if user is approved business with delivery capabilities
          if (registrations.isApprovedBusiness &&
              registrations.canHandleDeliveryRequests) {
            return null; // User is qualified for delivery
          }

          // If business exists but not approved
          if (registrations.hasPendingBusinessApplication) {
            return 'delivery_business_verification_required';
          }

          // No business registration found
          return 'delivery_business_required';
        } catch (e) {
          print('Error validating delivery role: $e');
          return 'delivery_business_required';
        }

      case RequestType.ride:
        // Check if user has driver role
        if (!user.hasRole(UserRole.driver)) {
          return 'driver_registration_required';
        }
        // Check if driver role is approved
        if (!user.isRoleVerified(UserRole.driver)) {
          return 'driver_verification_required';
        }
        break;

      default:
        // For other request types (item, service, rental), no specific role validation required
        return null;
    }
    return null;
  }

  void _navigateToRegistration() {
    switch (widget.request.type) {
      case RequestType.delivery:
        // Navigate to business registration
        Navigator.pushNamed(context, '/business-registration');
        break;
      case RequestType.ride:
        // Navigate to driver registration
        Navigator.pushNamed(context, '/driver-registration');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Respond to ${_getTypeDisplayName(widget.request.type)}',
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassTheme.glassCard(child: _buildRequestSummary()),
                  const SizedBox(height: 16),
                  _buildResponseFields(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitResponse,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _isLoading ? 'Submitting...' : 'Submit Response',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeDisplayName(RequestType type) {
    switch (type) {
      case RequestType.item:
        return 'Item Request';
      case RequestType.service:
        return 'Service Request';
      case RequestType.delivery:
        return 'Delivery Request';
      case RequestType.rental:
        return 'Rental Request';
      case RequestType.ride:
        return 'Ride Request';
      case RequestType.price:
        return 'Price Request';
    }
  }

  Widget _buildRequestSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getTypeIcon(widget.request.type),
              color: _getTypeColor(widget.request.type),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _getTypeDisplayName(widget.request.type),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _getTypeColor(widget.request.type),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.request.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.request.description,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.request.budget != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Budget: ${CurrencyHelper.instance.formatPrice(widget.request.budget ?? 0)}',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (widget.request.type == RequestType.service) ...[
          const SizedBox(height: 12),
          _buildServiceModuleContext(),
        ],
      ],
    );
  }

  Color _getTypeColor(RequestType type) {
    switch (type) {
      case RequestType.item:
        return const Color(0xFFFF6B35); // Orange/red
      case RequestType.service:
        return const Color(0xFF00BCD4); // Teal
      case RequestType.rental:
        return const Color(0xFF2196F3); // Blue
      case RequestType.delivery:
        return const Color(0xFF4CAF50); // Green
      case RequestType.ride:
        return const Color(0xFFFFC107); // Yellow
      case RequestType.price:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  IconData _getTypeIcon(RequestType type) {
    switch (type) {
      case RequestType.item:
        return Icons.shopping_bag;
      case RequestType.service:
        return Icons.build;
      case RequestType.delivery:
        return Icons.local_shipping;
      case RequestType.rental:
        return Icons.access_time;
      case RequestType.ride:
        return Icons.directions_car;
      case RequestType.price:
        return Icons.compare_arrows;
    }
  }

  Widget _buildServiceModuleContext() {
    final tsd = widget.request.typeSpecificData;
    final module = tsd['module']?.toString();
    final fields = tsd['moduleFields'];
    if (module == null || module.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[
      Row(
        children: [
          const Icon(Icons.category, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            'Service Module: ${module[0].toUpperCase()}${module.substring(1)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ];

    if (fields is Map && fields.isNotEmpty) {
      rows.add(const SizedBox(height: 8));
      fields.forEach((k, v) {
        if (v == null || (v is String && v.trim().isEmpty)) return;
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text('${ModuleFieldLocalizer.getLabel(k)}:',
                  style: TextStyle(
                      color: Colors.grey[700], fontWeight: FontWeight.w500)),
            ),
            Expanded(child: Text(v.toString())),
          ],
        ));
        rows.add(const SizedBox(height: 6));
      });
      if (rows.isNotEmpty) rows.removeLast();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildResponseFields() {
    return Column(
      children: [
        _buildCommonResponseField(),
        const SizedBox(height: 16),
        _buildTypeSpecificFields(),
      ],
    );
  }

  Widget _buildCommonResponseField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Message*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Explain why you\'re the best choice for this request...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Responder Location
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Responder Location*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              AccurateLocationPickerWidget(
                controller: _locationAddressController,
                countryCode: CountryService.instance.countryCode,
                labelText: '',
                hintText: 'Tap to pick responder location',
                isRequired: true,
                prefixIcon: Icons.location_on,
                enableCurrentLocationTap: true,
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _locationAddressController.text = address;
                    _locationLat = lat;
                    _locationLon = lng;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (widget.request.type) {
      case RequestType.item:
        return _buildItemResponseFields();
      case RequestType.service:
        return _buildServiceResponseFields();
      case RequestType.rental:
        return _buildRentalResponseFields();
      case RequestType.delivery:
        return _buildDeliveryResponseFields();
      case RequestType.ride:
        return _buildRideResponseFields();
      default:
        return const SizedBox();
    }
  }

  Widget _buildItemResponseFields() {
    return Column(
      children: [
        // Offer Price
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Offer Price*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _offerPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter your selling price',
                  prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an offer price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Item Condition
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Item Condition*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemConditionController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Brand new, Used - excellent condition',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please specify the item condition';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Offer Description
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Item Description*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _offerDescriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Detailed description of the item you\'re offering...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a detailed description';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Delivery Method
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery/Pickup Method*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDeliveryMethod,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                items: ['User pickup', 'I can deliver']
                    .map((method) =>
                        DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDeliveryMethod = value!;
                  });
                },
              ),
            ],
          ),
        ),

        // Delivery Cost (conditional)
        if (_selectedDeliveryMethod == 'I can deliver') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Cost',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deliveryCostController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Cost to deliver the item',
                    prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Estimated Delivery
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated Delivery (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estimatedDeliveryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Number of days for delivery',
                  suffixText: 'days',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Warranty
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warranty (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _warrantyController,
                decoration: const InputDecoration(
                  hintText: 'Warranty details (e.g., 30-day return policy)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Photo Upload
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photos (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload photos of the actual item you are offering',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ImageUploadWidget(
                uploadPath: 'responses/item',
                onImagesChanged: (images) {
                  setState(() {
                    _uploadedImages = images;
                  });
                },
                maxImages: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceResponseFields() {
    return Column(
      children: [
        // Price Type Selection
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pricing Type*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPriceType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                items: ['Fixed Price', 'Hourly Rate']
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPriceType = value!;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cost/Rate
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedPriceType == 'Fixed Price'
                    ? 'Total Cost*'
                    : 'Hourly Rate*',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _selectedPriceType == 'Fixed Price'
                    ? _estimatedCostController
                    : _hourlyRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: _selectedPriceType == 'Fixed Price'
                      ? 'Total estimated cost'
                      : 'Cost per hour',
                  prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                  suffixText:
                      _selectedPriceType == 'Hourly Rate' ? '/hr' : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the cost';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Timeframe
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated Timeframe*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeframeController,
                decoration: const InputDecoration(
                  hintText: 'e.g., 2-3 hours, 1 day, etc.',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide an estimated timeframe';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Available Dates
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Dates/Times',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available From',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _availableFrom = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F9FA),
                            ),
                            child: Text(
                              _availableFrom == null
                                  ? 'Select date'
                                  : '${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Until',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _availableFrom ?? DateTime.now(),
                              firstDate: _availableFrom ?? DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _availableUntil = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F9FA),
                            ),
                            child: Text(
                              _availableUntil == null
                                  ? 'Select date'
                                  : '${_availableUntil!.day}/${_availableUntil!.month}/${_availableUntil!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Solution Description
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Description of Solution*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _solutionDescriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Brief explanation of how you plan to solve the problem',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe your solution';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Portfolio Upload
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo/Portfolio (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload photos of your previous work or portfolio',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ImageUploadWidget(
                uploadPath: 'responses/service',
                onImagesChanged: (images) {
                  setState(() {
                    _uploadedImages = images;
                  });
                },
                maxImages: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRentalResponseFields() {
    return Column(
      children: [
        // Rental Price
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rental Price*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _rentalPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Price',
                        prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter rental price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedRentalPeriod,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        filled: true,
                        fillColor: Color(0xFFF8F9FA),
                      ),
                      items: ['day', 'week', 'hour']
                          .map((period) => DropdownMenuItem(
                                value: period,
                                child: Text(
                                  'per $period',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRentalPeriod = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Availability
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Availability*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available From',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _availableFrom = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F9FA),
                            ),
                            child: Text(
                              _availableFrom == null
                                  ? 'Select date'
                                  : '${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Until',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _availableFrom ?? DateTime.now(),
                              firstDate: _availableFrom ?? DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _availableUntil = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F9FA),
                            ),
                            child: Text(
                              _availableUntil == null
                                  ? 'Select date'
                                  : '${_availableUntil!.day}/${_availableUntil!.month}/${_availableUntil!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Item Condition
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Item Condition*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rentalItemConditionController,
                decoration: const InputDecoration(
                  hintText: 'Current condition of the rental item',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please specify item condition';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Description
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Item Description*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rentalDescriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Detailed description of the rental item',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide item description';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pickup/Delivery Options
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pickup/Delivery Options*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPickupDeliveryOption,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                items: [
                  'User picks up',
                  'I can deliver',
                  'Both options available'
                ]
                    .map((option) =>
                        DropdownMenuItem(value: option, child: Text(option)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPickupDeliveryOption = value!;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Security Deposit
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Security Deposit (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _securityDepositController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Security deposit amount',
                  prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Photo Upload
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photos (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload photos of the rental item',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ImageUploadWidget(
                uploadPath: 'responses/rental',
                onImagesChanged: (images) {
                  setState(() {
                    _uploadedImages = images;
                  });
                },
                maxImages: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryResponseFields() {
    return Column(
      children: [
        // Delivery Fee
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery Fee*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deliveryFeeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Your delivery service fee',
                  prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter delivery fee';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Vehicle Type
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Type*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                items: ['Car', 'Van', 'Truck', 'Motorcycle', 'Bicycle']
                    .map((vehicle) =>
                        DropdownMenuItem(value: vehicle, child: Text(vehicle)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVehicleType = value!;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Estimated Dates (date-only)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated Dates*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _estimatedPickupTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Date',
                        hintText: 'Select pickup date',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        filled: true,
                        fillColor: Color(0xFFF8F9FA),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date == null) return;
                        _estimatedPickupTimeController.text = _formatDate(date);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _estimatedDropoffTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Drop-off Date',
                        hintText: 'Select drop-off date',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        filled: true,
                        fillColor: Color(0xFFF8F9FA),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date == null) return;
                        _estimatedDropoffTimeController.text =
                            _formatDate(date);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Special Considerations
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Special Instructions (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specialInstructionsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Any notes or concerns about the delivery (e.g., size limitations)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Confirmation
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              Checkbox(
                value: true, // Always true for acceptance
                onChanged: (value) {
                  // Always accept when responding
                },
              ),
              const Expanded(
                child: Text(
                  'I confirm that I can complete this delivery request as described',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideResponseFields() {
    return Column(
      children: [
        // Fare
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Proposed Fare*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fareController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Your fare for this ride',
                  prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a fare';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Vehicle Type
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Type*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
                items: ['Car', 'Van', 'Truck', 'Motorcycle', 'Bicycle']
                    .map((vehicle) =>
                        DropdownMenuItem(value: vehicle, child: Text(vehicle)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVehicleType = value!;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Route Description
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Route Description (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _routeDescriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Any particular route preferences',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Driver Notes
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver Notes (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _driverNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Anything the requester should know',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  filled: true,
                  fillColor: Color(0xFFF8F9FA),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitResponse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _userService.getCurrentUserModel();
      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Enforce location requirement
      if (_locationAddressController.text.trim().isEmpty ||
          _locationLat == null ||
          _locationLon == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please pick a responder location'),
            backgroundColor: Colors.red,
          ));
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Role-based validation with cache clearing for delivery requests
      final validationError = await _validateUserRoleAsync(currentUser);
      if (validationError != null) {
        setState(() {
          _isLoading = false;
        });

        // Show user-friendly error messages
        String message;
        String actionLabel = 'Register';

        switch (validationError) {
          case 'delivery_business_required':
            message =
                'You need to register as a delivery business to respond to delivery requests';
            break;
          case 'delivery_business_verification_required':
            message =
                'Your delivery business registration is pending approval. Please wait for verification.';
            actionLabel = 'Check Status';
            break;
          case 'driver_registration_required':
            message =
                'You need to register as a driver to respond to ride requests';
            break;
          case 'driver_verification_required':
            message =
                'Your driver registration is pending approval. Please wait for verification.';
            actionLabel = 'Check Status';
            break;
          default:
            message = 'You don\'t have permission to respond to this request';
            actionLabel = 'Learn More';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: actionLabel == 'Register'
                ? SnackBarAction(
                    label: actionLabel,
                    textColor: Colors.white,
                    onPressed: () {
                      // Navigate to appropriate registration screen
                      _navigateToRegistration();
                    },
                  )
                : null,
          ),
        );
        return;
      }

      // Prepare response data
      double? price;
      Map<String, dynamic> additionalInfo = {};

      switch (widget.request.type) {
        case RequestType.item:
          price = double.tryParse(_offerPriceController.text.trim());
          additionalInfo = {
            'itemCondition': _itemConditionController.text.trim(),
            'offerDescription': _offerDescriptionController.text.trim(),
            'deliveryMethod': _selectedDeliveryMethod,
            'deliveryCost': _deliveryCostController.text.trim().isNotEmpty
                ? double.tryParse(_deliveryCostController.text.trim())
                : null,
            'estimatedDelivery':
                _estimatedDeliveryController.text.trim().isNotEmpty
                    ? int.tryParse(_estimatedDeliveryController.text.trim())
                    : null,
            'warranty': _warrantyController.text.trim().isNotEmpty
                ? _warrantyController.text.trim()
                : null,
            'images': _uploadedImages,
          };
          break;
        case RequestType.service:
          price = double.tryParse(_selectedPriceType == 'Fixed Price'
              ? _estimatedCostController.text.trim()
              : _hourlyRateController.text.trim());
          additionalInfo = {
            'priceType': _selectedPriceType,
            'timeframe': _timeframeController.text.trim(),
            'availableFrom': _availableFrom?.millisecondsSinceEpoch,
            'availableUntil': _availableUntil?.millisecondsSinceEpoch,
            'solutionDescription': _solutionDescriptionController.text.trim(),
            'images': _uploadedImages,
          };
          break;
        case RequestType.rental:
          price = double.tryParse(_rentalPriceController.text.trim());
          additionalInfo = {
            'rentalPeriod': _selectedRentalPeriod,
            'itemCondition': _rentalItemConditionController.text.trim(),
            'itemDescription': _rentalDescriptionController.text.trim(),
            'pickupDeliveryOption': _selectedPickupDeliveryOption,
            'securityDeposit': _securityDepositController.text.trim().isNotEmpty
                ? double.tryParse(_securityDepositController.text.trim())
                : null,
            'availableFrom': _availableFrom?.millisecondsSinceEpoch,
            'availableUntil': _availableUntil?.millisecondsSinceEpoch,
            'images': _uploadedImages,
          };
          break;
        case RequestType.delivery:
          price = double.tryParse(_deliveryFeeController.text.trim());
          additionalInfo = {
            'vehicleType': _selectedVehicleType,
            // Store as millisecondsSinceEpoch if parseable
            'estimatedPickupTime':
                _parseDateToMillis(_estimatedPickupTimeController.text.trim()),
            'estimatedDropoffTime':
                _parseDateToMillis(_estimatedDropoffTimeController.text.trim()),
            'specialInstructions': _specialInstructionsController.text.trim(),
          };
          break;
        case RequestType.ride:
          price = double.tryParse(_fareController.text.trim());
          additionalInfo = {
            'vehicleType': _selectedVehicleType,
            'routeDescription': _routeDescriptionController.text.trim(),
            'driverNotes': _driverNotesController.text.trim(),
          };
          break;
        default:
          break;
      }

      // Get country code from CountryService
      final countryCode = CountryService.instance.getCurrentCountryCode();

      // Submit the response
      await _requestService.createResponse(
        widget.request.id,
        {
          'message': _messageController.text.trim(),
          'price': price,
          'currency': _selectedCurrency,
          'availableDate': _availableFrom?.toIso8601String(),
          'images': _uploadedImages,
          'additionalData': additionalInfo,
          // Location is mandatory now
          'location_address': _locationAddressController.text.trim(),
          'location_latitude': _locationLat,
          'location_longitude': _locationLon,
          'country_code': countryCode,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final human = msg.contains('limit')
            ? 'Monthly response limit reached for this month.'
            : msg.replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(human.isNotEmpty ? human : 'Error submitting response'),
            backgroundColor: Colors.red,
            action: human.contains('Monthly response limit')
                ? SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
