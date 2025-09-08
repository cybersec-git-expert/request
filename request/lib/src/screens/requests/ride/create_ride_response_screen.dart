import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../../../models/request_model.dart';
import '../../../models/enhanced_user_model.dart';
import '../../../models/vehicle_type_model.dart';
import '../../../services/centralized_request_service.dart';
import '../../../services/enhanced_user_service.dart';
import '../../../services/country_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../utils/address_utils.dart';
import '../../../theme/glass_theme.dart';
import '../../../widgets/glass_page.dart';

class CreateRideResponseScreen extends StatefulWidget {
  final RequestModel request;
  final ResponseModel? existingResponse;

  const CreateRideResponseScreen({
    super.key,
    required this.request,
    this.existingResponse,
  });

  @override
  State<CreateRideResponseScreen> createState() =>
      _CreateRideResponseScreenState();
}

class _CreateRideResponseScreenState extends State<CreateRideResponseScreen> {
  final _formKey = GlobalKey<FormState>();
  final CentralizedRequestService _requestService = CentralizedRequestService();
  final EnhancedUserService _userService = EnhancedUserService();
  final VehicleService _vehicleService = VehicleService();

  // Google Maps Controller
  GoogleMapController? _mapController;
  bool _shouldShowMap = false; // Delayed map loading flag

  // Form Controllers
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();

  String _vehicleType = '';
  bool _smokingAllowed = false;
  bool _petsAllowed = true;
  DateTime? _departureTime;
  // int _availableSeats = 3; // Not used in this screen
  List<String> _imageUrls = [];

  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _isEditMode = false;
  String? _existingResponseId;

  // Location data
  Position? _currentPosition;
  UserModel? _requesterUser;

  // Map markers
  Set<Marker> _markers = {};

  // Dynamic vehicle types from database
  List<VehicleTypeModel> _vehicleTypes = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    _requestLocationPermission();
    _loadRequesterData();
    _checkExistingResponse();

    // Delayed map initialization to reduce initial rendering load
    Timer(const Duration(seconds: 2), () {
      // Balanced delay: not too long, not too short
      if (mounted) {
        setState(() {
          _shouldShowMap = true;
        });
      }
    });
  }

  Future<void> _loadVehicleTypes() async {
    try {
      // Debug: Check country setup
      final countryService = CountryService.instance;
      print('🏁 Loading vehicles for response...');
      print('   Country Code: ${countryService.countryCode}');
      print('   Country Name: ${countryService.countryName}');

      // Force refresh vehicles to bypass cache
      final vehicles = await _vehicleService.refreshVehicles();
      print('🚗 Loaded ${vehicles.length} vehicles for response');

      setState(() {
        _vehicleTypes = vehicles.cast<VehicleTypeModel>();
        // Set first vehicle as default if available and not already set
        if (vehicles.isNotEmpty && _vehicleType.isEmpty) {
          _vehicleType = vehicles.first.name;
        }
      });
    } catch (e) {
      print('Error loading vehicle types: $e');
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      await _updateMapMarkersAndCamera();
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadRequesterData() async {
    try {
      UserModel? user =
          await _userService.getUserById(widget.request.requesterId);
      setState(() {
        _requesterUser = user;
      });
    } catch (e) {
      print('Error loading requester data: $e');
    }
  }

  Future<void> _checkExistingResponse() async {
    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) return;

      // Use provided existing response or check request responses
      final ResponseModel? existingResponse = widget.existingResponse;
      if (existingResponse == null) return;

      setState(() {
        _isEditMode = true;
        _existingResponseId = existingResponse.id;
        // Load existing response data
        _priceController.text = existingResponse.price?.toString() ?? '';
        _messageController.text = existingResponse.message;
        // Load other fields if they exist in additionalInfo
        if (existingResponse.additionalInfo.isNotEmpty) {
          _vehicleType = existingResponse.additionalInfo['vehicleType'] ??
              (_vehicleTypes.isNotEmpty ? _vehicleTypes.first.name : '');
          _smokingAllowed =
              existingResponse.additionalInfo['smokingAllowed'] ?? false;
          _petsAllowed = existingResponse.additionalInfo['petsAllowed'] ?? true;
          if (existingResponse.additionalInfo['departureTime'] != null) {
            _departureTime = DateTime.tryParse(
                existingResponse.additionalInfo['departureTime']);
          }
        }
      });
    } catch (e) {
      // Stay in create mode
      print('Error checking existing response: $e');
    }
  }

  Future<void> _updateMapMarkersAndCamera() async {
    Set<Marker> newMarkers = {};

    // Add driver location marker (current position)
    if (_currentPosition != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add pickup location marker
    if (widget.request.location != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(widget.request.location!.latitude,
              widget.request.location!.longitude),
          infoWindow: InfoWindow(
              title: 'Pickup Location',
              snippet:
                  AddressUtils.cleanAddress(widget.request.location!.address)),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Add dropoff location marker
    if (widget.request.destinationLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(widget.request.destinationLocation!.latitude,
              widget.request.destinationLocation!.longitude),
          infoWindow: InfoWindow(
              title: 'Drop-off Location',
              snippet: AddressUtils.cleanAddress(
                  widget.request.destinationLocation!.address)),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });

    // Update camera to show all markers
    if (_mapController != null && _markers.isNotEmpty) {
      LatLngBounds bounds = _calculateBounds(_markers);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  LatLngBounds _calculateBounds(Set<Marker> markers) {
    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (Marker marker in markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  double _calculateDistance() {
    if (_currentPosition != null && widget.request.location != null) {
      return Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            widget.request.location!.latitude,
            widget.request.location!.longitude,
          ) /
          1000; // Convert to kilometers
    }
    return 0.0;
  }

  // Removed unused _selectDepartureTime

  Future<void> _submitResponse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to continue')),
        );
        return;
      }

      if (_isEditMode && _existingResponseId != null) {
        // Update existing response
        await _requestService.updateResponse(_existingResponseId!, {
          'message': _messageController.text,
          'price': double.parse(_priceController.text.trim()),
          'images': _imageUrls,
          'additionalInfo': {
            'vehicleType': _vehicleType,
            'passengers': widget.request.typeSpecificData['passengers'] ?? 1,
            'departureTime': _departureTime?.toIso8601String(),
            'smokingAllowed': _smokingAllowed,
            'petsAllowed': _petsAllowed,
          },
        });
      } else {
        // Create new response
        // Get country code from CountryService
        final countryCode = CountryService.instance.getCurrentCountryCode();

        await _requestService.createResponseNamed(
          requestId: widget.request.id,
          message: _messageController.text,
          price: double.parse(_priceController.text.trim()),
          images: _imageUrls,
          countryCode: countryCode,
          additionalData: {
            'vehicleType': _vehicleType,
            'passengers': widget.request.typeSpecificData['passengers'] ?? 1,
            'departureTime': _departureTime?.toIso8601String(),
            'smokingAllowed': _smokingAllowed,
            'petsAllowed': _petsAllowed,
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditMode
                  ? 'Ride offer updated successfully!'
                  : 'Ride offer submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

  // Contact functions
  void _callRequester() async {
    if (_requesterUser?.phoneNumber != null) {
      final Uri url = Uri.parse('tel:${_requesterUser!.phoneNumber}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
    }
  }

  void _messageRequester() async {
    if (_requesterUser?.phoneNumber != null) {
      final Uri url = Uri.parse('sms:${_requesterUser!.phoneNumber}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
    }
  }

  void _showRequesterProfile() {
    // TODO: Implement requester profile modal
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_requesterUser?.name ?? 'Requester Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Email: ${_requesterUser?.email ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Phone: ${_requesterUser?.phoneNumber ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: _isEditMode ? 'Edit Ride Offer' : 'Ride Offer',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Map Section
            Container(
              height: 250,
              decoration: GlassTheme.glassContainer,
              child: _isLoadingLocation
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Getting your location...'),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: _shouldShowMap
                          ? GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _currentPosition != null
                                    ? LatLng(_currentPosition!.latitude,
                                        _currentPosition!.longitude)
                                    : const LatLng(
                                        3.1390, 101.6869), // KL as default
                                zoom: 14,
                              ),
                              markers: _markers,
                              onMapCreated:
                                  (GoogleMapController controller) async {
                                try {
                                  _mapController = controller;

                                  // Add moderate delay to ensure the map is properly initialized
                                  await Future.delayed(const Duration(
                                      milliseconds:
                                          1000)); // Reduced from 2s to 1s

                                  if (_markers.isNotEmpty) {
                                    await _updateMapMarkersAndCamera();
                                  }

                                  print(
                                      '✅ Response Google Maps initialized successfully');
                                } catch (e) {
                                  print(
                                      '❌ Response Google Maps initialization error: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Map failed to load. Please check your internet connection.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                }
                              },
                              myLocationEnabled:
                                  true, // Re-enable for functionality
                              myLocationButtonEnabled:
                                  false, // Keep disabled for performance
                              // Critical fixes for frame rendering issues - DISABLE LITE MODE
                              liteModeEnabled:
                                  false, // Use interactive map but optimized
                              buildingsEnabled:
                                  false, // Disable to reduce rendering load
                              indoorViewEnabled: false,
                              compassEnabled:
                                  false, // Disable to reduce UI elements
                              trafficEnabled: false,
                              mapType: MapType.normal,
                              // Performance optimizations
                              minMaxZoomPreference:
                                  const MinMaxZoomPreference(8.0, 18.0),
                              rotateGesturesEnabled:
                                  false, // Disable to reduce complexity
                              scrollGesturesEnabled: true,
                              tiltGesturesEnabled: false,
                              zoomGesturesEnabled: true,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              // Additional performance settings
                              padding: EdgeInsets.zero,
                              cameraTargetBounds: CameraTargetBounds.unbounded,
                              style:
                                  null, // Use default style for better performance
                            )
                          : Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading Map...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
            ),
            const SizedBox(height: 20),

            // Location Cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GlassTheme.glassContainerSubtle,
              child: Column(
                children: [
                  // Pickup Location
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pickup Location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AddressUtils.cleanAddress(
                                  widget.request.location?.address ??
                                      'Location not specified'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Dropoff Location
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Drop-off Location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AddressUtils.cleanAddress(
                                  widget.request.destinationLocation?.address ??
                                      'Location not specified'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 20),

            // Passengers and Price
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GlassTheme.glassContainerSubtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trip Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Passengers Requested',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5F5F5),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Text(
                                '${widget.request.typeSpecificData['passengers'] ?? 1} passenger${(widget.request.typeSpecificData['passengers'] ?? 1) > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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
                            const Text(
                              'Distance from You',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5F5F5),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Text(
                                '${_calculateDistance().toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ride Fare',
                      hintText: 'Enter total ride fare',
                      prefixText: 'RM ',
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Requester Contact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GlassTheme.glassContainerSubtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Requester',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showRequesterProfile,
                        child: const CircleAvatar(
                          radius: 25,
                          child: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _requesterUser?.name ?? 'Loading...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _requesterUser?.email ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _callRequester,
                        icon: const Icon(Icons.call, color: Colors.green),
                        tooltip: 'Call',
                      ),
                      IconButton(
                        onPressed: _messageRequester,
                        icon: const Icon(Icons.message, color: Colors.blue),
                        tooltip: 'Message',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitResponse,
                style: GlassTheme.primaryButton,
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Submitting...'),
                        ],
                      )
                    : Text(
                        _isEditMode ? 'Update Ride Offer' : 'Submit Ride Offer',
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
