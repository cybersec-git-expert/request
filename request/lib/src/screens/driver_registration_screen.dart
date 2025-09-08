import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
// Removed firebase_shim after REST migration
// REMOVED_FB_IMPORT: import 'package:cloud_firestore/cloud_firestore.dart';
// REMOVED_FB_IMPORT: import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';
import '../services/enhanced_user_service.dart';
import '../services/file_upload_service.dart';
import '../services/api_client.dart';
import '../widgets/simple_phone_field.dart';
import '../theme/app_theme.dart';
import '../theme/glass_theme.dart';
import '../services/feature_gate_service.dart';
import '../widgets/coming_soon_widget.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final EnhancedUserService _userService = EnhancedUserService();
  final FileUploadService _fileUploadService = FileUploadService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _fullNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _secondaryMobileController = TextEditingController();
  final _nicNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _insuranceNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleColorController = TextEditingController();

  // New fields from mobile app
  DateTime? _dateOfBirth;
  String? _selectedGender;
  String? _selectedCity;
  bool _isVehicleOwner = true;
  bool _licenseHasNoExpiry = false;

  DateTime? _licenseExpiryDate;
  DateTime? _insuranceExpiryDate;

  // Vehicle type selection
  String? _selectedVehicleType;
  List<Map<String, dynamic>> _availableVehicleTypes = [];
  String? _userCountry;

  // Cities selection
  List<Map<String, dynamic>> _availableCities = [];
  bool _loadingCities = false;
  bool _loadingVehicleTypes = false;

  // Document files
  File? _driverImage; // Driver's photo (Profile Photo)
  File? _licenseFrontPhoto; // License front photo
  File? _licenseBackPhoto; // License back photo
  File? _nicFrontPhoto; // NIC Front photo
  File? _nicBackPhoto; // NIC Back photo
  File? _billingProofDocument; // Billing Proof (optional)
  File? _insuranceDocument; // Vehicle insurance document
  File? _vehicleRegistrationDocument; // Vehicle registration document
  List<File> _vehicleImages = []; // Vehicle photos (4 images)

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _userService.getCurrentUserModel();
      if (user != null && mounted) {
        setState(() {
          _fullNameController.text = user.name;

          // Auto-populate first name and last name from user data
          // If not available, try to split the display name
          if (user.firstName != null && user.firstName!.isNotEmpty) {
            _firstNameController.text = user.firstName!;
          } else if (user.name.isNotEmpty) {
            // Try to split display name into first and last names
            final nameParts = user.name.split(' ');
            _firstNameController.text = nameParts.first;
          }

          if (user.lastName != null && user.lastName!.isNotEmpty) {
            _lastNameController.text = user.lastName!;
          } else if (user.name.split(' ').length > 1) {
            // Use remaining parts as last name
            final nameParts = user.name.split(' ');
            _lastNameController.text = nameParts.skip(1).join(' ');
          }

          // Phone field starts empty - user enters their phone number
          _userCountry =
              user.countryCode ?? 'LK'; // Default to Sri Lanka if not set
        });

        // Load available vehicle types for user's country
        await _loadAvailableVehicleTypes();

        // Load available cities for user's country
        await _loadAvailableCities();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadAvailableVehicleTypes() async {
    try {
      setState(() {
        _loadingVehicleTypes = true;
      });

      final countryCode = _userCountry ?? 'LK';
      if (kDebugMode)
        debugPrint('🔄 Loading vehicle types for country: $countryCode');
      final response = await ApiClient.instance.get(
        '/api/vehicle-types/public/$countryCode',
      );
      if (response.data['success'] == true) {
        final vehicleTypes = (response.data['data'] as List)
            .map((vt) => {
                  'id': vt['id'] as String,
                  'name': vt['name'] as String,
                  'icon': vt['icon'] ?? 'DirectionsCar',
                  'displayOrder': vt['displayOrder'] ?? 0,
                  'passengerCapacity': vt['passengerCapacity'] ?? 1,
                })
            .toList();

        if (mounted) {
          setState(() {
            _availableVehicleTypes = vehicleTypes.isNotEmpty
                ? vehicleTypes
                : [
                    {
                      'id': 'no_vehicles',
                      'name': 'No vehicle types enabled for your country',
                      'icon': 'DirectionsCar',
                      'displayOrder': 0,
                      'passengerCapacity': 1
                    }
                  ];

            // Auto-select first available vehicle type
            if (_selectedVehicleType == null &&
                _availableVehicleTypes.isNotEmpty &&
                _availableVehicleTypes.first['id'] != 'no_vehicles') {
              _selectedVehicleType = _availableVehicleTypes.first['id'];
            }
            _loadingVehicleTypes = false;
          });
          if (kDebugMode)
            debugPrint(
                '✅ Loaded ${vehicleTypes.length} vehicle types for $countryCode: ${vehicleTypes.map((v) => v['name']).join(', ')}');
        }
      } else {
        throw Exception('API returned success: false');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading vehicle types: $e');
      if (mounted) {
        setState(() {
          _availableVehicleTypes = [
            {
              'id': 'error',
              'name': 'Network error - contact support',
              'icon': 'DirectionsCar',
              'displayOrder': 0,
              'passengerCapacity': 1
            }
          ];
          _loadingVehicleTypes = false;
        });
      }
    }
  }

  Future<void> _loadAvailableCities() async {
    try {
      setState(() {
        _loadingCities = true;
      });

      final countryCode = _userCountry ?? 'LK';
      if (kDebugMode) debugPrint('🔄 Loading cities for country: $countryCode');
      final response = await ApiClient.instance.get(
        '/api/cities',
        queryParameters: {'country': countryCode},
      );

      if (response.data['success'] == true) {
        final cities = (response.data['data'] as List)
            .map((city) => {
                  'id': city['id']?.toString() ?? city['name'],
                  'name': city['name'] as String,
                  'countryCode': city['countryCode'] ?? countryCode,
                })
            .where((city) => city['name']?.isNotEmpty == true)
            .toList();

        if (mounted) {
          setState(() {
            _availableCities = cities.isNotEmpty
                ? cities
                : [
                    {
                      'id': 'no_cities',
                      'name': 'No cities available',
                      'countryCode': countryCode
                    }
                  ];
            _loadingCities = false;
          });
          if (kDebugMode)
            debugPrint(
                '✅ Loaded ${cities.length} cities for $countryCode: ${cities.map((c) => c['name']).join(', ')}');
        }
      } else {
        throw Exception('API returned success: false');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cities: $e');
      if (mounted) {
        setState(() {
          _availableCities = [
            {
              'id': 'error',
              'name': 'Network error - try again',
              'countryCode': _userCountry ?? 'LK'
            }
          ];
          _loadingCities = false;
        });
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() => _dateOfBirth = picked);
    }
  }

  void _showDocumentRequirementsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Required Documents'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• National Identity Card'),
            Text('• No Objection Certificate (if not vehicle owner)'),
            Text('• Vehicle Owner\'s National Identity Card (if applicable)'),
            Text('• Billing Proof (Utility bill or bank statement)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _licenseNumberController.dispose();
    _insuranceNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleNumberController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  // Get selected city data with both ID and name
  Map<String, dynamic>? _getSelectedCityData() {
    if (_selectedCity == null) return null;

    // Find the city in available cities list
    final city = _availableCities.firstWhere(
        (city) => city['name'] == _selectedCity,
        orElse: () => {'id': null, 'name': _selectedCity});

    return {
      'id': city['id'], // UUID from database
      'name': city['name'] // City name
    };
  }

  // Get selected vehicle type data with both ID and name
  Map<String, dynamic>? _getSelectedVehicleTypeData() {
    if (_selectedVehicleType == null) return null;

    // Find the vehicle type in available vehicle types list
    final vehicleType = _availableVehicleTypes.firstWhere(
        (vt) => vt['id'] == _selectedVehicleType,
        orElse: () => {'id': _selectedVehicleType, 'name': 'Unknown'});

    return {
      'id': vehicleType['id'], // UUID from database
      'name': vehicleType['name'] // Vehicle type name
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: FeatureGateService.instance.isDriverRegistrationEnabled(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GlassTheme.backgroundContainer(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Driver Registration'),
                backgroundColor: Colors.transparent,
                foregroundColor: GlassTheme.colors.textPrimary,
                elevation: 0,
              ),
              body: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.data == false) {
          return ComingSoonWidget(
            title: 'Driver Registration',
            description:
                'Driver registration is not available in your country yet. We\'re working to bring ride sharing services to your region soon!',
            icon: Icons.drive_eta,
          );
        }

        // Original driver registration form
        return GlassTheme.backgroundContainer(
            child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Driver Registration'),
            backgroundColor: Colors.transparent,
            foregroundColor: GlassTheme.colors.textPrimary,
            elevation: 0,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDriverInformation(),
                  const SizedBox(height: 24),
                  _buildDocumentsSection(),
                  const SizedBox(height: 24),
                  _buildVehicleInformation(),
                  const SizedBox(height: 24),
                  _buildVehicleDocuments(),
                  const SizedBox(height: 24),
                  _buildVehicleImages(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ));
      },
    );
  }

  // Helper method to get vehicle icon based on icon name
  Widget _getVehicleIcon(String iconName) {
    IconData iconData;
    switch (iconName) {
      case 'DirectionsCar':
        iconData = Icons.directions_car;
        break;
      case 'TwoWheeler':
        iconData = Icons.two_wheeler;
        break;
      case 'LocalShipping':
        iconData = Icons.local_shipping;
        break;
      case 'DirectionsBus':
        iconData = Icons.directions_bus;
        break;
      case 'Motorcycle':
        iconData = Icons.motorcycle;
        break;
      case 'LocalTaxi':
        iconData = Icons.local_taxi;
        break;
      case 'AirportShuttle':
        iconData = Icons.airport_shuttle;
        break;
      default:
        iconData = Icons.directions_car;
    }
    return Icon(iconData, size: 20);
  }

  Widget _buildDriverInformation() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('About You', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  readOnly: false, // Allow editing for ID card accuracy
                  decoration: const InputDecoration(
                    labelText: 'First Name * (as on ID card)',
                    helperText: 'Edit if different from your ID card',
                    prefixIcon: Icon(Icons.person_outline),
                    border: InputBorder.none,
                    filled: true,
                    fillColor:
                        Color(0xFFF9F9F9), // Lighter fill to show it's editable
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'First name is required (as shown on ID card)';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  readOnly: false, // Allow editing for ID card accuracy
                  decoration: const InputDecoration(
                    labelText: 'Last Name * (as on ID card)',
                    helperText: 'Edit if different from your ID card',
                    prefixIcon: Icon(Icons.person_outline),
                    border: InputBorder.none,
                    filled: true,
                    fillColor:
                        Color(0xFFF9F9F9), // Lighter fill to show it's editable
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Last name is required (as shown on ID card)';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _selectDateOfBirth,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 12),
                  Text(
                    _dateOfBirth == null
                        ? 'Date of Birth *'
                        : 'Date of Birth: ${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                    style: TextStyle(
                      color: _dateOfBirth == null
                          ? Colors.grey[600]
                          : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender *',
                prefixIcon: Icon(Icons.person),
                border: InputBorder.none,
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your gender';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nicNumberController,
            decoration: const InputDecoration(
              labelText: 'NIC Number *',
              prefixIcon: Icon(Icons.credit_card),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your NIC number';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          // Contact Details Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.contact_phone,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Contact Details', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          // Simple phone number field
          SimplePhoneField(
            controller: _phoneController,
            label: 'Phone Number *',
            hint: 'Enter your phone number',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required for driver registration';
              }
              // Basic phone validation - at least 7 digits
              final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
              if (cleanPhone.length < 7) {
                return 'Please enter a valid phone number (minimum 7 digits)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCity,
              decoration: InputDecoration(
                labelText: 'City *',
                prefixIcon: const Icon(Icons.location_city),
                border: InputBorder.none,
                suffixIcon: _loadingCities
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              items: _availableCities.map((city) {
                return DropdownMenuItem<String>(
                  value: city['name'],
                  child: Text(city['name']),
                );
              }).toList()
                ..add(const DropdownMenuItem(
                    value: 'other', child: Text('Other'))),
              onChanged: _loadingCities
                  ? null
                  : (value) {
                      setState(() {
                        _selectedCity = value;
                      });
                    },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your city';
                }
                return null;
              },
              hint: _loadingCities
                  ? const Text('Loading cities...')
                  : const Text('Select your city'),
            ),
          ),
          const SizedBox(height: 24),
          // Vehicle Ownership Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Vehicle Ownership', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              children: [
                RadioListTile<bool>(
                  title: const Text(
                      'I am the owner of this vehicle I am about to register.'),
                  value: true,
                  groupValue: _isVehicleOwner,
                  onChanged: (value) {
                    setState(() {
                      _isVehicleOwner = value!;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                RadioListTile<bool>(
                  title: const Text('I am not the owner of the vehicle.'),
                  value: false,
                  groupValue: _isVehicleOwner,
                  onChanged: (value) {
                    setState(() {
                      _isVehicleOwner = value!;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
            ),
            child: GestureDetector(
              onTap: () {
                _showDocumentRequirementsDialog();
              },
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'See list of documents required',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[800],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _licenseNumberController,
            decoration: const InputDecoration(
              labelText: 'Driving License Number *',
              prefixIcon: Icon(Icons.credit_card),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your license number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (!_licenseHasNoExpiry)
            GestureDetector(
              onTap: _selectLicenseExpiryDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      _licenseExpiryDate == null
                          ? 'Expiration Date *'
                          : 'Expiration Date: ${_licenseExpiryDate!.day}/${_licenseExpiryDate!.month}/${_licenseExpiryDate!.year}',
                      style: TextStyle(
                        color: _licenseExpiryDate == null
                            ? Colors.grey[600]
                            : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          if (!_licenseHasNoExpiry) const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: CheckboxListTile(
              title: const Text(
                'My licence does not have an expiry date. (for older licences)',
                style: TextStyle(fontSize: 14),
              ),
              value: _licenseHasNoExpiry,
              onChanged: (value) {
                setState(() {
                  _licenseHasNoExpiry = value!;
                  if (_licenseHasNoExpiry) {
                    _licenseExpiryDate = null;
                  }
                });
              },
              activeColor: AppTheme.primaryColor,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Personal Document Upload', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '* Required',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Profile Photo Section
          Row(
            children: [
              Icon(Icons.person,
                  color: GlassTheme.colors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text('Profile Photo', style: GlassTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          _buildDocumentUpload(
            'Profile Photo',
            'Upload or capture your photo *',
            _driverImage,
            () => _pickDocument('driver_image'),
            Icons.person,
            isRequired: true,
          ),
          const SizedBox(height: 24),
          // Driving License Section
          Row(
            children: [
              Icon(Icons.credit_card,
                  color: GlassTheme.colors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text('Driving License', style: GlassTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          _buildDocumentUpload(
            'Driving License - Front',
            'Upload or capture the front side of your driving license *',
            _licenseFrontPhoto,
            () => _pickDocument('license_front'),
            Icons.credit_card,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildDocumentUpload(
            'Driving License - Rear',
            'Upload or capture the back side of your driving license *',
            _licenseBackPhoto,
            () => _pickDocument('license_back'),
            Icons.flip_to_back,
            isRequired: true,
          ),
          const SizedBox(height: 24),
          // National Identity Card Section
          Row(
            children: [
              Icon(Icons.badge, color: GlassTheme.colors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text('National Identity Card', style: GlassTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          _buildDocumentUpload(
            'NIC - Front',
            'Upload or capture the front side of your National Identity Card',
            _nicFrontPhoto,
            () => _pickDocument('nic_front'),
            Icons.badge,
            isRequired: false,
          ),
          const SizedBox(height: 16),
          _buildDocumentUpload(
            'NIC - Rear',
            'Upload or capture the back side of your National Identity Card',
            _nicBackPhoto,
            () => _pickDocument('nic_back'),
            Icons.flip_to_back,
            isRequired: false,
          ),
          const SizedBox(height: 24),
          // Billing Proof Section
          Row(
            children: [
              Icon(Icons.receipt,
                  color: GlassTheme.colors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text('Billing Proof (optional)', style: GlassTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          _buildDocumentUpload(
            'Billing Proof',
            'Billing proof is used to confirm your address. It can be a utility bill (water, electricity or landline phone) or a bank statement with your correct address.',
            _billingProofDocument,
            () => _pickDocument('billing_proof'),
            Icons.receipt,
            isRequired: false,
          ),
          const SizedBox(height: 16),
          _buildInsuranceSection(),
        ],
      ),
    );
  }

  Widget _buildInsuranceSection() {
    return Column(
      children: [
        TextFormField(
          controller: _insuranceNumberController,
          decoration: const InputDecoration(
            labelText: 'Insurance Number *',
            prefixIcon: Icon(Icons.security),
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your insurance number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _selectInsuranceExpiryDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 12),
                Text(
                  _insuranceExpiryDate == null
                      ? 'Insurance Expiry Date *'
                      : 'Insurance Expiry: ${_insuranceExpiryDate!.day}/${_insuranceExpiryDate!.month}/${_insuranceExpiryDate!.year}',
                  style: TextStyle(
                    color: _insuranceExpiryDate == null
                        ? Colors.grey[600]
                        : Colors.black,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDocumentUpload(
          'Vehicle Insurance Document',
          'Upload or capture your vehicle insurance certificate',
          _insuranceDocument,
          () => _pickDocument('vehicle_insurance'),
          Icons.security,
          isRequired: true,
        ),
        const SizedBox(height: 16),
        _buildDocumentUpload(
          'Vehicle Registration Document',
          'Upload or capture your vehicle registration document',
          _vehicleRegistrationDocument,
          () => _pickDocument('vehicle_registration'),
          Icons.assignment,
          isRequired: true,
        ),
      ],
    );
  }

  Widget _buildVehicleInformation() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Vehicle Information', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          // Vehicle Type Selection
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category, color: Colors.grey),
                    const SizedBox(width: 12),
                    const Text(
                      'Vehicle Type *',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingVehicleTypes)
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading vehicle types...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                else if (_availableVehicleTypes.isEmpty)
                  const Text(
                    'No vehicle types available',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedVehicleType,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    items: _availableVehicleTypes.map((vehicle) {
                      return DropdownMenuItem<String>(
                        value: vehicle['id'],
                        child: Row(
                          children: [
                            _getVehicleIcon(vehicle['icon']),
                            const SizedBox(width: 8),
                            Text(vehicle['name']),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedVehicleType = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a vehicle type';
                      }
                      return null;
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleModelController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Make & Model *',
              hintText: 'e.g., Toyota Camry',
              prefixIcon: Icon(Icons.directions_car),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your vehicle make & model';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _vehicleYearController,
                  decoration: const InputDecoration(
                    labelText: 'Year *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _vehicleColorController,
                  decoration: const InputDecoration(
                    labelText: 'Color *',
                    prefixIcon: Icon(Icons.color_lens),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleNumberController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Number/License Plate *',
              hintText: 'e.g., ABC-1234',
              prefixIcon: Icon(Icons.confirmation_number),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your vehicle number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDocuments() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Vehicle Documents', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVehicleImages() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_camera,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Vehicle Photos', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Required: 4 vehicle photos (upload or capture)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Front view with number plate visible',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                      Text(
                        '2. Rear view with number plate visible',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                      Text(
                        '3. & 4. Additional vehicle photos',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount:
                _vehicleImages.length < 6 ? _vehicleImages.length + 1 : 6,
            itemBuilder: (context, index) {
              if (index < _vehicleImages.length) {
                return _buildVehicleImageItem(index);
              } else {
                return _buildAddImageButton();
              }
            },
          ),
          if (_vehicleImages.length < 4) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Please upload at least ${4 - _vehicleImages.length} more photo(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleImageItem(int index) {
    String title = '';
    switch (index) {
      case 0:
        title = '1. Front View\n(with number plate)';
        break;
      case 1:
        title = '2. Rear View\n(with number plate)';
        break;
      default:
        title = '${index + 1}. Vehicle Photo';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                  ),
                  child: Image.file(
                    _vehicleImages[index],
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeVehicleImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickVehicleImage,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(
              color: Colors.grey[300]!, style: BorderStyle.solid, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo,
              size: 40,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Add Photo',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUpload(String title, String description, File? file,
      VoidCallback onTap, IconData icon,
      {bool isRequired = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: file != null ? Colors.green.withOpacity(0.1) : Colors.white,
        ),
        child: Column(
          children: [
            Icon(
              file != null ? Icons.check_circle : icon,
              size: 40,
              color: file != null ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              file != null ? '$title - Uploaded' : title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: file != null ? Colors.green : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              file != null ? 'Tap to change document' : description,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canSubmit() ? _submitVerification : null,
        style: GlassTheme.primaryButton,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit for Verification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  bool _canSubmit() {
    // No phone verification required in form - will be handled post-submission
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty && // Phone number required
        _dateOfBirth != null &&
        _selectedGender != null &&
        _nicNumberController.text.trim().isNotEmpty &&
        _selectedCity != null &&
        _licenseNumberController.text.trim().isNotEmpty &&
        (_licenseExpiryDate != null || _licenseHasNoExpiry) &&
        _driverImage != null && // Driver photo required
        _licenseFrontPhoto != null && // License front photo required
        _licenseBackPhoto != null && // License back photo required
        _insuranceNumberController.text.trim().isNotEmpty &&
        _insuranceExpiryDate != null && // Insurance expiry date required
        _insuranceDocument != null && // Vehicle insurance required
        _vehicleModelController.text.trim().isNotEmpty &&
        _vehicleYearController.text.trim().isNotEmpty &&
        _vehicleColorController.text.trim().isNotEmpty &&
        _vehicleNumberController.text.trim().isNotEmpty &&
        _vehicleRegistrationDocument != null && // Vehicle registration required
        _vehicleImages.length >= 4 && // Minimum 4 vehicle photos
        !_isLoading;
  }

  // (Removed duplicate _loadAvailableCities and obsolete _buildDocumentListItem)

  Future<void> _selectLicenseExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(() => _licenseExpiryDate = date);
    }
  }

  Future<void> _selectInsuranceExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(() => _insuranceExpiryDate = date);
    }
  }

  Future<void> _pickDocument(String type) async {
    // Show dialog to choose between camera and gallery
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text('Choose how you want to add the document:'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1500,
      maxHeight: 1500,
    );

    if (image != null) {
      setState(() {
        switch (type) {
          case 'driver_image':
            _driverImage = File(image.path);
            break;
          case 'license_front':
            _licenseFrontPhoto = File(image.path);
            break;
          case 'license_back':
            _licenseBackPhoto = File(image.path);
            break;
          case 'nic_front':
            _nicFrontPhoto = File(image.path);
            break;
          case 'nic_back':
            _nicBackPhoto = File(image.path);
            break;
          case 'billing_proof':
            _billingProofDocument = File(image.path);
            break;
          case 'vehicle_insurance':
            _insuranceDocument = File(image.path);
            break;
          case 'vehicle_registration':
            _vehicleRegistrationDocument = File(image.path);
            break;
        }
      });
    }
  }

  Future<void> _pickVehicleImage() async {
    if (_vehicleImages.length >= 6) return;

    // Show dialog to choose between camera and gallery
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Text(
          _vehicleImages.length < 2
              ? 'Photo ${_vehicleImages.length + 1}: ${_vehicleImages.length == 0 ? "Front view with number plate" : "Rear view with number plate"}'
              : 'Additional vehicle photo ${_vehicleImages.length + 1}',
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1500,
      maxHeight: 1500,
    );

    if (image != null) {
      setState(() {
        _vehicleImages.add(File(image.path));
      });
    }
  }

  void _removeVehicleImage(int index) {
    setState(() {
      _vehicleImages.removeAt(index);
    });
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate() || !_canSubmit()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) throw Exception('User not authenticated');

      // Upload documents
      String? driverImageUrl,
          licenseFrontUrl,
          licenseBackUrl,
          nicFrontUrl,
          nicBackUrl,
          billingProofUrl,
          insuranceUrl,
          registrationUrl;
      List<String> vehicleImageUrls = [];

      // Upload driver photo (required)
      if (_driverImage != null) {
        driverImageUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _driverImage!, 'driver_photo');
      }

      // Upload license front photo (required)
      if (_licenseFrontPhoto != null) {
        licenseFrontUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _licenseFrontPhoto!, 'license_front');
      }

      // Upload license back photo (required)
      if (_licenseBackPhoto != null) {
        licenseBackUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _licenseBackPhoto!, 'license_back');
      }

      // Upload NIC front photo (optional)
      if (_nicFrontPhoto != null) {
        nicFrontUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _nicFrontPhoto!, 'nic_front');
      }

      // Upload NIC back photo (optional)
      if (_nicBackPhoto != null) {
        nicBackUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _nicBackPhoto!, 'nic_back');
      }

      // Upload billing proof document (optional)
      if (_billingProofDocument != null) {
        billingProofUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _billingProofDocument!, 'billing_proof');
      }

      // Upload license front photo (required)
      if (_licenseFrontPhoto != null) {
        licenseFrontUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _licenseFrontPhoto!, 'license_front');
      }

      // Upload license back photo (required)
      if (_licenseBackPhoto != null) {
        licenseBackUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _licenseBackPhoto!, 'license_back');
      }

      // Upload vehicle insurance document (required)
      if (_insuranceDocument != null) {
        insuranceUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid, _insuranceDocument!, 'vehicle_insurance');
      }

      // Upload vehicle registration document (required)
      if (_vehicleRegistrationDocument != null) {
        registrationUrl = await _fileUploadService.uploadDriverDocument(
            currentUser.uid,
            _vehicleRegistrationDocument!,
            'vehicle_registration');
      }

      // Upload vehicle images
      for (int i = 0; i < _vehicleImages.length; i++) {
        final imageUrl = await _fileUploadService.uploadVehicleImage(
            currentUser.uid, _vehicleImages[i], i + 1);
        vehicleImageUrls.add(imageUrl);
      }

      // Create driver verification data
      final driverData = {
        'userId': currentUser.uid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'fullName':
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'email': currentUser.email,
        'phoneNumber': _phoneController.text.trim(),
        'phoneVerified': false, // Will be verified post-submission
        'phoneVerificationSource': 'form_submission',
        'secondaryMobile': _secondaryMobileController.text.trim().isNotEmpty
            ? _secondaryMobileController.text.trim()
            : null,
        'dateOfBirth': _dateOfBirth,
        'gender': _selectedGender,
        'nicNumber': _nicNumberController.text.trim(),
        'city': _getSelectedCityData(),
        'isVehicleOwner': _isVehicleOwner,
        'licenseNumber': _licenseNumberController.text.trim(),
        'licenseExpiry': _licenseHasNoExpiry ? null : _licenseExpiryDate,
        'licenseHasNoExpiry': _licenseHasNoExpiry,
        'insuranceNumber': _insuranceNumberController.text.trim(),
        'insuranceExpiry': _insuranceExpiryDate,
        'vehicleModel': _vehicleModelController.text.trim(),
        'vehicleYear': int.parse(_vehicleYearController.text.trim()),
        'vehicleColor': _vehicleColorController.text.trim(),
        'vehicleNumber': _vehicleNumberController.text.trim(),
        'vehicleType': _getSelectedVehicleTypeData(),
        'country': _userCountry,
        'status': 'pending',
        'isVerified': false,
        'isActive': true,
        'availability': true,
        'rating': 0.0,
        'totalRides': 0,
        'totalEarnings': 0.0,
        'subscriptionPlan': 'free',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),

        // Document URLs
        'driverImageUrl': driverImageUrl, // Driver photo (profile photo)
        'licenseFrontUrl': licenseFrontUrl, // License front photo
        'licenseBackUrl': licenseBackUrl, // License back photo
        'nicFrontUrl': nicFrontUrl, // NIC front photo (optional)
        'nicBackUrl': nicBackUrl, // NIC back photo (optional)
        'billingProofUrl': billingProofUrl, // Billing proof (optional)
        'insuranceDocumentUrl': insuranceUrl, // Vehicle insurance
        'vehicleRegistrationUrl': registrationUrl, // Vehicle registration
        'vehicleImageUrls': vehicleImageUrls,

        // Verification status for each document/image
        'documentVerification': {
          'driverImage': {
            'status': 'pending',
            'submittedAt': DateTime.now()
          }, // Driver photo
          'licenseFront': {
            'status': 'pending',
            'submittedAt': DateTime.now()
          }, // License front
          'licenseBack': {
            'status': 'pending',
            'submittedAt': DateTime.now()
          }, // License back
          'nicFront': nicFrontUrl != null
              ? {'status': 'pending', 'submittedAt': DateTime.now()}
              : null, // Optional: NIC front
          'nicBack': nicBackUrl != null
              ? {'status': 'pending', 'submittedAt': DateTime.now()}
              : null, // Optional: NIC back
          'billingProof': billingProofUrl != null
              ? {'status': 'pending', 'submittedAt': DateTime.now()}
              : null, // Optional: Billing proof
          'vehicleInsurance': {
            'status': 'pending',
            'submittedAt': DateTime.now()
          }, // Vehicle insurance
          'vehicleRegistration': {
            'status': 'pending',
            'submittedAt': DateTime.now()
          }, // Vehicle registration
        },
        'vehicleImageVerification': _vehicleImages
            .asMap()
            .entries
            .map((entry) => {
                  'imageIndex': entry.key,
                  'status': 'pending',
                  'submittedAt': DateTime.now(),
                  'imageType': entry.key == 0
                      ? 'front_with_plate'
                      : entry.key == 1
                          ? 'rear_with_plate'
                          : 'additional',
                })
            .toList(),
      };

      // Save to Firestore
      await _userService.submitDriverVerification(driverData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Driver verification submitted successfully! We\'ll review your documents within 1-3 business days.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Phone verification is now handled post-submission
  // Users enter their phone number in the form and verification happens
  // after they check their verification status
}
