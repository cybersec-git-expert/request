import 'package:flutter/material.dart';
import '../services/google_places_service.dart';
import '../utils/address_utils.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class AccurateLocationPickerWidget extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final bool isRequired;
  final Function(String address, double lat, double lng)? onLocationSelected;
  final IconData prefixIcon;
  final String? countryCode; // optional ISO code to filter autocomplete
  final bool
      enableCurrentLocationTap; // make prefix icon tap fetch current location

  const AccurateLocationPickerWidget({
    super.key,
    required this.controller,
    this.labelText = 'Location',
    this.hintText = 'Search for a location',
    this.isRequired = false,
    this.onLocationSelected,
    this.prefixIcon = Icons.location_on,
    this.countryCode,
    this.enableCurrentLocationTap = false,
  });

  @override
  State<AccurateLocationPickerWidget> createState() =>
      _AccurateLocationPickerWidgetState();
}

class _AccurateLocationPickerWidgetState
    extends State<AccurateLocationPickerWidget> {
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty && query.length > 2) {
        _searchPlaces(query);
      } else {
        _clearSuggestions();
      }
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final suggestions = await GooglePlacesService.searchPlaces(
        query,
        countryCode: widget.countryCode,
      );
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });

      if (_focusNode.hasFocus && suggestions.isNotEmpty) {
        _showOverlay();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _suggestions = [];
      });
      print('Error searching places: $e');
    }
  }

  void _clearSuggestions() {
    setState(() {
      _suggestions = [];
    });
    _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();

    // Compute width to match the text field
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldWidth = box?.size.width ?? MediaQuery.of(context).size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 60),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: fieldWidth,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    title: Text(
                      suggestion.mainText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      suggestion.secondaryText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () => _selectPlace(suggestion),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final overlay = Overlay.of(context);
    if (overlay.mounted) {
      overlay.insert(_overlayEntry!);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission not granted')),
        );
        return;
      }

      setState(() => _isLoading = true);
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      final addr = await GooglePlacesService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      final cleaned = AddressUtils.cleanAddress(addr ?? '');
      widget.controller.text = cleaned;
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(cleaned, pos.latitude, pos.longitude);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get current location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    setState(() {
      _isLoading = true;
    });

    _removeOverlay();
    _focusNode.unfocus();

    try {
      final placeDetails =
          await GooglePlacesService.getPlaceDetails(suggestion.placeId);

      if (placeDetails != null) {
        // Clean the address to remove location codes
        final cleanedAddress =
            AddressUtils.cleanAddress(placeDetails.formattedAddress);
        widget.controller.text = cleanedAddress;

        if (widget.onLocationSelected != null) {
          print('=== LOCATION PICKER CALLBACK ===');
          print('Selected address: "$cleanedAddress"');
          print('Selected latitude: ${placeDetails.latitude}');
          print('Selected longitude: ${placeDetails.longitude}');
          print('================================');

          widget.onLocationSelected!(
            cleanedAddress,
            placeDetails.latitude,
            placeDetails.longitude,
          );
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error getting location details'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _suggestions = [];
      });
    }
  }

  Future<void> _geocodeTypedAddress() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final details = await GooglePlacesService.geocodeAddress(
        text,
        countryCode: widget.countryCode,
      );
      if (details != null) {
        final cleaned = AddressUtils.cleanAddress(details.formattedAddress);
        widget.controller.text = cleaned;
        widget.onLocationSelected?.call(
          cleaned,
          details.latitude,
          details.longitude,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find that address. Try refining it.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geocode failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        key: _fieldKey,
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: widget.enableCurrentLocationTap
              ? InkWell(
                  onTap: _useCurrentLocation,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(widget.prefixIcon),
                  ),
                )
              : Icon(widget.prefixIcon),
          suffixIcon: _isLoading
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(12),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          widget.controller.clear();
                          _clearSuggestions();
                          _focusNode.unfocus();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      tooltip: 'Search address',
                      icon: const Icon(Icons.search),
                      onPressed: _geocodeTypedAddress,
                    ),
                  ],
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          // Allow enough width for clear + search icons
          suffixIconConstraints:
              const BoxConstraints(minWidth: 96, maxWidth: 128, maxHeight: 48),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        textInputAction: TextInputAction.search,
        validator: widget.isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
        onTap: () {
          if (_suggestions.isNotEmpty) {
            _showOverlay();
          }
        },
        onFieldSubmitted: (_) => _geocodeTypedAddress(),
      ),
    );
  }
}
