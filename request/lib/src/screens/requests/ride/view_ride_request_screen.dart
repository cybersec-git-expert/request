import 'package:flutter/material.dart';
import 'dart:async';
import '../../../theme/glass_theme.dart';
import '../../../widgets/glass_page.dart';
import '../../../services/rest_auth_service.dart' hide UserModel;
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Removed unused firebase_shim import after migration
// REMOVED_FB_IMPORT: import 'package:cloud_firestore/cloud_firestore.dart';
// REMOVED_FB_IMPORT: import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:geocoding/geocoding.dart'; // unused after removing current-location lookup
import 'dart:math' as math;
import '../../../models/request_model.dart';
import '../../../models/enhanced_user_model.dart';
import '../../../services/enhanced_request_service.dart';
import '../../../services/enhanced_user_service.dart';
import '../../../services/country_service.dart';
import '../../../utils/address_utils.dart';
import 'edit_ride_request_screen.dart';
import '../../../services/rest_vehicle_type_service.dart';
import '../../../services/chat_service.dart';
import '../../chat/conversation_screen.dart';
import '../../../services/user_registration_service.dart';
import '../../../services/google_directions_service.dart';
import '../../../services/rest_request_service.dart' as rest;
import '../../../utils/currency_helper.dart';
import '../../membership/quick_upgrade_sheet.dart';
import '../../../services/entitlements_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewRideRequestScreen extends StatefulWidget {
  final String requestId;

  const ViewRideRequestScreen({super.key, required this.requestId});

  @override
  State<ViewRideRequestScreen> createState() => _ViewRideRequestScreenState();
}

class _ViewRideRequestScreenState extends State<ViewRideRequestScreen> {
  final EnhancedRequestService _requestService = EnhancedRequestService();
  final EnhancedUserService _userService = EnhancedUserService();

  RequestModel? _request;
  List<ResponseModel> _responses = [];
  bool _isLoading = true;
  bool _isOwner = false;
  UserModel? _requesterUser;
  String? _vehicleTypeName; // Resolved human-readable vehicle type name
  bool _isApprovedDriver = false; // From driver_verifications table

  // Map related
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _shouldShowMap = false; // Delayed map loading flag
  bool _mapFitted = false; // Ensure we don't refit camera repeatedly

  // Quick respond (inline fare)
  final TextEditingController _fareController = TextEditingController();
  bool _isSubmittingResponse = false;
  String? _fareError;
  bool _membershipCompleted = false;
  EntitlementsSummary? _entitlements;

  @override
  void initState() {
    super.initState();
    _loadGateState();
    _loadRequestData();
    // my-location overlay disabled to reduce emulator buffer churn

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

  // Removed permission initialization since my-location layer is disabled

  Future<void> _loadGateState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('membership_completed') ?? false;
      final ent = await EntitlementsService.getEntitlementsSummary();
      if (mounted) {
        setState(() {
          _membershipCompleted = completed;
          _entitlements = ent;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fareController.dispose();
    try {
      _mapController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadRequestData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check Auth state first
      final firebaseUser = RestAuthService.instance.currentUser;

      final request = await _requestService.getRequestById(widget.requestId);
      final responses =
          await _requestService.getResponsesForRequest(widget.requestId);
      final currentUser = await _userService.getCurrentUserModel();

      // Fetch driver registration status for current user
      bool isApprovedDriver = false;
      try {
        final regs =
            await UserRegistrationService.instance.getUserRegistrations();
        isApprovedDriver = regs?.isApprovedDriver == true;
      } catch (_) {}

      if (request != null) {
        final requesterUser =
            await _userService.getUserById(request.requesterId);

        // Owner check
        bool isOwner = false;
        String currentUserId = '';

        if (firebaseUser?.uid != null) {
          currentUserId = firebaseUser!.uid;
        }
        if (currentUserId.isEmpty && currentUser?.id != null) {
          currentUserId = currentUser!.id;
        }
        if (currentUserId.isNotEmpty && request.requesterId.isNotEmpty) {
          isOwner = currentUserId == request.requesterId;
        } else {
          isOwner = false; // default to allow responding
        }

        if (mounted) {
          setState(() {
            _request = request;
            _responses = responses.cast<ResponseModel>();
            _isOwner = isOwner;
            _requesterUser = requesterUser;
            _isApprovedDriver = isApprovedDriver;
            _isLoading = false;
          });

          _setupMapMarkers();
          _resolveVehicleTypeName();
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ride request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resolveVehicleTypeName() async {
    try {
      final rideData = _request?.rideData;
      if (rideData == null) return;

      // Prefer explicit metadata id if present
      final meta = _request?.typeSpecificData ?? const {};
      final String? vehicleTypeId =
          (meta['vehicle_type_id']?.toString().isNotEmpty == true)
              ? meta['vehicle_type_id'].toString()
              : null;

      String? value = rideData.vehicleType;

      // If looks like a UUID or an explicit id is provided, resolve via API
      final String? idToResolve = vehicleTypeId ??
          ((value != null && value.contains('-') && value.length >= 8)
              ? value
              : null);

      if (idToResolve != null) {
        final vt = await RestVehicleTypeService.instance
            .getVehicleTypeById(idToResolve);
        if (mounted) {
          setState(() {
            _vehicleTypeName = vt?.name ?? value; // fallback to original
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _vehicleTypeName = value;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vehicleTypeName = _request?.rideData?.vehicleType;
        });
      }
    }
  }

  // Role-based validation methods
  bool _canUserRespond() {
    if (_request == null) return false;
    if (_isOwner) return false;
    // Membership + entitlements gating
    if (!_membershipCompleted) return false;
    if (!(_entitlements?.canRespond ?? false)) return false;
    // Only approved drivers (driver_verifications.status == approved)
    return _isApprovedDriver;
  }

  bool _hasUserResponded() {
    final currentUser = RestAuthService.instance.currentUser;
    if (currentUser == null) return false;
    return _responses
        .any((response) => response.responderId == currentUser.uid);
  }

  // Removed cheapest fare computation per requirement
  // double? _getCheapestFare() { ... }

  Widget _buildResponsesSection() {
    // Removed cheapest label; currency symbol not needed here

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2EE), // soft pink card
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Responses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadRequestData,
                icon: const Icon(Icons.refresh, color: Colors.black87),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Total ${_responses.length}',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Removed cheapest badge per requirement
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToEditRideRequest() {
    if (_request == null) return;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => EditRideRequestScreen(request: _request!),
          ),
        )
        .then((_) => _loadRequestData()); // Reload data when coming back
  }

  void _setupMapMarkers() {
    if (_request == null) return;

    setState(() {
      _markers.clear();
      _polylines.clear();
      // Add pickup marker if available
      if (_request!.location != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(
                _request!.location!.latitude, _request!.location!.longitude),
            infoWindow: InfoWindow(
              title: 'Pickup Location',
              snippet: AddressUtils.cleanAddress(_request!.location!.address),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ),
        );
      }

      // Add destination marker if available
      if (_request!.destinationLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(
              _request!.destinationLocation!.latitude,
              _request!.destinationLocation!.longitude,
            ),
            infoWindow: InfoWindow(
              title: 'Destination',
              snippet: AddressUtils.cleanAddress(
                  _request!.destinationLocation!.address),
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
        // Add route line when both ends exist
        // Draw navigation route asynchronously using Google Directions API
        if (_request!.location != null) {
          _drawNavigationRoute();
        }
      }
    });

    // Fit markers on map after setting them up
    if (_mapController != null && !_mapFitted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _fitMarkersOnMap();
      });
    }
  }

  Future<void> _drawNavigationRoute() async {
    try {
      final origin = LatLng(
        _request!.location!.latitude,
        _request!.location!.longitude,
      );
      final destination = LatLng(
        _request!.destinationLocation!.latitude,
        _request!.destinationLocation!.longitude,
      );

      final points = await GoogleDirectionsService.getDirections(
        origin: origin,
        destination: destination,
        travelMode: 'driving',
      );

      if (!mounted) return;

      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'route');
        if (points.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFF2196F3),
              width: 5,
            ),
          );
        }
      });

      // Optionally refit camera to include the whole route
      if (_mapController != null && points.length > 1) {
        final bounds = _calculateBounds(points);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60.0),
        );
      }
    } catch (e) {
      // Non-fatal: keep map usable even if directions fail
      // print('Failed to draw navigation route: $e');
    }
  }

  void _fitMarkersOnMap() async {
    if (_mapController == null || _markers.isEmpty) return;

    if (_markers.length == 1) {
      // Center on single marker
      final marker = _markers.first;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(marker.position, 15),
      );
    } else if (_markers.length > 1) {
      // Fit all markers
      final positions = _markers.map((m) => m.position).toList();
      final bounds = _calculateBounds(positions);

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
    _mapFitted = true;
  }

  LatLngBounds _calculateBounds(List<LatLng> positions) {
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      minLat = minLat < pos.latitude ? minLat : pos.latitude;
      maxLat = maxLat > pos.latitude ? maxLat : pos.latitude;
      minLng = minLng < pos.longitude ? minLng : pos.longitude;
      maxLng = maxLng > pos.longitude ? maxLng : pos.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassTheme.backgroundContainer(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_request == null) {
      return GlassPage(
        title: 'Ride Request',
        body: const Center(
          child: Text('Ride request not found or has been removed.'),
        ),
      );
    }

    return GlassTheme.backgroundContainer(
      child: Stack(
        children: [
          // Map View with delayed loading and performance optimizations
          _shouldShowMap
              ? GoogleMap(
                  key: const ValueKey('ride-map-view'),
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(6.9271, 79.8612), // Colombo, Sri Lanka
                    zoom: 14,
                  ),
                  onMapCreated: (GoogleMapController controller) async {
                    try {
                      _mapController = controller;

                      // Add a small delay to ensure the map is properly initialized
                      await Future.delayed(const Duration(
                          milliseconds: 2000)); // Increased from 500ms to 2s

                      // Use existing map setup methods
                      if (_markers.isNotEmpty && !_mapFitted) {
                        _fitMarkersOnMap();
                      } else if (_request?.location != null) {
                        _setupMapMarkers();
                      }

                      print('✅ View Google Maps initialized successfully');
                    } catch (e) {
                      print('❌ View Google Maps initialization error: $e');
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
                  // Disable my-location overlay to avoid emulator buffer churn
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
                  rotateGesturesEnabled: false, // Disable to reduce complexity
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

          // Top App Bar - Clean design without shadows
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: GlassTheme.glassContainer,
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back,
                            color: GlassTheme.colors.textPrimary),
                      ),
                      Expanded(
                        child: Text(
                          _buildAppBarTitle(),
                          style: GlassTheme.titleSmall,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isOwner) ...[
                        IconButton(
                          onPressed: _navigateToEditRideRequest,
                          icon: Icon(Icons.edit,
                              color: GlassTheme.colors.textPrimary),
                          tooltip: 'Edit Request',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Sheet - Clean design without shadows
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: GlassTheme.glassContainer,
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: GlassTheme.colors.glassBorderSubtle,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        _buildRideDetails(),
                        const SizedBox(height: 24),
                        _buildRequesterInfo(),
                        const SizedBox(height: 24),
                        _buildResponsesSection(),

                        // Respond Area for non-owners (single entry point)
                        if (!_isOwner) ...[
                          const SizedBox(height: 24),
                          if (_canUserRespond())
                            _buildQuickRespondSection()
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Upgrade to respond',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text(
                                      'Complete membership and upgrade to respond and view contact details.'),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await QuickUpgradeSheet.show(
                                            context, 'driver');
                                        await _loadGateState();
                                      },
                                      child: const Text('See Plans'),
                                    ),
                                  )
                                ],
                              ),
                            ),
                        ],

                        const SizedBox(height: 80), // Space for FAB
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRideDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Title with Route Information
        _buildRouteTitle(),
        const SizedBox(height: 24),

        // Location Details with Enhanced Design
        _buildLocationInfo(),

        const SizedBox(height: 20),

        // Distance and Route Info
        if (_request!.location != null &&
            _request!.destinationLocation != null) ...[
          _buildDistanceInfo(),
          const SizedBox(height: 20),
        ],

        // Enhanced Ride Details Section
        _buildRideDetailsSection(),

        const SizedBox(height: 16),

        // Status and Date
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(_request!.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _request!.status.name.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(_request!.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Posted ${_formatDate(_request!.createdAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openGoogleMaps(
      double latitude, double longitude, String address) async {
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final googleMapsAppUrl =
        'geo:$latitude,$longitude?q=$latitude,$longitude($address)';

    try {
      // Try to open Google Maps app first
      if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
        await launchUrl(Uri.parse(googleMapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        // Fallback to web version
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  Widget _buildRouteTitle() {
    final pickupAddress =
        _request!.location?.address ?? 'Pickup location not specified';
    final dropoffAddress =
        _request!.destinationLocation?.address ?? 'Destination not specified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ride Request',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ride from ${AddressUtils.cleanAddress(pickupAddress)} to ${AddressUtils.cleanAddress(dropoffAddress)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildRideDetailsSection() {
    final rideData = _request!.rideData;

    return Column(
      children: [
        // Passengers, Vehicle Type, and Timing - Row Layout like in your screenshot
        Row(
          children: [
            // Passengers
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${rideData?.passengers ?? 1} passenger(s)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Vehicle Type Row
        if (rideData?.vehicleType != null)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car,
                          size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _vehicleTypeName ?? rideData!.vehicleType!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        if (rideData?.vehicleType != null) const SizedBox(height: 12),

        // Timing Row
        if (rideData != null)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rideData.isFlexibleTime
                              ? 'Flexible timing'
                              : 'Scheduled timing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Column(
      children: [
        if (_request!.location != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Green dot for pickup
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AddressUtils.cleanAddress(_request!.location!.address),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Navigation arrow
                InkWell(
                  onTap: () {
                    _openGoogleMaps(
                      _request!.location!.latitude,
                      _request!.location!.longitude,
                      _request!.location!.address,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.navigation,
                        color: Colors.grey[600], size: 20),
                  ),
                ),
              ],
            ),
          ),
        if (_request!.destinationLocation != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Red dot for destination
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AddressUtils.cleanAddress(
                            _request!.destinationLocation!.address),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Navigation arrow
                InkWell(
                  onTap: () {
                    _openGoogleMaps(
                      _request!.destinationLocation!.latitude,
                      _request!.destinationLocation!.longitude,
                      _request!.destinationLocation!.address,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.navigation,
                        color: Colors.grey[600], size: 20),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDistanceInfo() {
    if (_request!.location == null || _request!.destinationLocation == null) {
      return const SizedBox.shrink();
    }

    final distance = _calculateDistance(
      _request!.location!.latitude,
      _request!.location!.longitude,
      _request!.destinationLocation!.latitude,
      _request!.destinationLocation!.longitude,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.straighten, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Text(
            '${distance.toStringAsFixed(1)} km distance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double radiusOfEarth = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.asin(math.sqrt(a));

    return radiusOfEarth * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Widget _buildRequesterInfo() {
    // Fallback name/phone from request metadata if user lookup missing
    final meta = _request?.typeSpecificData ?? {};
    // Common backend variations
    final fallbackName = (meta['requester_name'] ??
            meta['requester_display_name'] ??
            meta['user_display_name'] ??
            meta['user_name'] ??
            meta['display_name'] ??
            meta['name'] ??
            '')
        .toString()
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Requester Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[100],
              child: Text(
                _requesterUser?.name.isNotEmpty == true
                    ? _requesterUser!.name[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ((_requesterUser?.name ?? '').trim().isNotEmpty)
                        ? _requesterUser!.name
                        : (fallbackName.isNotEmpty
                            ? fallbackName
                            : 'Anonymous User'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Intentionally hide raw phone number text; use call icon instead
                  if (_requesterUser?.isPhoneVerified == true)
                    Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Phone Verified',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (!_isOwner) // Hide contact options from requester/owner
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      if (!_membershipCompleted ||
                          !(_entitlements?.canSeeContactDetails ?? false)) {
                        await QuickUpgradeSheet.show(context, 'driver');
                        await _loadGateState();
                        return;
                      }
                      // Prefer requester's user phone, fallback to metadata phone
                      final meta = _request?.typeSpecificData ?? {};
                      final fallbackPhone =
                          (meta['requester_phone'] ?? meta['user_phone'] ?? '')
                              .toString()
                              .trim();
                      final phone =
                          (_requesterUser?.phoneNumber?.isNotEmpty ?? false)
                              ? _requesterUser!.phoneNumber!
                              : fallbackPhone;
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No phone number available')),
                        );
                        return;
                      }
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Cannot start phone call on this device')),
                        );
                      }
                    },
                    icon: const Icon(Icons.phone, color: Colors.green),
                    tooltip: 'Call',
                  ),
                  IconButton(
                    onPressed: () async {
                      // In-app chat via ChatService (same as UnifiedRequestViewScreen)
                      final request = _request;
                      if (request == null) return;
                      final currentUserId =
                          RestAuthService.instance.currentUser?.uid;
                      if (currentUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('You must be logged in to chat')),
                        );
                        return;
                      }
                      if (currentUserId == request.requesterId) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'This is your own request. You cannot message yourself.')),
                        );
                        return;
                      }
                      try {
                        final (convo, messages) =
                            await ChatService.instance.openConversation(
                          requestId: request.id,
                          currentUserId: currentUserId,
                          otherUserId: request.requesterId,
                        );
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              conversation: convo,
                              initialMessages: messages,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to open chat: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.message, color: Colors.blue),
                    tooltip: 'Message',
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // Removed duplicate _buildResponsesSection (retaining the earlier version defined above)

  // _showEditResponseSheet removed (Glass refactor)

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return Colors.grey;
      case RequestStatus.active:
        return Colors.orange;
      case RequestStatus.open:
        return Colors.green;
      case RequestStatus.inProgress:
        return Colors.orange;
      case RequestStatus.completed:
        return Colors.blue;
      case RequestStatus.cancelled:
        return Colors.red;
      case RequestStatus.expired:
        return Colors.brown;
    }
  }

  Widget _buildQuickRespondSection() {
    final currencySymbol = CurrencyHelper.instance.getCurrencySymbol();
    final hasResponded = _hasUserResponded();

    // If user has already responded, don't show the quick respond section
    // The edit functionality is available in the responses section header
    if (hasResponded) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Offer your fare',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fareController,
          keyboardType: const TextInputType.numberWithOptions(
              signed: false, decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter fare',
            prefixText: currencySymbol,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorText: _fareError,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isSubmittingResponse ? null : _submitQuickResponse,
            icon: const Icon(Icons.reply, color: Colors.white),
            label: _isSubmittingResponse
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Respond to Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Quick submit. You can edit details later.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _submitQuickResponse() async {
    if (!_canUserRespond() || _request == null) return;
    final raw = _fareController.text.trim().replaceAll(',', '');
    final price = double.tryParse(raw);
    if (price == null || price <= 0) {
      setState(() => _fareError = 'Enter a valid amount');
      return;
    }
    setState(() {
      _fareError = null;
      _isSubmittingResponse = true;
    });
    try {
      final currency = CurrencyHelper.instance.getCurrency();

      // Get user's location and country information
      String? locationAddress;
      double? locationLatitude;
      double? locationLongitude;
      String? countryCode;

      // Get country code from CountryService (preferred) and user data (fallback)
      countryCode = CountryService.instance.getCurrentCountryCode();
      if (countryCode == 'LK' || countryCode.isEmpty) {
        // Fallback to user's country code if default or empty
        try {
          final currentUser = await _userService.getCurrentUserModel();
          if (currentUser?.countryCode != null &&
              currentUser!.countryCode!.isNotEmpty) {
            countryCode = currentUser.countryCode;
          }
        } catch (e) {
          print('Error getting user country: $e');
        }
      }

      // Ensure we have a valid country code - fallback to LK if still null/empty
      if (countryCode == null || countryCode.isEmpty) {
        countryCode = 'LK'; // Default to Sri Lanka
      }

      final data = rest.CreateResponseData(
        message: 'Ride offer',
        price: price,
        currency: currency,
        locationAddress: locationAddress,
        locationLatitude: locationLatitude,
        locationLongitude: locationLongitude,
        countryCode: countryCode,
      );

      final created = await rest.RestRequestService.instance
          .createResponse(_request!.id, data);
      if (created != null) {
        if (!mounted) return;
        _fareController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response submitted')),
        );
        await _loadRequestData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit response')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit response: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingResponse = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _buildAppBarTitle() {
    if (_request == null) return 'Ride Request';

    final vehicleType =
        _vehicleTypeName ?? _request!.rideData?.vehicleType ?? 'Vehicle';
    String pickup = 'Pickup';
    String destination = 'Destination';

    if (_request!.location?.address != null) {
      pickup = _request!.location!.address.split(',').first;
    }

    if (_request!.destinationLocation?.address != null) {
      destination = _request!.destinationLocation!.address.split(',').first;
    }

    return '$vehicleType: $pickup to $destination';
  }

  // Removed old _buildRespondButton in favor of a single inline respond flow
}
