import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../widgets/glass_page.dart';
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart';
import '../../services/enhanced_request_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/user_registration_service.dart';
import '../../widgets/image_upload_widget.dart';
import '../../utils/currency_helper.dart';
import '../../widgets/accurate_location_picker_widget.dart';
import '../../utils/module_field_localizer.dart';
import '../../services/country_service.dart';

class UnifiedResponseEditScreen extends StatefulWidget {
  final RequestModel request;
  final ResponseModel response;

  const UnifiedResponseEditScreen({
    super.key,
    required this.request,
    required this.response,
  });

  @override
  State<UnifiedResponseEditScreen> createState() =>
      _UnifiedResponseEditScreenState();
}

class _UnifiedResponseEditScreenState extends State<UnifiedResponseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final EnhancedRequestService _requestService = EnhancedRequestService();
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

  // Additional common controllers
  final _notesController = TextEditingController();
  final _specialConsiderationsController = TextEditingController();

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
  // Location controllers
  final _locationAddressController = TextEditingController();
  final _locationLatitudeController = TextEditingController();
  final _locationLongitudeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeFormData();
    // Force a rebuild after initialization to ensure images are displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
        // Reload metadata if empty OR required item fields missing
        if (widget.response.additionalInfo.isEmpty ||
            _needsItemFieldHydration()) {
          _attemptReloadMetadata();
        }
      }
    });
  }

  bool _needsItemFieldHydration() {
    if (widget.request.type != RequestType.item) return false;
    final info = widget.response.additionalInfo;
    bool missing(String k) => !(info.containsKey(k)) || info[k] == null;
    // Controllers empty or metadata keys absent
    return _itemConditionController.text.isEmpty && missing('itemCondition') ||
        _offerDescriptionController.text.isEmpty &&
            missing('offerDescription') ||
        _deliveryCostController.text.isEmpty && missing('deliveryCost') ||
        _estimatedDeliveryController.text.isEmpty &&
            missing('estimatedDelivery') ||
        _warrantyController.text.isEmpty && missing('warranty') ||
        _selectedDeliveryMethod.isEmpty && missing('deliveryMethod');
  }

  Future<void> _attemptReloadMetadata() async {
    try {
      final responses =
          await _requestService.getResponsesForRequest(widget.request.id);
      ResponseModel? fresh;
      for (final r in responses) {
        if (r.id == widget.response.id) {
          fresh = r;
          break;
        }
      }
      if (fresh == null || fresh.additionalInfo.isEmpty) return;
      final info = fresh.additionalInfo;
      setState(() {
        // Only fill if still empty so we don't overwrite user edits
        if (_itemConditionController.text.isEmpty &&
            info['itemCondition'] != null) {
          _itemConditionController.text = info['itemCondition'].toString();
        }
        if (_offerDescriptionController.text.isEmpty &&
            info['offerDescription'] != null) {
          _offerDescriptionController.text =
              info['offerDescription'].toString();
        }
        if (_rentalItemConditionController.text.isEmpty &&
            info['itemCondition'] != null) {
          _rentalItemConditionController.text =
              info['itemCondition'].toString();
        }
        if (_rentalDescriptionController.text.isEmpty &&
            info['itemDescription'] != null) {
          _rentalDescriptionController.text =
              info['itemDescription'].toString();
        }
        if (_solutionDescriptionController.text.isEmpty &&
            info['solutionDescription'] != null) {
          _solutionDescriptionController.text =
              info['solutionDescription'].toString();
        }
        if (_timeframeController.text.isEmpty && info['timeframe'] != null) {
          _timeframeController.text = info['timeframe'].toString();
        }
        if (_deliveryFeeController.text.isEmpty &&
            info['deliveryFee'] != null) {
          _deliveryFeeController.text = _formatPrice(info['deliveryFee']);
        }
        if (_fareController.text.isEmpty && info['fare'] != null) {
          _fareController.text = _formatPrice(info['fare']);
        }
        if (_notesController.text.isEmpty && info['notes'] != null) {
          _notesController.text = info['notes'].toString();
        }
        if (_specialConsiderationsController.text.isEmpty &&
            info['specialConsiderations'] != null) {
          _specialConsiderationsController.text =
              info['specialConsiderations'].toString();
        }
        // Item-specific (previously missing)
        if (_deliveryCostController.text.isEmpty &&
            info['deliveryCost'] != null) {
          _deliveryCostController.text = _formatPrice(info['deliveryCost']);
        }
        if (_estimatedDeliveryController.text.isEmpty &&
            info['estimatedDelivery'] != null) {
          _estimatedDeliveryController.text =
              info['estimatedDelivery'].toString();
        }
        if (_warrantyController.text.isEmpty && info['warranty'] != null) {
          _warrantyController.text = info['warranty'].toString();
        }
        // Select values
        if (info['deliveryMethod'] != null)
          _selectedDeliveryMethod = info['deliveryMethod'].toString();
        if (info['priceType'] != null)
          _selectedPriceType = info['priceType'].toString();
        if (info['rentalPeriod'] != null)
          _selectedRentalPeriod = info['rentalPeriod'].toString();
        if (info['pickupDeliveryOption'] != null)
          _selectedPickupDeliveryOption =
              info['pickupDeliveryOption'].toString();
        if (info['vehicleType'] != null)
          _selectedVehicleType = info['vehicleType'].toString();
        // Images
        if (_uploadedImages.isEmpty && fresh!.images.isNotEmpty) {
          _uploadedImages = List<String>.from(fresh.images);
        }
        // Location
        if (_locationAddressController.text.isEmpty) {
          final locAddr = info['location_address'] ?? info['locationAddress'];
          if (locAddr != null)
            _locationAddressController.text = locAddr.toString();
        }
        if (_locationLatitudeController.text.isEmpty &&
            info['location_latitude'] != null) {
          _locationLatitudeController.text =
              info['location_latitude'].toString();
        }
        if (_locationLongitudeController.text.isEmpty &&
            info['location_longitude'] != null) {
          _locationLongitudeController.text =
              info['location_longitude'].toString();
        }
      });
    } catch (e) {
      // Silent fail; dev log
      // ignore: avoid_print
      print('[UnifiedResponseEditScreen] metadata reload failed: $e');
    }
  }

  void _initializeFormData() {
    // Initialize common fields
    _messageController.text = widget.response.message;
    _priceController.text = _formatPrice(widget.response.price);

    // Get fields from additionalInfo
    final additionalInfo = widget.response.additionalInfo;
    _notesController.text = additionalInfo['notes']?.toString() ?? '';
    _specialConsiderationsController.text =
        additionalInfo['specialConsiderations']?.toString() ?? '';

    // Initialize currency and dates
    _selectedCurrency = widget.response.currency ?? 'LKR';
    _availableFrom = widget.response.availableFrom;
    _availableUntil = widget.response.availableUntil;

    // Initialize images - prioritize main images field, then additionalInfo
    _uploadedImages = List<String>.from(widget.response.images);
    if (_uploadedImages.isEmpty && additionalInfo['images'] != null) {
      _uploadedImages = List<String>.from(additionalInfo['images'] ?? []);
    }

    // Debug: Print additionalInfo to see what's actually there
    print('🔍 DEBUG: AdditionalInfo contents:');
    print(additionalInfo);
    print('🔍 DEBUG: Location fields in additionalInfo:');
    print('  location_address: ${additionalInfo['location_address']}');
    print('  location_latitude: ${additionalInfo['location_latitude']}');
    print('  location_longitude: ${additionalInfo['location_longitude']}');
    print('  locationAddress: ${additionalInfo['locationAddress']}');

    // Check if response has direct location fields (newer responses)
    print('🔍 DEBUG: Checking response model for direct location fields:');
    final responseLocationAddress =
        widget.response.additionalInfo['location_address'];
    final responseLocationLat =
        widget.response.additionalInfo['location_latitude'];
    final responseLocationLng =
        widget.response.additionalInfo['location_longitude'];
    print('  response locationAddress: $responseLocationAddress');
    print('  response locationLatitude: $responseLocationLat');
    print('  response locationLongitude: $responseLocationLng');

    // Initialize location (prioritize additionalInfo, then response model fields)
    final locAddr = additionalInfo['location_address'] ??
        additionalInfo['locationAddress'] ??
        responseLocationAddress;
    if (locAddr != null) {
      _locationAddressController.text = locAddr.toString();
      print('🔍 DEBUG: Set location address to: ${locAddr.toString()}');
    } else {
      print(
          '🔍 DEBUG: No location address found in additionalInfo or response');
    }

    final locLat = additionalInfo['location_latitude'] ?? responseLocationLat;
    if (locLat != null) {
      _locationLatitudeController.text = locLat.toString();
      print('🔍 DEBUG: Set location latitude to: $locLat');
    }

    final locLng = additionalInfo['location_longitude'] ?? responseLocationLng;
    if (locLng != null) {
      _locationLongitudeController.text = locLng.toString();
      print('🔍 DEBUG: Set location longitude to: $locLng');
    }

    // Initialize type-specific fields based on request type
    switch (widget.request.type) {
      case RequestType.rental:
        // Rental price is stored in main price field
        _rentalPriceController.text = _formatPrice(widget.response.price);
        _securityDepositController.text =
            _formatPrice(additionalInfo['securityDeposit']);
        _selectedRentalPeriod =
            additionalInfo['rentalPeriod']?.toString() ?? 'day';
        _selectedPickupDeliveryOption =
            additionalInfo['pickupDeliveryOption']?.toString() ??
                'User picks up';
        _rentalItemConditionController.text =
            additionalInfo['itemCondition']?.toString() ?? '';
        _rentalDescriptionController.text =
            additionalInfo['itemDescription']?.toString() ?? '';
        break;
      case RequestType.delivery:
        // Delivery fee historically stored as main response.price, fallback if additionalInfo key missing
        final deliveryFeeRaw = additionalInfo['deliveryFee'];
        if (deliveryFeeRaw != null) {
          _deliveryFeeController.text = _formatPrice(deliveryFeeRaw);
        } else {
          _deliveryFeeController.text = _formatPrice(widget.response.price);
        }
        _deliveryNotesController.text =
            additionalInfo['deliveryNotes']?.toString() ?? '';
        _selectedVehicleType =
            additionalInfo['vehicleType']?.toString() ?? 'Car';

        // Initialize pickup and dropoff times from metadata
        final pickupTimeRaw = additionalInfo['estimatedPickupTime'];
        if (pickupTimeRaw != null) {
          try {
            final pickupTime = DateTime.fromMillisecondsSinceEpoch(
                pickupTimeRaw is int
                    ? pickupTimeRaw
                    : int.parse(pickupTimeRaw.toString()));
            _estimatedPickupTimeController.text = _formatDate(pickupTime);
          } catch (e) {
            print('Error parsing pickup time: $e');
          }
        }

        final dropoffTimeRaw = additionalInfo['estimatedDropoffTime'];
        if (dropoffTimeRaw != null) {
          try {
            final dropoffTime = DateTime.fromMillisecondsSinceEpoch(
                dropoffTimeRaw is int
                    ? dropoffTimeRaw
                    : int.parse(dropoffTimeRaw.toString()));
            _estimatedDropoffTimeController.text = _formatDate(dropoffTime);
          } catch (e) {
            print('Error parsing dropoff time: $e');
          }
        }

        // Initialize special instructions
        _specialInstructionsController.text =
            additionalInfo['specialInstructions']?.toString() ?? '';
        break;
      case RequestType.ride:
        _fareController.text = _formatPrice(additionalInfo['fare']);
        _routeDescriptionController.text =
            additionalInfo['routeDescription']?.toString() ?? '';
        _driverNotesController.text =
            additionalInfo['driverNotes']?.toString() ?? '';
        _selectedVehicleType =
            additionalInfo['vehicleType']?.toString() ?? 'Car';
        break;
      case RequestType.item:
        // Offer price is stored in main price field
        _offerPriceController.text = _formatPrice(widget.response.price);
        _itemConditionController.text =
            additionalInfo['itemCondition']?.toString() ?? '';
        _offerDescriptionController.text =
            additionalInfo['offerDescription']?.toString() ?? '';
        _selectedDeliveryMethod =
            additionalInfo['deliveryMethod']?.toString() ?? 'User pickup';
        _deliveryCostController.text =
            _formatPrice(additionalInfo['deliveryCost']);
        _estimatedDeliveryController.text =
            additionalInfo['estimatedDelivery']?.toString() ?? '';
        _warrantyController.text = additionalInfo['warranty']?.toString() ?? '';
        break;
      case RequestType.service:
        // Service price is stored in main price field
        _selectedPriceType =
            additionalInfo['priceType']?.toString() ?? 'Fixed Price';
        if (_selectedPriceType == 'Fixed Price') {
          _estimatedCostController.text = _formatPrice(widget.response.price);
        } else {
          _hourlyRateController.text = _formatPrice(widget.response.price);
        }
        _timeframeController.text =
            additionalInfo['timeframe']?.toString() ?? '';
        _solutionDescriptionController.text =
            additionalInfo['solutionDescription']?.toString() ?? '';
        break;
      case RequestType.price:
        // Handle price comparison requests if needed
        break;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '';
    double? priceValue =
        price is double ? price : double.tryParse(price.toString());
    if (priceValue == null) return '';

    // Remove unnecessary decimal places
    if (priceValue == priceValue.roundToDouble()) {
      return priceValue.round().toString();
    } else {
      return priceValue.toString();
    }
  }

  @override
  void dispose() {
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
    _notesController.dispose();
    _specialConsiderationsController.dispose();
    _locationAddressController.dispose();
    _locationLatitudeController.dispose();
    _locationLongitudeController.dispose();
    super.dispose();
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

  double? _parsePriceInput(String text) {
    if (text.trim().isEmpty) return null;
    final sanitized = text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  // Date-only formatting for display
  String _formatDate(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  // Parse YYYY-MM-DD to epoch ms
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
      title: 'Edit Response to ${_getTypeDisplayName(widget.request.type)}',
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassTheme.glassCard(child: _buildRequestSummary()),
              const SizedBox(height: 16),
              GlassTheme.glassCard(child: _buildResponseFields()),
            ],
          ),
        ),
      ),
      bottomBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitResponse,
              style: GlassTheme.primaryButton,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Response'),
            ),
          ),
        ),
      ),
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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
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
          // Module + fields context for service requests
          if (widget.request.type == RequestType.service)
            ..._buildServiceModuleContext(widget.request.typeSpecificData),
        ],
      ),
    );
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

  List<Widget> _buildServiceModuleContext(Map<String, dynamic> tsd) {
    final module = tsd['module']?.toString();
    final fields = tsd['moduleFields'];
    if (module == null || module.isEmpty) return const [];

    String prettyLabel(String key) => ModuleFieldLocalizer.getLabel(key);

    final rows = <Widget>[
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (fields is Map && fields.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...fields.entries
                  .map((e) {
                    final k = prettyLabel(e.key);
                    final v = e.value;
                    if (v == null || (v is String && v.trim().isEmpty)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              '$k:',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              v.toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w400),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .where((w) => w is! SizedBox)
                  .toList(),
            ],
          ],
        ),
      ),
    ];

    return rows;
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
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
          const SizedBox(height: 20),
          const Text('Responder Location*',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              print('🔍 DEBUG: Building AccurateLocationPickerWidget');
              print('  Controller text: "${_locationAddressController.text}"');
              print('  Request type: ${widget.request.type}');
              return AccurateLocationPickerWidget(
                controller: _locationAddressController,
                countryCode: CountryService.instance.countryCode,
                hintText: 'Tap to pick responder location',
                isRequired: true,
                prefixIcon: Icons.location_on,
                enableCurrentLocationTap: true,
                onLocationSelected: (address, lat, lng) {
                  print('🔍 DEBUG: Location selected callback triggered');
                  print('  New address: "$address"');
                  print('  New lat: $lat');
                  print('  New lng: $lng');
                  setState(() {
                    _locationAddressController.text = address;
                    _locationLatitudeController.text = lat.toString();
                    _locationLongitudeController.text = lng.toString();
                  });
                },
              );
            },
          ),
        ],
      ),
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

        // Delivery Cost (show always if value exists or delivery selected; keeps visibility for editing existing data)
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
                  hintText: 'Cost to deliver the item (if you deliver)',
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
                key: ValueKey('item_images_${_uploadedImages.length}'),
                initialImages: _uploadedImages,
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
                key: ValueKey('service_images_${_uploadedImages.length}'),
                initialImages: _uploadedImages,
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
                key: ValueKey('rental_images_${_uploadedImages.length}'),
                initialImages: _uploadedImages,
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
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
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
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
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
    if (_isLoading) return; // guard against double taps
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For delivery requests, clear registration cache to ensure we have the latest data
      if (widget.request.type == RequestType.delivery) {
        UserRegistrationService.instance.clearCache();
        // Also clear user service cache to get fresh user data
        _userService.clearCache();
      }

      final currentUser = await _userService.getCurrentUserModel();
      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Enforce location required on edit too
      if (_locationAddressController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please provide responder location'),
            backgroundColor: Colors.red,
          ));
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Role-based validation using async method for proper registration checks
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
          price = _parsePriceInput(_offerPriceController.text);
          additionalInfo = {
            'itemCondition': _itemConditionController.text.trim(),
            'offerDescription': _offerDescriptionController.text.trim(),
            'deliveryMethod': _selectedDeliveryMethod,
            'deliveryCost': _deliveryCostController.text.trim().isNotEmpty
                ? _parsePriceInput(_deliveryCostController.text.trim())
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
          price = _parsePriceInput(_selectedPriceType == 'Fixed Price'
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
          price = _parsePriceInput(_rentalPriceController.text.trim());
          additionalInfo = {
            'rentalPeriod': _selectedRentalPeriod,
            'itemCondition': _rentalItemConditionController.text.trim(),
            'itemDescription': _rentalDescriptionController.text.trim(),
            'pickupDeliveryOption': _selectedPickupDeliveryOption,
            'securityDeposit': _securityDepositController.text.trim().isNotEmpty
                ? _parsePriceInput(_securityDepositController.text.trim())
                : null,
            'availableFrom': _availableFrom?.millisecondsSinceEpoch,
            'availableUntil': _availableUntil?.millisecondsSinceEpoch,
            'images': _uploadedImages,
          };
          break;
        case RequestType.delivery:
          price = _parsePriceInput(_deliveryFeeController.text.trim());
          additionalInfo = {
            'vehicleType': _selectedVehicleType,
            'estimatedPickupTime':
                _parseDateToMillis(_estimatedPickupTimeController.text.trim()),
            'estimatedDropoffTime':
                _parseDateToMillis(_estimatedDropoffTimeController.text.trim()),
            'specialInstructions': _specialInstructionsController.text.trim(),
          };
          break;
        case RequestType.ride:
          price = _parsePriceInput(_fareController.text.trim());
          additionalInfo = {
            'vehicleType': _selectedVehicleType,
            'routeDescription': _routeDescriptionController.text.trim(),
            'driverNotes': _driverNotesController.text.trim(),
          };
          break;
        default:
          break;
      }

      // Basic price presence validation for types that require price
      if (widget.request.type != RequestType.price && price == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid numeric price/fare.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Update the response
      await _requestService.updateResponseNamed(
        responseId: widget.response.id,
        requestId: widget.request.id,
        message: _messageController.text.trim(),
        price: price,
        currency: _selectedCurrency,
        availableFrom: _availableFrom,
        availableUntil: _availableUntil,
        images: _uploadedImages,
        additionalInfo: additionalInfo,
        locationAddress: _locationAddressController.text.trim(),
        locationLatitude:
            double.tryParse(_locationLatitudeController.text.trim()),
        locationLongitude:
            double.tryParse(_locationLongitudeController.text.trim()),
      );
      // NOTE: location fields not yet persisted on update route backend; include once implemented
      // Fetch latest version so caller gets fresh metadata/images
      final refreshedResponses =
          await _requestService.getResponsesForRequest(widget.request.id);
      final updated = refreshedResponses.firstWhere(
          (r) => r.id == widget.response.id,
          orElse: () => widget.response);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating response: $e'),
            backgroundColor: Colors.red,
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
