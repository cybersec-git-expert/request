import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/google_places_service.dart';
import 'dart:async';

class LocationPickerWidget extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final bool isRequired;
  final Function(String address, double? lat, double? lng)? onLocationSelected;

  const LocationPickerWidget({
    super.key,
    required this.controller,
    this.hintText = 'Enter or select location',
    this.labelText = 'Location',
    this.isRequired = false,
    this.onLocationSelected,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  bool _isLoadingLocation = false;
  List<PlaceSuggestion> _searchSuggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();
  bool _isReadOnly = true;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedForeverDialog();
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks[0];
        String address = _formatAddress(place);
        
        setState(() {
          widget.controller.text = address;
        });
        
        widget.onLocationSelected?.call(
          address,
          position.latitude,
          position.longitude,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Location detected successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  String _formatAddress(Placemark place) {
    List<String> addressParts = [];
    
    if (place.name != null && place.name!.isNotEmpty) {
      addressParts.add(place.name!);
    }
    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }
    
    return addressParts.join(', ');
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Please enable location services in your device settings to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Denied'),
          content: const Text(
            'Location permission is required to detect your current location. Please allow location access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _getCurrentLocation();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission has been permanently denied. Please enable it in your device settings to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final predictions = await GooglePlacesService.searchPlaces(query);
        
        if (mounted) {
          setState(() {
            _searchSuggestions = predictions;
            _showSuggestions = _searchSuggestions.isNotEmpty;
          });
          
          if (_showSuggestions) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _searchSuggestions = [];
            _showSuggestions = false;
          });
          _removeOverlay();
        }
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    
    if (!_showSuggestions || _searchSuggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _searchSuggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = _searchSuggestions[index];
                  return InkWell(
                    onTap: () async {
                      widget.controller.text = suggestion.description;
                      
                      try {
                        final placeDetails = await GooglePlacesService.getPlaceDetails(suggestion.placeId);
                        
                        if (placeDetails != null) {
                          widget.onLocationSelected?.call(
                            suggestion.description,
                            placeDetails.latitude,
                            placeDetails.longitude,
                          );
                        } else {
                          widget.onLocationSelected?.call(
                            suggestion.description,
                            null,
                            null,
                          );
                        }
                      } catch (e) {
                        widget.onLocationSelected?.call(
                          suggestion.description,
                          null,
                          null,
                        );
                      }
                      
                      _focusNode.unfocus();
                      setState(() {
                        _isReadOnly = true;
                        _showSuggestions = false;
                      });
                      _removeOverlay();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion.description,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        readOnly: _isReadOnly,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingLocation)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Get current location',
                  iconSize: 20,
                ),
              IconButton(
                icon: Icon(_isReadOnly ? Icons.edit : Icons.check),
                onPressed: () {
                  setState(() {
                    _isReadOnly = !_isReadOnly;
                  });
                  if (!_isReadOnly) {
                    _focusNode.requestFocus();
                  } else {
                    _focusNode.unfocus();
                    _removeOverlay();
                  }
                },
                tooltip: _isReadOnly ? 'Edit location' : 'Done editing',
                iconSize: 20,
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          if (!_isReadOnly) {
            _searchLocation(value);
          }
        },
        onTap: () {
          if (_isReadOnly) {
            setState(() {
              _isReadOnly = false;
            });
            _focusNode.requestFocus();
          }
        },
        validator: widget.isRequired ? (value) {
          if (value == null || value.trim().isEmpty) {
            return '${widget.labelText ?? 'Location'} is required';
          }
          return null;
        } : null,
      ),
    );
  }
}