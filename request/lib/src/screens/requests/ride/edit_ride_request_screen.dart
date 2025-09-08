import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/request_model.dart';
import '../../../models/vehicle_type_model.dart';
import '../../../services/enhanced_request_service.dart';
import '../../../services/enhanced_user_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../utils/address_utils.dart';
import '../../../widgets/accurate_location_picker_widget.dart';
import '../../../services/country_service.dart';
import '../../../theme/glass_theme.dart';
import '../../../widgets/glass_page.dart';
import '../../../utils/currency_helper.dart';
// Geolocator removed as my-location overlay is disabled for stability on emulator

class EditRideRequestScreen extends StatefulWidget {
  final RequestModel request;

  const EditRideRequestScreen({
    super.key,
    required this.request,
  });

  @override
  State<EditRideRequestScreen> createState() => _EditRideRequestScreenState();
}

class _EditRideRequestScreenState extends State<EditRideRequestScreen> {
  final EnhancedRequestService _requestService = EnhancedRequestService();
  final EnhancedUserService _userService = EnhancedUserService();
  final VehicleService _vehicleService = VehicleService();

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();

  // Ride-specific fields
  String _selectedVehicleType = 'economy';
  DateTime? _departureTime;
  int _passengerCount = 1;
  bool _scheduleForLater = false;
  bool _allowSharing = true;
  final _specialRequestsController = TextEditingController();
  List<String> _imageUrls = [];

  // Location coordinates
  double? _pickupLat;
  double? _pickupLng;
  double? _destinationLat;
  double? _destinationLng;

  // Google Maps
  GoogleMapController? _mapController;
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612), // Colombo, Sri Lanka
    zoom: 14,
  );
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _shouldShowMap = false; // Delayed map loading flag
  bool _mapFitted = false;
  // my-location overlay disabled; no flag needed

  bool _isLoading = false;

  // Dynamic vehicle types from database
  List<VehicleTypeModel> _vehicleTypes = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    _initializeFromRequest();
    // my-location disabled; skip permission init

    // Delayed map initialization to reduce initial rendering load
    Timer(const Duration(seconds: 2), () {
      // Balanced delay for better UX
      if (mounted) {
        setState(() {
          _shouldShowMap = true;
        });
      }
    });
  }

  // Location permission handling removed; can be reintroduced when enabling my-location overlay

  Future<void> _loadVehicleTypes() async {
    try {
      // Debug: Check country setup
      final countryService = CountryService.instance;
      print('🏁 Loading vehicles for edit...');
      print('   Country Code: ${countryService.countryCode}');
      print('   Country Name: ${countryService.countryName}');

      // Force refresh vehicles to bypass cache
      final vehicles = await _vehicleService.refreshVehicles();
      print('🚗 Loaded ${vehicles.length} vehicles for edit');

      setState(() {
        _vehicleTypes = vehicles.cast<VehicleTypeModel>();
      });
    } catch (e) {
      print('Error loading vehicle types: $e');
    }
  }

  void _initializeFromRequest() {
    _titleController.text = widget.request.title;
    _descriptionController.text = widget.request.description;
    // Clean the pickup location address
    _pickupLocationController.text =
        AddressUtils.cleanAddress(widget.request.location?.address ?? '');
    _budgetController.text = widget.request.budget?.toString() ?? '';
    _imageUrls = List<String>.from(widget.request.images);

    // Set location coordinates
    if (widget.request.location != null) {
      _pickupLat = widget.request.location!.latitude;
      _pickupLng = widget.request.location!.longitude;
    }

    // Handle destination location - clean the address
    if (widget.request.destinationLocation != null) {
      _destinationController.text = AddressUtils.cleanAddress(
          widget.request.destinationLocation!.address);
      _destinationLat = widget.request.destinationLocation!.latitude;
      _destinationLng = widget.request.destinationLocation!.longitude;
    }

    // Parse ride-specific data using RideRequestData model
    try {
      final rideData = RideRequestData.fromMap(widget.request.typeSpecificData);

      _passengerCount = rideData.passengers;
      _departureTime = rideData.preferredTime;
      _allowSharing = rideData.petsAllowed;
      _specialRequestsController.text = rideData.specialRequests ?? '';

      // Map vehicle type to new system
      switch ((rideData.vehicleType ?? '').toLowerCase()) {
        case 'premium':
          _selectedVehicleType = 'premium';
          break;
        case 'shared':
          _selectedVehicleType = 'shared';
          break;
        case 'suv':
          _selectedVehicleType = 'suv';
          break;
        default:
          _selectedVehicleType = 'economy';
      }

      // Check if it's scheduled for later
      final now = DateTime.now();
      final preferredTime = rideData.preferredTime;
      _scheduleForLater = preferredTime.difference(now).inMinutes > 30;
    } catch (e) {
      print('Error parsing ride data: $e');
      // Fallback to default values
      _selectedVehicleType = 'economy';
      _passengerCount = 1;
      _allowSharing = true;
      _scheduleForLater = false;
    }

    // Update map markers after data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMapMarkers();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pickupLocationController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    _specialRequestsController.dispose();
    try {
      _mapController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  /// Get icon from string name
  IconData _getVehicleIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'two_wheeler':
      case 'twowheeler':
        return Icons.two_wheeler;
      case 'local_taxi':
      case 'localtaxi':
        return Icons.local_taxi;
      case 'directions_car':
      case 'directionscar':
        return Icons.directions_car;
      case 'airport_shuttle':
      case 'airportshuttle':
        return Icons.airport_shuttle;
      case 'directions_bus':
      case 'directionsbus':
        return Icons.directions_bus;
      case 'people':
        return Icons.people;
      default:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Edit Ride',
      actions: [
        IconButton(
          icon: Icon(Icons.my_location, color: GlassTheme.colors.textPrimary),
          onPressed: _goToCurrentLocation,
          tooltip: 'My Location',
        ),
      ],
      body: Stack(
        children: [
          // Google Maps View with delayed loading
          Positioned.fill(
            child: _shouldShowMap
                ? GoogleMap(
                    key: const ValueKey('ride-map-edit'),
                    initialCameraPosition: _initialPosition,
                    onMapCreated: (GoogleMapController controller) async {
                      try {
                        _mapController = controller;

                        // Add delay for proper initialization
                        await Future.delayed(const Duration(
                            milliseconds: 2000)); // Increased from 500ms to 2s

                        // If we have coordinates, update the view
                        if (_pickupLat != null &&
                            _pickupLng != null &&
                            !_mapFitted) {
                          _updateMapMarkers();
                        }

                        print('✅ Edit Google Maps initialized successfully');
                      } catch (e) {
                        print('❌ Edit Google Maps initialization error: $e');
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
                    markers: _markers,
                    polylines: _polylines,
                    onTap: _onMapTapped,
                    // Disable my-location overlay to reduce emulator buffer churn
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    // Use Lite Mode to reduce emulator GPU load and avoid buffer churn
                    liteModeEnabled: true,
                    buildingsEnabled: false, // Disable to reduce rendering load
                    indoorViewEnabled: false,
                    compassEnabled: false, // Disable to reduce UI elements
                    trafficEnabled: false,
                    mapType: MapType.normal,
                    // Performance optimizations
                    minMaxZoomPreference: const MinMaxZoomPreference(8.0, 18.0),
                    rotateGesturesEnabled:
                        false, // Disable to reduce complexity
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    zoomGesturesEnabled: true,
                    // Additional performance settings
                    padding: EdgeInsets.zero,
                    cameraTargetBounds: CameraTargetBounds.unbounded,
                    style: null, // Use default style for better performance
                  )
                : Container(
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

          // Bottom Sheet with ride details
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: GlassTheme.glassContainer,
                child: Material(
                  color: Colors.transparent,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Location inputs
                      _buildLocationInputs(),
                      const SizedBox(height: 24),

                      // Vehicle selection
                      _buildVehicleSelection(),
                      const SizedBox(height: 24),

                      // Passengers and scheduling
                      _buildRideOptions(),
                      const SizedBox(height: 24),

                      // Budget input
                      _buildBudgetInput(),
                      const SizedBox(height: 24),

                      // Update ride button
                      _buildUpdateButton(),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Removed unused _buildSectionTitle helper

  Widget _buildLocationInputs() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AccurateLocationPickerWidget(
                        controller: _pickupLocationController,
                        countryCode: CountryService.instance.countryCode,
                        labelText: '',
                        hintText: 'Pickup location',
                        isRequired: true,
                        enableCurrentLocationTap: true,
                        onLocationSelected: (address, lat, lng) {
                          setState(() {
                            _pickupLat = lat;
                            _pickupLng = lng;
                          });
                          _updateMapMarkers();
                          // Show feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pickup location set: $address'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[300]),
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AccurateLocationPickerWidget(
                        controller: _destinationController,
                        countryCode: CountryService.instance.countryCode,
                        labelText: '',
                        hintText: 'Where to?',
                        isRequired: true,
                        onLocationSelected: (address, lat, lng) {
                          setState(() {
                            _destinationLat = lat;
                            _destinationLng = lng;
                          });
                          _updateMapMarkers();
                          // Show feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Destination set: $address'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelection() {
    if (_vehicleTypes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a ride',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : const Center(
                    child: Text(
                      'No vehicles available in your area',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a ride',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _vehicleTypes.length,
            itemBuilder: (context, index) {
              final vehicle = _vehicleTypes[index];
              final isSelected = _selectedVehicleType == vehicle.id;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVehicleType = vehicle.id;
                  });
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? Colors.grey[100] : Colors.transparent,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getVehicleIcon(vehicle.icon),
                            size: 24,
                            color: Colors.grey[800],
                          ),
                          const Spacer(),
                          Text(
                            '${vehicle.passengerCapacity}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          vehicle.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRideOptions() {
    return Column(
      children: [
        // Passenger count
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.grey),
              const SizedBox(width: 12),
              const Text(
                'Passengers',
                style: TextStyle(fontSize: 16),
              ),
              const Spacer(),
              Row(
                children: [
                  IconButton(
                    onPressed: _passengerCount > 1
                        ? () => setState(() => _passengerCount--)
                        : null,
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: _passengerCount > 1
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
                  Text(
                    '$_passengerCount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: _passengerCount < 6
                        ? () => setState(() => _passengerCount++)
                        : null,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: _passengerCount < 6
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Schedule for later
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: ListTile(
            leading: Icon(
              Icons.schedule,
              color: _scheduleForLater
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
            title: Text(_scheduleForLater
                ? (_departureTime != null
                    ? 'Leave at ${_departureTime!.hour}:${_departureTime!.minute.toString().padLeft(2, '0')}'
                    : 'Select time')
                : 'Leave now'),
            trailing: Switch(
              value: _scheduleForLater,
              onChanged: (value) {
                setState(() {
                  _scheduleForLater = value;
                  if (value && _departureTime == null) {
                    _selectDateTime();
                  }
                });
              },
            ),
            onTap: _scheduleForLater ? _selectDateTime : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassContainerSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget (optional)',
            style: GlassTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _budgetController,
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateRequest,
        style: GlassTheme.primaryButton,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Update Ride Request'),
      ),
    );
  }

  Future<BitmapDescriptor> _createCustomMarker(
      IconData icon, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    const double radius = 20.0;

    // Draw circle background
    canvas.drawCircle(const Offset(radius, radius), radius, paint);

    // Draw white circle border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(const Offset(radius, radius), radius, borderPaint);

    // Draw icon
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 20.0,
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));

    // Convert to image
    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
          (radius * 2).toInt(),
          (radius * 2).toInt(),
        );

    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(uint8List);
  }

  void _updateMapMarkers() async {
    // Create custom icons
    final BitmapDescriptor humanIcon =
        await _createCustomMarker(Icons.person, Colors.blue);
    final BitmapDescriptor destinationIcon =
        await _createCustomMarker(Icons.location_on, Colors.red);

    setState(() {
      _markers.clear();
      _polylines.clear();

      // Add pickup marker with human icon
      if (_pickupLat != null && _pickupLng != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(_pickupLat!, _pickupLng!),
            infoWindow: InfoWindow(
              title: 'Pickup',
              snippet: _pickupLocationController.text,
            ),
            icon: humanIcon,
          ),
        );
      }

      // Add destination marker with custom icon
      if (_destinationLat != null && _destinationLng != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(_destinationLat!, _destinationLng!),
            infoWindow: InfoWindow(
              title: 'Drop',
              snippet: _destinationController.text,
            ),
            icon: destinationIcon,
          ),
        );
      }

      // Add route line if both locations are set
      if (_pickupLat != null &&
          _pickupLng != null &&
          _destinationLat != null &&
          _destinationLng != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [
              LatLng(_pickupLat!, _pickupLng!),
              LatLng(_destinationLat!, _destinationLng!),
            ],
            color: const Color(0xFF2196F3),
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
      }
    });

    // Camera movement after setState
    if (_pickupLat != null &&
        _pickupLng != null &&
        _destinationLat != null &&
        _destinationLng != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _fitMarkersOnMap();
      });
    } else if (_pickupLat != null && _pickupLng != null) {
      // If only pickup is set, center on pickup
      Future.delayed(const Duration(milliseconds: 200), () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(_pickupLat!, _pickupLng!), 15),
        );
      });
    } else if (_destinationLat != null && _destinationLng != null) {
      // If only destination is set, center on destination
      Future.delayed(const Duration(milliseconds: 200), () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
              LatLng(_destinationLat!, _destinationLng!), 15),
        );
      });
    }
  }

  void _fitMarkersOnMap() {
    if (_mapController == null || _pickupLat == null || _destinationLat == null)
      return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _pickupLat! < _destinationLat! ? _pickupLat! : _destinationLat!,
        _pickupLng! < _destinationLng! ? _pickupLng! : _destinationLng!,
      ),
      northeast: LatLng(
        _pickupLat! > _destinationLat! ? _pickupLat! : _destinationLat!,
        _pickupLng! > _destinationLng! ? _pickupLng! : _destinationLng!,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
          bounds, 120.0), // More padding for better view
    );
  }

  void _onMapTapped(LatLng position) {
    // For now, just show coordinates - can be enhanced to set pickup/destination
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Tapped: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goToCurrentLocation() {
    // Future: Implement current location functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting current location...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _departureTime ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _departureTime != null
            ? TimeOfDay.fromDateTime(_departureTime!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _departureTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _updateRequest() async {
    // Basic validation
    if (_pickupLocationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter pickup location')),
      );
      return;
    }

    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter destination')),
      );
      return;
    }

    if (_scheduleForLater && _departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select departure time')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user has verified phone number
      final currentUser = await _userService.getCurrentUserModel();
      if (currentUser == null || !currentUser.isPhoneVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Please verify your phone number to update requests'),
            ),
          );
        }
        return;
      }

      // Get selected vehicle details
      final selectedVehicle = _vehicleTypes.firstWhere(
        (vehicle) => vehicle.id == _selectedVehicleType,
      );

      // Create the ride-specific data
      final rideData = RideRequestData(
        passengers: _passengerCount,
        preferredTime: _scheduleForLater
            ? _departureTime!
            : DateTime.now().add(const Duration(minutes: 10)),
        isFlexibleTime: !_scheduleForLater,
        vehicleType: selectedVehicle.name,
        allowSmoking: false,
        petsAllowed: _allowSharing,
        specialRequests: _specialRequestsController.text.trim().isEmpty
            ? null
            : _specialRequestsController.text.trim(),
      );

      // Generate a descriptive title
      final title =
          'Ride from ${_pickupLocationController.text.trim()} to ${_destinationController.text.trim()}';

      final locationInfo = LocationInfo(
        address: _pickupLocationController.text.trim(),
        latitude: _pickupLat ?? widget.request.location?.latitude ?? 0.0,
        longitude: _pickupLng ?? widget.request.location?.longitude ?? 0.0,
      );

      final destinationInfo = LocationInfo(
        address: _destinationController.text.trim(),
        latitude: _destinationLat ??
            widget.request.destinationLocation?.latitude ??
            0.0,
        longitude: _destinationLng ??
            widget.request.destinationLocation?.longitude ??
            0.0,
      );

      await _requestService.updateRequestFlexible(
        requestId: widget.request.id,
        title: title,
        description:
            'Ride request for $_passengerCount passenger(s) using ${selectedVehicle.name}',
        budget: double.tryParse(_budgetController.text),
        location: locationInfo,
        destinationLocation: destinationInfo,
        images: _imageUrls,
        typeSpecificData: rideData.toMap(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: $e'),
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
