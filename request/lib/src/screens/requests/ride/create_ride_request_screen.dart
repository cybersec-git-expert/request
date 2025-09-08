import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/rest_vehicle_type_service.dart';
import '../../../services/country_filtered_data_service.dart';
import '../../../services/rest_ride_request_service.dart';
import '../../../services/rest_auth_service.dart';
import '../../../utils/address_utils.dart';
import '../../../widgets/accurate_location_picker_widget.dart';
import '../../../services/country_service.dart';
import '../../../utils/currency_helper.dart';
import '../../../utils/distance_calculator.dart';
import '../../../services/google_directions_service.dart';
import '../../../theme/glass_theme.dart';
import '../../../widgets/glass_page.dart';

class CreateRideRequestScreen extends StatefulWidget {
  const CreateRideRequestScreen({super.key});

  @override
  State<CreateRideRequestScreen> createState() =>
      _CreateRideRequestScreenState();
}

class _CreateRideRequestScreenState extends State<CreateRideRequestScreen> {
  bool _mapFitted = false; // avoid repeated camera fitting
  // final _formKey = GlobalKey<FormState>(); // Removed unused form key (UI fully custom)

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();

  // Ride-specific fields
  String _selectedVehicleType = '';
  DateTime? _departureTime;
  int _passengerCount = 1;
  bool _scheduleForLater = false;
  final _specialRequestsController = TextEditingController();

  // Location coordinates and distance
  double? _pickupLat;
  double? _pickupLng;
  double? _destinationLat;
  double? _destinationLng;
  double? _distance; // Distance in kilometers
  String? _estimatedTime;

  // Google Maps
  GoogleMapController? _mapController;
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612), // Colombo, Sri Lanka
    zoom: 14,
  );
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _isLoading = false;
  bool _mapReady = false;
  bool _mapInitTimedOut = false;
  bool _shouldShowMap = false; // Add flag to control map visibility

  // Dynamic vehicle types from database
  List<VehicleType> _vehicleTypes = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    // my-location overlay disabled to reduce emulator buffer churn

    // Delay map loading to improve initial screen performance
    Timer(const Duration(milliseconds: 2000), () {
      // Balanced delay for better UX
      if (mounted) {
        setState(() {
          _shouldShowMap = true;
        });
      }
    });

    // If the Google Map doesn't call onMapCreated within 6s, show a hint
    Timer(const Duration(seconds: 6), () {
      if (mounted && !_mapReady) {
        setState(() {
          _mapInitTimedOut = true;
        });
      }
    });
  }

  Future<void> _loadVehicleTypes() async {
    setState(() => _isLoading = true);

    try {
      // Get available vehicle types (country enabled + has registered drivers)
      final availableTypes =
          await CountryFilteredDataService.instance.getAvailableVehicleTypes();

      // Convert to VehicleType objects
      final vehicles = availableTypes
          .map((vt) => VehicleType(
                id: vt['id']?.toString() ?? '',
                name: vt['name']?.toString() ?? '',
                description: vt['description']?.toString(),
                iconUrl: vt['icon']?.toString(),
                passengerCapacity: int.tryParse(
                    (vt['passengerCapacity'] ?? vt['capacity'] ?? '1')
                        .toString()),
                isActive: vt['isActive'] == true,
                countryEnabled:
                    true, // These are already filtered to be country enabled
                createdAt: DateTime.now(), // Placeholder
                updatedAt: DateTime.now(), // Placeholder
              ))
          .toList();

      setState(() {
        _vehicleTypes = vehicles;
        if (_vehicleTypes.isNotEmpty && _selectedVehicleType.isEmpty) {
          _selectedVehicleType = _vehicleTypes.first.id;
        }
        _isLoading = false;
      });

      if (_vehicleTypes.isEmpty) {
        // Show a message that no vehicles are available in this country
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No vehicles available in your area. Please try again later.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load available vehicles'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _calculateDistance() async {
    if (_pickupLat != null &&
        _pickupLng != null &&
        _destinationLat != null &&
        _destinationLng != null) {
      // Always calculate fallback distance first
      final fallbackDistance = DistanceCalculator.calculateDistance(
        startLat: _pickupLat!,
        startLng: _pickupLng!,
        endLat: _destinationLat!,
        endLng: _destinationLng!,
      );

      final fallbackTime = DistanceCalculator.estimateTravelTime(
        fallbackDistance,
        vehicleType: _selectedVehicleType,
      );

      // Set fallback values first
      _distance = fallbackDistance;
      _estimatedTime = fallbackTime;

      setState(() {});

      // Try to get better estimates from Google API in the background
      try {
        Map<String, dynamic> routeInfo =
            await GoogleDirectionsService.getRouteInfo(
          origin: LatLng(_pickupLat!, _pickupLng!),
          destination: LatLng(_destinationLat!, _destinationLng!),
          travelMode: 'driving',
        );

        if (routeInfo.isNotEmpty) {
          // Update with API data
          _distance = (routeInfo['distance'] / 1000.0);
          _estimatedTime = routeInfo['durationText'];

          setState(() {});
        }
      } catch (e) {
        print('Google Directions API error: $e');
        // Keep fallback values
      }

      // Update map with route
      _updateMapWithRoute();
    }
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

  void _updateMapWithRoute() async {
    if (_pickupLat != null &&
        _pickupLng != null &&
        _destinationLat != null &&
        _destinationLng != null) {
      // Create custom human icon for pickup
      final BitmapDescriptor humanIcon =
          await _createCustomMarker(Icons.person, Colors.blue);
      final BitmapDescriptor destinationIcon =
          await _createCustomMarker(Icons.location_on, Colors.red);

      // Add markers with human icon for pickup
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickupLat!, _pickupLng!),
          infoWindow: InfoWindow(
              title: 'Pickup',
              snippet:
                  AddressUtils.cleanAddress(_pickupLocationController.text)),
          icon: humanIcon,
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_destinationLat!, _destinationLng!),
          infoWindow: InfoWindow(
              title: 'Destination',
              snippet: AddressUtils.cleanAddress(_destinationController.text)),
          icon: destinationIcon,
        ),
      };

      try {
        // Get route points from Google Directions API
        List<LatLng> routePoints = await GoogleDirectionsService.getDirections(
          origin: LatLng(_pickupLat!, _pickupLng!),
          destination: LatLng(_destinationLat!, _destinationLng!),
          travelMode: _selectedVehicleType == 'bike' ? 'driving' : 'driving',
        );

        if (routePoints.isNotEmpty) {
          // Add polyline with actual route
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: Colors.blue,
              width: 4,
              patterns: [],
            ),
          };
        } else {
          // Fallback to straight line if directions API fails
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [
                LatLng(_pickupLat!, _pickupLng!),
                LatLng(_destinationLat!, _destinationLng!),
              ],
              color: Colors.blue,
              width: 3,
            ),
          };
        }
      } catch (e) {
        print('Error getting directions: $e');
        // Fallback to straight line
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [
              LatLng(_pickupLat!, _pickupLng!),
              LatLng(_destinationLat!, _destinationLng!),
            ],
            color: Colors.blue,
            width: 3,
          ),
        };
      }

      // Adjust camera to show both points only once
      if (_mapController != null && !_mapFitted) {
        double minLat =
            _pickupLat! < _destinationLat! ? _pickupLat! : _destinationLat!;
        double maxLat =
            _pickupLat! > _destinationLat! ? _pickupLat! : _destinationLat!;
        double minLng =
            _pickupLng! < _destinationLng! ? _pickupLng! : _destinationLng!;
        double maxLng =
            _pickupLng! > _destinationLng! ? _pickupLng! : _destinationLng!;

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            100.0, // padding
          ),
        );
        _mapFitted = true;
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Book a Ride',
      actions: [
        IconButton(
          icon: Icon(Icons.my_location, color: GlassTheme.colors.textPrimary),
          tooltip: 'My Location',
          onPressed: _goToCurrentLocation,
        ),
      ],
      body: Stack(
        children: [
          // Google Maps View with delayed loading
          Positioned.fill(
            child: _shouldShowMap
                ? GoogleMap(
                    key: const ValueKey('ride-map-create'),
                    initialCameraPosition: _initialPosition,
                    onMapCreated: (GoogleMapController controller) async {
                      try {
                        _mapController = controller;

                        // Add a longer delay to ensure the map is properly initialized
                        await Future.delayed(const Duration(
                            milliseconds: 2000)); // Increased from 500ms to 2s

                        if (mounted) {
                          setState(() => _mapReady = true);
                        }

                        print('✅ Google Maps initialized successfully');
                      } catch (e) {
                        print('❌ Google Maps initialization error: $e');
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
                    myLocationEnabled:
                        false, // disable to reduce emulator buffer churn
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

          // Helpful overlay if map failed to initialize (likely missing API key)
          if (_mapInitTimedOut && !_mapReady)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Map not available. For Android emulator, ensure:\n'
                  '• A valid MAPS_API_KEY is set in android/key.properties or env\n'
                  '• Emulator image includes Google Play services',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

          // Bottom Sheet with ride details (Glass style)
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
                      const SizedBox(height: 16),

                      // Distance information card
                      if (_distance != null) _buildDistanceCard(),
                      if (_distance != null) const SizedBox(height: 16),

                      // Vehicle selection
                      _buildVehicleSelection(),
                      const SizedBox(height: 24),

                      // Passengers and scheduling
                      _buildRideOptions(),
                      const SizedBox(height: 24),

                      // Request ride button
                      _buildRequestButton(),
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

  // Removed unused _buildSectionTitle helper (design simplified)

  Widget _buildLocationInputs() {
    return Column(
      children: [
        // Pickup location
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
                  prefixIcon: Icons.my_location,
                  enableCurrentLocationTap: true,
                  onLocationSelected: (address, lat, lng) {
                    setState(() {
                      _pickupLat = lat;
                      _pickupLng = lng;
                    });
                    _calculateDistance();
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
        const SizedBox(height: 8),
        // Destination location
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
                  prefixIcon: Icons.location_on,
                  onLocationSelected: (address, lat, lng) {
                    setState(() {
                      _destinationLat = lat;
                      _destinationLng = lng;
                    });
                    _calculateDistance(); // Add this line
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
    );
  }

  Widget _buildDistanceCard() {
    if (_distance == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassContainerSubtle,
      child: Row(
        children: [
          Icon(Icons.route, color: GlassTheme.colors.infoColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Distance: ${DistanceCalculator.formatDistance(_distance!)}',
                  style: GlassTheme.titleSmall,
                ),
                if (_estimatedTime != null)
                  Text(
                    'Estimated time: $_estimatedTime',
                    style: GlassTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
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
                  // Recalculate estimated time for new vehicle type
                  if (_distance != null) {
                    _estimatedTime = DistanceCalculator.estimateTravelTime(
                      _distance!,
                      vehicleType: _selectedVehicleType,
                    );
                    setState(() {});
                  }
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: isSelected
                      ? GlassTheme.glassContainerSubtle
                      : BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getVehicleIcon(
                                vehicle.iconUrl ?? 'directions_car'),
                            size: 24,
                            color: GlassTheme.colors.textPrimary,
                          ),
                          const Spacer(),
                          Text(
                            '${vehicle.passengerCapacity ?? 1}',
                            style: GlassTheme.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          vehicle.name,
                          style: GlassTheme.titleSmall,
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
          decoration: GlassTheme.glassContainerSubtle,
          child: Row(
            children: [
              Icon(Icons.person, color: GlassTheme.colors.textSecondary),
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
                          ? GlassTheme.colors.primaryBlue
                          : Colors.grey,
                    ),
                  ),
                  Text(
                    '$_passengerCount',
                    style: GlassTheme.titleSmall,
                  ),
                  IconButton(
                    onPressed: _passengerCount < 6
                        ? () => setState(() => _passengerCount++)
                        : null,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: _passengerCount < 6
                          ? GlassTheme.colors.primaryBlue
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
          decoration: GlassTheme.glassContainerSubtle,
          child: ListTile(
            leading: Icon(
              Icons.schedule,
              color: _scheduleForLater
                  ? GlassTheme.colors.primaryBlue
                  : GlassTheme.colors.textSecondary,
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

  Widget _buildRequestButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRequest,
        style: GlassTheme.primaryButton,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Request Ride'),
      ),
    );
  }

  // Removed unused _updateMapMarkers (replaced by _updateMapWithRoute logic)

  // Removed unused _fitMarkersOnMap helper

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
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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

  Future<void> _submitRequest() async {
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
      final currentUser = RestAuthService.instance.currentUser;
      if (currentUser == null || !currentUser.phoneVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Please verify your phone number to create requests'),
            ),
          );
        }
        return;
      }

      // Get selected vehicle details
      final selectedVehicle = _vehicleTypes.firstWhere(
          (v) => v.id == _selectedVehicleType,
          orElse: () => _vehicleTypes.first);

      // Create the ride-specific data
      await RestRideRequestService.instance.createRideRequest(
        pickupAddress: _pickupLocationController.text.trim(),
        pickupLat: _pickupLat ?? 0,
        pickupLng: _pickupLng ?? 0,
        destinationAddress: _destinationController.text.trim(),
        destinationLat: _destinationLat ?? 0,
        destinationLng: _destinationLng ?? 0,
        vehicleTypeId: selectedVehicle.id,
        passengers: _passengerCount,
        scheduledTime: _scheduleForLater ? _departureTime : null,
        budget: double.tryParse(_budgetController.text),
        currency: CurrencyHelper.instance.getCurrency(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating request: $e'),
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
