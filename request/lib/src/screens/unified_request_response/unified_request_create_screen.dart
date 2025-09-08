import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../widgets/glass_page.dart';
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart';
import '../../services/centralized_request_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../widgets/image_upload_widget.dart';
import '../../services/country_service.dart';
import '../../widgets/accurate_location_picker_widget.dart';
import '../../widgets/category_picker.dart';
import '../../utils/currency_helper.dart';

class UnifiedRequestCreateScreen extends StatefulWidget {
  final RequestType? initialType;
  final String?
      initialModule; // e.g., item, rent, delivery, ride, tours, events, construction, education, hiring, other

  const UnifiedRequestCreateScreen(
      {super.key, this.initialType, this.initialModule});

  @override
  State<UnifiedRequestCreateScreen> createState() =>
      _UnifiedRequestCreateScreenState();
}

class _UnifiedRequestCreateScreenState
    extends State<UnifiedRequestCreateScreen> {
  final EnhancedUserService _userService = EnhancedUserService();
  final CentralizedRequestService _requestService = CentralizedRequestService();

  // Common form controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();

  // Item-specific controllers
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();

  // Rental-specific controllers
  final _itemToRentController = TextEditingController();
  final _rentalItemController = TextEditingController();

  // Delivery-specific controllers
  final _pickupLocationController = TextEditingController();
  final _dropoffLocationController = TextEditingController();
  final _itemCategoryController = TextEditingController();
  final _itemDescriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  // Service module dynamic controllers/fields
  final _peopleCountController = TextEditingController(); // tours/events
  final _durationDaysController = TextEditingController(); // tours
  final _guestsCountController = TextEditingController(); // events
  final _areaSizeController = TextEditingController(); // construction (sqft)
  // Construction module
  final _projectLocationNoteController = TextEditingController();
  String _constructionMainCategory = '';
  String _constructionScopeOfWork = 'Labor & Materials (Provide a full quote)';
  final _constructionMeasurementsController = TextEditingController();
  final _constructionItemsListController = TextEditingController();
  bool _constructionDeliveryRequired = false;
  DateTime? _rentalStartDate; // for equipment rental
  DateTime? _rentalEndDate; // for equipment rental
  int _numberOfFloors = 1;
  String _plansStatus = '';
  String _propertyType = 'Residential Land';
  final _landSizeController = TextEditingController();
  final _sessionsPerWeekController = TextEditingController(); // education
  // Education module
  String _preferredEducationMode = 'Online'; // Online, In-Person, Both
  final _studentsCountController = TextEditingController();
  final _detailedNeedsController = TextEditingController();
  // Education: Academic Tutoring
  final _subjectsController = TextEditingController();
  String _syllabus = 'Local (National)';
  final _syllabusOtherController = TextEditingController();
  // Education: Professional & Skill Development
  final _courseOrSkillController = TextEditingController();
  final _desiredOutcomeControllerEdu = TextEditingController();
  // Education: Arts & Hobbies
  final _artOrSportController = TextEditingController();
  String _classType = 'Individual'; // Individual, Group, Workshop
  // Education: Admissions & Consulting
  final _targetCountryController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  final _experienceYearsController = TextEditingController(); // hiring
  bool _needsGuide = false; // tours
  bool _pickupRequiredForTour = false; // tours
  // Use a value that always exists in dropdown items to avoid value mismatch
  String _educationLevel = 'Other'; // education
  String _positionType = 'Full-time'; // hiring
  // Job Request module (users post their qualifications, employers respond)
  final TextEditingController _desiredJobTitleController =
      TextEditingController();
  final TextEditingController _qualificationsController =
      TextEditingController();
  final TextEditingController _salaryExpectationController =
      TextEditingController();
  String _payPeriod = 'Monthly'; // Monthly, Weekly, Daily, Hourly
  bool _isSalaryNegotiable = false;
  final Set<String> _benefits =
      <String>{}; // EPF/ETF, Meals, Accommodation, Transport, OT
  String _workArrangement = 'On-site'; // On-site, Hybrid, Remote
  String _educationRequirement =
      'O/L'; // O/L, A/L, Diploma, Degree, Postgraduate
  final TextEditingController _skillsController =
      TextEditingController(); // comma separated
  String _applyMethod = 'In-App'; // In-App, Call, Email
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  DateTime? _applicationDeadline; // date-only

  // Tours module – general and category-specific state
  DateTime? _tourStartDate; // date-only
  DateTime? _tourEndDate; // date-only
  int _adults = 2;
  int _children = 0;

  // Events module – general and category-specific state
  DateTime? _eventDate; // date-only
  TimeOfDay? _eventStartTime;
  TimeOfDay? _eventEndTime;
  String _eventType = 'Wedding';
  final TextEditingController _eventOtherTypeController =
      TextEditingController();
  // Venues
  String _venueType = 'Indoor'; // Indoor / Outdoor / Poolside / Garden / Hall
  final Set<String> _requiredFacilities =
      <String>{}; // AC, Parking, Sound, etc.
  // Food & Beverage
  final Set<String> _cuisineTypes = <String>{};
  String _serviceStyle = 'Buffet';
  final TextEditingController _dietaryNeedsController = TextEditingController();
  // Entertainment & Talent
  String _talentType = '';
  final TextEditingController _durationRequiredController =
      TextEditingController();
  String _talentVenueType = 'Indoor';
  // Services & Staff
  String _staffType = '';
  int _staffCount = 1;
  final TextEditingController _hoursRequiredController =
      TextEditingController();
  // Rentals & Supplies
  final TextEditingController _rentalItemsListController =
      TextEditingController();
  final Set<String> _rentalRequiredServices =
      <String>{}; // Delivery & Pickup, On-site Setup

  // Tours & Experiences
  String _tourType = 'Cultural & Heritage';
  String _preferredLanguage = 'English';
  final _otherLanguageController = TextEditingController();
  final Set<String> _timeOfDayPrefs =
      <String>{}; // Morning, Afternoon, Evening, Full Day
  bool _jeepIncluded = false;
  String _skillLevel = 'Beginner';

  // Transportation (within tours)
  String _transportType = 'Hire Driver for Tour';
  final _tourPickupController = TextEditingController();
  final _tourDropoffController = TextEditingController();
  final Set<String> _vehicleTypes =
      <String>{}; // Car (Sedan), Van (AC), Tuk-Tuk, Motorbike/Scooter, Luxury Vehicle
  String _luggageOption = 'Small Bags Only';
  final _itineraryController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _flightTimeController = TextEditingController();
  bool _licenseConfirmed = false;

  // Accommodation (within tours)
  String _accommodationType = 'Hotel';
  int _unitsCount = 1; // rooms or beds
  String _unitsType = 'rooms'; // 'rooms' or 'beds'
  final Set<String> _amenities =
      <String>{}; // AC, Hot Water, Wi-Fi, Kitchen, Pool, Parking
  String _boardBasis = 'Room Only';
  bool _cookStaffRequired = false;
  bool _mealsWithHostFamily = false;
  String _hostelRoomType = 'Dormitory';

  RequestType _selectedType = RequestType.item;
  String? _selectedModule; // service subtype/module context
  String _selectedCondition = 'New';
  String _selectedUrgency = 'Flexible';
  // kept for parity with other flows if needed later

  String _selectedCategory = 'Electronics';
  String? _selectedCategoryId;
  String? _selectedSubCategoryId;
  String? _selectedSubcategory;
  String _pickupDropoffPreference = 'pickup';
  // legacy placeholders removed; using *_DateTime specific fields
  DateTime? _preferredDateTime;
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  DateTime? _preferredDeliveryTime;
  List<String> _imageUrls = [];
  bool _isLoading = false;
  double? _selectedLatitude;
  double? _selectedLongitude;

  final List<String> _conditions = [
    'New',
    'Used',
    'For Parts',
    'Any Condition'
  ];
  final List<String> _urgencyLevels = ['Flexible', 'ASAP', 'Specific Date'];
  // delivery time options are derived inline in UI where needed

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? RequestType.item;
    _selectedModule = widget.initialModule;
    // If opened for a specific service module, reflect it in the visible label
    if (_selectedType == RequestType.service && _selectedModule != null) {
      final m = _selectedModule!;
      // Use module as a temporary visible category label until user picks from CategoryPicker
      _selectedCategory = m.isNotEmpty
          ? m[0].toUpperCase() + (m.length > 1 ? m.substring(1) : '')
          : _selectedCategory;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _itemNameController.dispose();
    _quantityController.dispose();
    _itemToRentController.dispose();
    _rentalItemController.dispose();
    _pickupLocationController.dispose();
    _dropoffLocationController.dispose();
    _itemCategoryController.dispose();
    _itemDescriptionController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _specialInstructionsController.dispose();
    // dispose dynamic controllers
    _peopleCountController.dispose();
    _durationDaysController.dispose();
    _guestsCountController.dispose();
    _areaSizeController.dispose();
    _sessionsPerWeekController.dispose();
    _studentsCountController.dispose();
    _detailedNeedsController.dispose();
    _subjectsController.dispose();
    _syllabusOtherController.dispose();
    _courseOrSkillController.dispose();
    _desiredOutcomeControllerEdu.dispose();
    _artOrSportController.dispose();
    _targetCountryController.dispose();
    _fieldOfStudyController.dispose();
    _experienceYearsController.dispose();
    _desiredJobTitleController.dispose();
    _qualificationsController.dispose();
    _salaryExpectationController.dispose();
    _skillsController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _otherLanguageController.dispose();
    _tourPickupController.dispose();
    _tourDropoffController.dispose();
    _itineraryController.dispose();
    _flightNumberController.dispose();
    _flightTimeController.dispose();
    // construction
    _projectLocationNoteController.dispose();
    _constructionMeasurementsController.dispose();
    _constructionItemsListController.dispose();
    _landSizeController.dispose();
    // events
    _eventOtherTypeController.dispose();
    _dietaryNeedsController.dispose();
    _durationRequiredController.dispose();
    _hoursRequiredController.dispose();
    _rentalItemsListController.dispose();
    super.dispose();
  }

  // Derive which module banner to show based on selected type and module.
  String? _effectiveBannerModule() {
    // If a specific module is set, use it (normalize aliases)
    if (_selectedModule != null && _selectedModule!.isNotEmpty) {
      final m = _selectedModule!.toLowerCase();
      if (m == 'rental') return 'rent';
      if (m == 'jobs') return 'job';
      return m;
    }
    // Otherwise, map the high-level request type
    switch (_selectedType) {
      case RequestType.item:
        return 'item';
      case RequestType.rental:
        return 'rent';
      case RequestType.delivery:
        return 'delivery';
      case RequestType.ride:
        return 'ride';
      case RequestType.service:
        return null; // no specific module chosen yet
      case RequestType.price:
        return null;
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

  // Color mapping now handled by GlassTheme buttons

  String _getRequestTypeString(RequestType type) {
    switch (type) {
      case RequestType.item:
        return 'item';
      case RequestType.service:
        return 'service';
      case RequestType.delivery:
        return 'delivery';
      case RequestType.rental:
        return 'rental';
      case RequestType.ride:
        return 'ride';
      case RequestType.price:
        return 'price';
    }
  }

  Future<void> _showCategoryPicker() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => CategoryPicker(
          requestType: _getRequestTypeString(_selectedType),
          module: _selectedType == RequestType.service ? _selectedModule : null,
          scrollController: scrollController,
        ),
      ),
    );

    if (result != null && result.containsKey('category')) {
      setState(() {
        _selectedCategory = result['category'] ?? 'Electronics';
        _selectedSubcategory = result['subcategory'];
        _selectedCategoryId = result['categoryId'] ?? _selectedCategoryId;
        _selectedSubCategoryId =
            result['subcategoryId'] ?? _selectedSubcategory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: _selectedModule == 'hiring'
          ? 'Post ${_getTypeDisplayNameWithModule()}'
          : 'Create ${_getTypeDisplayNameWithModule()}',
      appBarBackgroundColor: GlassTheme.isDarkMode
          ? const Color(0x1AFFFFFF)
          : const Color(0xCCFFFFFF),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show banner for all modules/types: item, rent, delivery, ride, tours, events, construction, education, hiring, other
              if (_effectiveBannerModule() != null)
                _buildModuleBanner(_effectiveBannerModule()!),
              GlassTheme.glassCard(child: _buildTypeSpecificFields()),
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
              onPressed: _isLoading ? null : _submitRequest,
              style: GlassTheme.primaryButton,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_selectedModule == 'hiring'
                      ? 'Post ${_getTypeDisplayNameWithModule()}'
                      : 'Create ${_getTypeDisplayNameWithModule()}'),
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeDisplayNameWithModule() {
    if (_selectedType == RequestType.service && _selectedModule != null) {
      final m = _selectedModule!.toLowerCase();
      switch (m) {
        case 'item':
          return 'Item Request';
        case 'rent':
        case 'rental':
          return 'Rental Request';
        case 'delivery':
          return 'Delivery Request';
        case 'ride':
          return 'Ride Request';
        case 'tours':
          return 'Tour Request';
        case 'events':
          return 'Event Request';
        case 'construction':
          return 'Construction Request';
        case 'education':
          return 'Education Request';
        case 'hiring':
          return 'Job Request';
        case 'other':
          return 'Other Service Request';
      }
    }
    return _getTypeDisplayName(_selectedType);
  }

  Widget _buildModuleBanner(String module) {
    final info = _moduleTheme(module);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: info.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    )),
                if (info.subtitle != null)
                  Text(info.subtitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ModuleTheme _moduleTheme(String module) {
    switch (module.toLowerCase()) {
      case 'item':
        return _ModuleTheme(
          title: 'Item Request',
          subtitle: 'Buy or request items',
          icon: Icons.shopping_bag,
          gradient: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
        );
      case 'rent':
      case 'rental':
        return _ModuleTheme(
          title: 'Rental',
          subtitle: 'Rent items and equipment',
          icon: Icons.business_center,
          gradient: const [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
        );
      case 'delivery':
        return _ModuleTheme(
          title: 'Delivery',
          subtitle: 'Pickup and drop-off made easy',
          icon: Icons.local_shipping,
          gradient: const [Color(0xFFF97316), Color(0xFFF59E0B)],
        );
      case 'ride':
        return _ModuleTheme(
          title: 'Ride',
          subtitle: 'Get a driver quickly',
          icon: Icons.directions_car,
          gradient: const [Color(0xFF06B6D4), Color(0xFF22C55E)],
        );
      case 'tours':
        return _ModuleTheme(
          title: 'Tours & Travel',
          subtitle: 'Trips, packages, and activities',
          icon: Icons.flight_takeoff,
          gradient: const [Color(0xFF9333EA), Color(0xFF6366F1)],
        );
      case 'events':
        return _ModuleTheme(
          title: 'Events',
          subtitle: 'Weddings, parties, and more',
          icon: Icons.celebration,
          gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
        );
      case 'construction':
        return _ModuleTheme(
          title: 'Construction',
          subtitle: 'Builders, repairs, and renovations',
          icon: Icons.construction,
          gradient: const [Color(0xFF0EA5E9), Color(0xFF10B981)],
        );
      case 'education':
        return _ModuleTheme(
          title: 'Education',
          subtitle: 'Tutoring and training',
          icon: Icons.school,
          gradient: const [Color(0xFF22C55E), Color(0xFF06B6D4)],
        );
      case 'hiring':
        return _ModuleTheme(
          title: 'Job',
          subtitle: 'Find jobs or candidates',
          icon: Icons.work,
          gradient: const [Color(0xFF3B82F6), Color(0xFF10B981)],
        );
      case 'other':
      default:
        return _ModuleTheme(
          title: 'Other Service',
          subtitle: 'Tell us what you need',
          icon: Icons.more_horiz,
          gradient: const [Color(0xFF64748B), Color(0xFF94A3B8)],
        );
    }
  }

  Widget _buildFlatField({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: GlassTheme.glassContainerSubtle,
      child: child,
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (_selectedType) {
      case RequestType.item:
        return _buildItemFields();
      case RequestType.service:
        return _buildServiceFields();
      case RequestType.delivery:
        return _buildDeliveryFields();
      case RequestType.rental:
        return _buildRentalFields();
      case RequestType.ride:
        return const SizedBox(); // Should not reach here due to redirect above
      case RequestType.price:
        return const SizedBox(); // Should not reach here due to redirect above
    }
  }

  Widget _buildItemFields() {
    return Column(
      children: [
        // Category (Use Category Picker) – at top
        _buildFlatField(
          child: TextFormField(
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'Select a category',
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            controller: TextEditingController(
              text: _selectedSubcategory != null
                  ? '$_selectedCategory > $_selectedSubcategory'
                  : _selectedCategory,
            ),
            onTap: _showCategoryPicker,
            validator: (value) {
              if (_selectedCategory == 'Electronics' &&
                  _selectedCategoryId == null) {
                return 'Please select a category';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Request Title
        _buildFlatField(
          child: TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Request Title',
              hintText: 'Enter a short, descriptive title',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Item Name
        _buildFlatField(
          child: TextFormField(
            controller: _itemNameController,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              hintText: 'e.g., Sony PS-LX2 Turntable',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the item name';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Description
        _buildFlatField(
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Provide detailed information...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Quantity
        _buildFlatField(
          child: TextFormField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              hintText: 'How many do you need?',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the quantity';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Desired Condition
        _buildFlatField(
          child: DropdownButtonFormField<String>(
            value: _selectedCondition,
            decoration: const InputDecoration(
              labelText: 'Desired Condition',
            ),
            items: _conditions.map((condition) {
              return DropdownMenuItem<String>(
                value: condition,
                child: Text(condition),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCondition = value!;
              });
            },
          ),
        ),
        const SizedBox(height: 16),

        // Location (Use Location Picker Widget)
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              AccurateLocationPickerWidget(
                controller: _locationController,
                countryCode: CountryService.instance.countryCode,
                labelText: '',
                hintText: 'Enter item pickup location',
                isRequired: true,
                prefixIcon: Icons.location_on,
                onLocationSelected: (address, lat, lng) {
                  print('=== ITEM LOCATION CALLBACK RECEIVED ===');
                  print('Address: "$address"');
                  print('Latitude: $lat');
                  print('Longitude: $lng');
                  print('========================================');

                  setState(() {
                    _locationController.text = address;
                    _selectedLatitude = lat;
                    _selectedLongitude = lng;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Budget
        _buildFlatField(
          child: TextFormField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: CurrencyHelper.instance.getBudgetLabel(),
              hintText: 'Enter your budget range',
              prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Photo/Link
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo/Link (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload a picture of the item or provide a reference link',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ImageUploadWidget(
                uploadPath: 'request_images/items',
                onImagesChanged: (urls) {
                  setState(() {
                    _imageUrls = urls;
                  });
                },
                maxImages: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceFields() {
    return Column(
      children: [
        // Service Type (Use Category Picker)
        GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<Map<String, String>>(
              context: context,
              isScrollControlled: true,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (context, scrollController) => CategoryPicker(
                  requestType: _getRequestTypeString(_selectedType),
                  module: _selectedType == RequestType.service
                      ? _selectedModule
                      : null,
                  scrollController: scrollController,
                ),
              ),
            );

            if (result != null) {
              setState(() {
                _selectedCategory = result['category'] ?? _selectedCategory;
                _selectedSubcategory =
                    result['subcategory'] ?? _selectedSubcategory;
                _selectedCategoryId =
                    result['categoryId'] ?? _selectedCategoryId;
                _selectedSubCategoryId =
                    result['subcategoryId'] ?? _selectedSubCategoryId;
                _resetServiceDynamicFields();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Type',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_selectedCategory.isNotEmpty == true &&
                                _selectedSubcategory?.isNotEmpty == true)
                            ? '$_selectedCategory > $_selectedSubcategory'
                            : 'Select service category',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tours module: General fields at the top
        if (_selectedType == RequestType.service &&
            (_selectedModule?.toLowerCase() == 'tours')) ...[
          // Location / Destination
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location / Destination',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                AccurateLocationPickerWidget(
                  controller: _locationController,
                  countryCode: CountryService.instance.countryCode,
                  labelText: '',
                  hintText: 'Enter destination (e.g., Kandy, Ella, Yala)',
                  isRequired: true,
                  prefixIcon: Icons.location_on,
                  onLocationSelected: (address, lat, lng) {
                    setState(() {
                      _locationController.text = address;
                      _selectedLatitude = lat;
                      _selectedLongitude = lng;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Start/End Dates (date-only)
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _tourStartDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null)
                            setState(() => _tourStartDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFFF8F9FA),
                          child: Text(
                            _tourStartDate == null
                                ? 'Start Date'
                                : _formatDate(_tourStartDate!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final initial =
                              _tourEndDate ?? _tourStartDate ?? DateTime.now();
                          final date = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: _tourStartDate ?? DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => _tourEndDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFFF8F9FA),
                          child: Text(
                            _tourEndDate == null
                                ? 'End Date'
                                : _formatDate(_tourEndDate!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Number of People (Adults / Children)
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Number of People',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildCounterRow(
                    'Adults (12+)', _adults, (v) => setState(() => _adults = v),
                    min: 1),
                const SizedBox(height: 8),
                _buildCounterRow('Children (2-11)', _children,
                    (v) => setState(() => _children = v),
                    min: 0),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Events module: General fields at the top
        if (_selectedType == RequestType.service &&
            (_selectedModule?.toLowerCase() == 'events')) ...[
          // Event Location
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                AccurateLocationPickerWidget(
                  controller: _locationController,
                  countryCode: CountryService.instance.countryCode,
                  labelText: '',
                  hintText: 'Enter the event location',
                  isRequired: true,
                  prefixIcon: Icons.location_on,
                  onLocationSelected: (address, lat, lng) {
                    setState(() {
                      _locationController.text = address;
                      _selectedLatitude = lat;
                      _selectedLongitude = lng;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Event Date (date-only)
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _eventDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    color: const Color(0xFFF8F9FA),
                    child: Text(
                      _eventDate == null
                          ? 'Select event date'
                          : _formatDate(_eventDate!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Start/End Time
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                              context: context,
                              initialTime: _eventStartTime ?? TimeOfDay.now());
                          if (t != null) setState(() => _eventStartTime = t);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFFF8F9FA),
                          child: Text(
                            _eventStartTime == null
                                ? 'Start Time'
                                : _eventStartTime!.format(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                              context: context,
                              initialTime: _eventEndTime ?? TimeOfDay.now());
                          if (t != null) setState(() => _eventEndTime = t);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFFF8F9FA),
                          child: Text(
                            _eventEndTime == null
                                ? 'End Time'
                                : _eventEndTime!.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Event Type and Guests
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _eventType,
                  decoration: const InputDecoration(labelText: 'Type of Event'),
                  items: const [
                    DropdownMenuItem(value: 'Wedding', child: Text('Wedding')),
                    DropdownMenuItem(
                        value: 'Birthday', child: Text('Birthday')),
                    DropdownMenuItem(
                        value: 'Corporate', child: Text('Corporate')),
                    DropdownMenuItem(
                        value: 'Religious', child: Text('Religious')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _eventType = v ?? 'Wedding'),
                ),
                if (_eventType == 'Other')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextFormField(
                      controller: _eventOtherTypeController,
                      decoration: const InputDecoration(
                          labelText: 'Specify Event Type'),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _guestsCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Guests Count',
                    hintText: 'How many people will attend?',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Request Title
        _buildFlatField(
          child: TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Request Title',
              hintText: 'Enter a short, descriptive title',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Description (Tours: Special Requirements / Description)
        _buildFlatField(
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: (_selectedModule?.toLowerCase() == 'tours')
                  ? 'Special Requirements / Description'
                  : 'Description',
              hintText: (_selectedModule?.toLowerCase() == 'tours')
                  ? 'Any extra details (e.g., wheelchair access, child-friendly)'
                  : 'Provide detailed information about the service needed...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Location for services other than Tours/Events (handled above for those)
        if (!(_selectedType == RequestType.service &&
            (((_selectedModule?.toLowerCase() == 'tours') ||
                    (_selectedModule?.toLowerCase() == 'events')) ||
                // Hide location when Education is strictly online
                ((_selectedModule?.toLowerCase() == 'education') &&
                    _preferredEducationMode == 'Online'))))
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                AccurateLocationPickerWidget(
                  controller: _locationController,
                  countryCode: CountryService.instance.countryCode,
                  labelText: '',
                  hintText: 'Enter service location',
                  isRequired: true,
                  prefixIcon: Icons.location_on,
                  onLocationSelected: (address, lat, lng) {
                    setState(() {
                      _locationController.text = address;
                      _selectedLatitude = lat;
                      _selectedLongitude = lng;
                    });
                  },
                ),
              ],
            ),
          ),
        if (!(_selectedType == RequestType.service &&
            ((_selectedModule?.toLowerCase() == 'tours') ||
                (_selectedModule?.toLowerCase() == 'events'))))
          const SizedBox(height: 16),

        // Preferred Date & Time for modules other than Tours/Events
        if (!(_selectedType == RequestType.service &&
            ((_selectedModule?.toLowerCase() == 'tours') ||
                (_selectedModule?.toLowerCase() == 'events')))) ...[
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Date & Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _preferredDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    color: const Color(0xFFF8F9FA),
                    child: Text(
                      _preferredDateTime == null
                          ? 'Select date and time'
                          : '${_preferredDateTime!.day}/${_preferredDateTime!.month}/${_preferredDateTime!.year} at ${TimeOfDay.fromDateTime(_preferredDateTime!).format(context)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Urgency
        _buildFlatField(
          child: DropdownButtonFormField<String>(
            value: _selectedUrgency,
            decoration: const InputDecoration(
              labelText: 'Urgency',
            ),
            items: _urgencyLevels.map((urgency) {
              return DropdownMenuItem<String>(
                value: urgency,
                child: Text(urgency),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedUrgency = value!;
              });
            },
          ),
        ),
        const SizedBox(height: 16),

        // Budget
        _buildFlatField(
          child: TextFormField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: CurrencyHelper.instance.getBudgetLabel(),
              hintText: 'Enter your budget range',
              prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Photo/Video
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo/Video (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload a photo or short video to better explain the issue',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ImageUploadWidget(
                uploadPath: 'request_images/services',
                onImagesChanged: (urls) {
                  setState(() {
                    _imageUrls = urls;
                  });
                },
                maxImages: 5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Module/Subcategory-specific dynamic fields
        _buildServiceDynamicFields(),
      ],
    );
  }

  void _resetServiceDynamicFields() {
    _peopleCountController.clear();
    _durationDaysController.clear();
    _guestsCountController.clear();
    _areaSizeController.clear();
    _sessionsPerWeekController.clear();
    _studentsCountController.clear();
    _detailedNeedsController.clear();
    _subjectsController.clear();
    _syllabus = 'Local (National)';
    _syllabusOtherController.clear();
    _courseOrSkillController.clear();
    _desiredOutcomeControllerEdu.clear();
    _artOrSportController.clear();
    _classType = 'Individual';
    _targetCountryController.clear();
    _fieldOfStudyController.clear();
    _experienceYearsController.clear();
    _needsGuide = false;
    _pickupRequiredForTour = false;
    _educationLevel = 'Other';
    _preferredEducationMode = 'Online';
    _positionType = 'Full-time';
    // job request (user qualifications)
    _desiredJobTitleController.clear();
    _qualificationsController.clear();
    _salaryExpectationController.clear();
    _payPeriod = 'Monthly';
    _isSalaryNegotiable = false;
    _benefits.clear();
    _workArrangement = 'On-site';
    _educationRequirement = 'O/L';
    _skillsController.clear();
    _applyMethod = 'In-App';
    _contactPersonController.clear();
    _contactPhoneController.clear();
    _contactEmailController.clear();
    _applicationDeadline = null;
    // events
    _eventDate = null;
    _eventStartTime = null;
    _eventEndTime = null;
    _eventType = 'Wedding';
    _eventOtherTypeController.clear();
    _venueType = 'Indoor';
    _requiredFacilities.clear();
    _cuisineTypes.clear();
    _serviceStyle = 'Buffet';
    _dietaryNeedsController.clear();
    _talentType = '';
    _durationRequiredController.clear();
    _talentVenueType = 'Indoor';
    _staffType = '';
    _staffCount = 1;
    _hoursRequiredController.clear();
    _rentalItemsListController.clear();
    _rentalRequiredServices.clear();
  }

  Widget _buildServiceDynamicFields() {
    if (_selectedType != RequestType.service || _selectedModule == null) {
      return const SizedBox.shrink();
    }
    final module = _selectedModule!.toLowerCase();
    switch (module) {
      case 'tours':
        return _buildToursModuleFields();
      case 'events':
        // Category-specific fields
        final cat = _selectedCategory.toLowerCase();
        if (cat == 'venues') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlatField(
                child: DropdownButtonFormField<String>(
                  value: _venueType,
                  decoration: const InputDecoration(labelText: 'Venue Type'),
                  items: const [
                    DropdownMenuItem(value: 'Indoor', child: Text('Indoor')),
                    DropdownMenuItem(value: 'Outdoor', child: Text('Outdoor')),
                    DropdownMenuItem(
                        value: 'Poolside', child: Text('Poolside')),
                    DropdownMenuItem(value: 'Garden', child: Text('Garden')),
                    DropdownMenuItem(value: 'Hall', child: Text('Hall')),
                  ],
                  onChanged: (v) => setState(() => _venueType = v ?? 'Indoor'),
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Required Facilities'),
                    ...['AC', 'Parking', 'In-house Sound', 'Stage', 'Generator']
                        .map((f) {
                      final selected = _requiredFacilities.contains(f);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(f),
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _requiredFacilities.add(f);
                          } else {
                            _requiredFacilities.remove(f);
                          }
                        }),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        } else if (cat == 'food & beverage' || cat == 'food & beverages') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlatField(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preferred Cuisine Types'),
                    ...[
                      'Sri Lankan',
                      'Indian',
                      'Chinese',
                      'Western',
                      'BBQ',
                      'Vegan/Vegetarian'
                    ].map((c) {
                      final selected = _cuisineTypes.contains(c);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c),
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _cuisineTypes.add(c);
                          } else {
                            _cuisineTypes.remove(c);
                          }
                        }),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: DropdownButtonFormField<String>(
                  value: _serviceStyle,
                  decoration: const InputDecoration(labelText: 'Service Style'),
                  items: const [
                    DropdownMenuItem(value: 'Buffet', child: Text('Buffet')),
                    DropdownMenuItem(value: 'Plated', child: Text('Plated')),
                    DropdownMenuItem(
                        value: 'Family Style', child: Text('Family Style')),
                    DropdownMenuItem(
                        value: 'Live Stations', child: Text('Live Stations')),
                  ],
                  onChanged: (v) =>
                      setState(() => _serviceStyle = v ?? 'Buffet'),
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: TextFormField(
                  controller: _dietaryNeedsController,
                  decoration: const InputDecoration(
                    labelText: 'Dietary Requirements',
                    hintText: 'e.g., Halal, Vegan, Gluten-free',
                  ),
                ),
              ),
            ],
          );
        } else if (cat == 'entertainment & talent') {
          final defaultTalent = _selectedSubcategory ?? 'DJ';
          if (_talentType.isEmpty) _talentType = defaultTalent;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlatField(
                child: DropdownButtonFormField<String>(
                  value: _talentType,
                  decoration: const InputDecoration(labelText: 'Talent Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Photographer', child: Text('Photographer')),
                    DropdownMenuItem(
                        value: 'Videographer', child: Text('Videographer')),
                    DropdownMenuItem(value: 'DJ', child: Text('DJ')),
                    DropdownMenuItem(
                        value: 'Live Band', child: Text('Live Band')),
                    DropdownMenuItem(value: 'Dancers', child: Text('Dancers')),
                    DropdownMenuItem(
                        value: 'MC / Announcer', child: Text('MC / Announcer')),
                    DropdownMenuItem(
                        value: 'Magician / Kids Entertainer',
                        child: Text('Magician / Kids Entertainer')),
                  ],
                  onChanged: (v) =>
                      setState(() => _talentType = v ?? defaultTalent),
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: TextFormField(
                  controller: _durationRequiredController,
                  decoration: const InputDecoration(
                    labelText: 'Duration Required',
                    hintText: 'e.g., 3 hours',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: DropdownButtonFormField<String>(
                  value: _talentVenueType,
                  decoration: const InputDecoration(labelText: 'Venue Type'),
                  items: const [
                    DropdownMenuItem(value: 'Indoor', child: Text('Indoor')),
                    DropdownMenuItem(value: 'Outdoor', child: Text('Outdoor')),
                  ],
                  onChanged: (v) =>
                      setState(() => _talentVenueType = v ?? 'Indoor'),
                ),
              ),
            ],
          );
        } else if (cat == 'services & staff') {
          final defaultStaff = _selectedSubcategory ?? 'Servers / Waitstaff';
          if (_staffType.isEmpty) _staffType = defaultStaff;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlatField(
                child: DropdownButtonFormField<String>(
                  value: _staffType,
                  decoration: const InputDecoration(labelText: 'Staff Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Event Planner / Coordinator',
                        child: Text('Event Planner / Coordinator')),
                    DropdownMenuItem(
                        value: 'Decoration Services',
                        child: Text('Decoration Services')),
                    DropdownMenuItem(
                        value: 'Servers / Waitstaff',
                        child: Text('Servers / Waitstaff')),
                    DropdownMenuItem(
                        value: 'Sound & Lighting Technician',
                        child: Text('Sound & Lighting Technician')),
                    DropdownMenuItem(
                        value: 'Security Staff', child: Text('Security Staff')),
                  ],
                  onChanged: (v) =>
                      setState(() => _staffType = v ?? defaultStaff),
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: _buildCounterRow('Number of Staff', _staffCount,
                    (v) => setState(() => _staffCount = v),
                    min: 1),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: TextFormField(
                  controller: _hoursRequiredController,
                  decoration: const InputDecoration(
                    labelText: 'Hours Required',
                    hintText: 'e.g., 6 hours',
                  ),
                ),
              ),
            ],
          );
        } else if (cat == 'rentals & supplies' ||
            cat == 'rentals & supply' ||
            cat == 'rentals') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlatField(
                child: TextFormField(
                  controller: _rentalItemsListController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Items Needed',
                    hintText:
                        'List the items to rent (chairs, tables, marquee, etc.)',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatField(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Required Services'),
                    ...['Delivery & Pickup', 'On-site Setup'].map((s) {
                      final selected = _rentalRequiredServices.contains(s);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s),
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _rentalRequiredServices.add(s);
                          } else {
                            _rentalRequiredServices.remove(s);
                          }
                        }),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      case 'construction':
        return _buildConstructionModuleFields();
      case 'education':
        // Education: general + category-specific fields
        final cat = _selectedCategory.toLowerCase();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General education details
            _buildFlatField(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _educationLevel,
                    decoration: const InputDecoration(
                        labelText: "Student's Current Level"),
                    items: const [
                      DropdownMenuItem(
                          value: 'Primary (Grade 1-5)',
                          child: Text('Primary (Grade 1-5)')),
                      DropdownMenuItem(
                          value: 'Secondary (Grade 6-11 / O/L)',
                          child: Text('Secondary (Grade 6-11 / O/L)')),
                      DropdownMenuItem(
                          value: 'A/L (Advanced Level)',
                          child: Text('A/L (Advanced Level)')),
                      DropdownMenuItem(
                          value: 'Undergraduate', child: Text('Undergraduate')),
                      DropdownMenuItem(
                          value: 'Postgraduate', child: Text('Postgraduate')),
                      DropdownMenuItem(
                          value: 'Professional', child: Text('Professional')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) =>
                        setState(() => _educationLevel = v ?? 'Other'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _preferredEducationMode,
                    decoration:
                        const InputDecoration(labelText: 'Preferred Mode'),
                    items: const [
                      DropdownMenuItem(value: 'Online', child: Text('Online')),
                      DropdownMenuItem(
                          value: 'In-Person', child: Text('In-Person')),
                      DropdownMenuItem(value: 'Both', child: Text('Both')),
                    ],
                    onChanged: (v) =>
                        setState(() => _preferredEducationMode = v ?? 'Online'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _studentsCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Number of Students',
                      hintText: 'e.g., 1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sessionsPerWeekController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sessions per week',
                      hintText: 'e.g., 2',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailedNeedsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Detailed Needs',
                      hintText:
                          'Describe the specific topics, schedule, or preferences',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category-specific
            if (cat == 'academic tutoring')
              _buildFlatField(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _subjectsController,
                      decoration: const InputDecoration(
                        labelText: 'Subject(s)',
                        hintText: 'e.g., Mathematics, Science',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _syllabus,
                      decoration: const InputDecoration(labelText: 'Syllabus'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Local (National)',
                            child: Text('Local (National)')),
                        DropdownMenuItem(
                            value: 'Cambridge', child: Text('Cambridge')),
                        DropdownMenuItem(
                            value: 'Edexcel', child: Text('Edexcel')),
                        DropdownMenuItem(value: 'IB', child: Text('IB')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) =>
                          setState(() => _syllabus = v ?? _syllabus),
                    ),
                    if (_syllabus == 'Other')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextFormField(
                          controller: _syllabusOtherController,
                          decoration: const InputDecoration(
                              labelText: 'Specify Syllabus'),
                        ),
                      ),
                  ],
                ),
              )
            else if (cat == 'professional & skill development')
              _buildFlatField(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _courseOrSkillController,
                      decoration: const InputDecoration(
                        labelText: 'Specific Course/Skill',
                        hintText: 'e.g., IELTS, JavaScript, CIMA',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _desiredOutcomeControllerEdu,
                      decoration: const InputDecoration(
                        labelText: 'Desired Outcome',
                        hintText: 'e.g., Exam pass, certification, portfolio',
                      ),
                    ),
                  ],
                ),
              )
            else if (cat == 'arts & hobbies')
              _buildFlatField(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _artOrSportController,
                      decoration: const InputDecoration(
                        labelText: 'Instrument / Art Form / Sport',
                        hintText: 'e.g., Guitar, Painting, Cricket',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _classType,
                      decoration:
                          const InputDecoration(labelText: 'Class Type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Individual', child: Text('Individual')),
                        DropdownMenuItem(value: 'Group', child: Text('Group')),
                        DropdownMenuItem(
                            value: 'Workshop', child: Text('Workshop')),
                      ],
                      onChanged: (v) =>
                          setState(() => _classType = v ?? 'Individual'),
                    ),
                  ],
                ),
              )
            else if (cat == 'admissions & consulting')
              _buildFlatField(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _targetCountryController,
                      decoration: const InputDecoration(
                        labelText: 'Target Country',
                        hintText: 'e.g., UK, Canada, Japan',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fieldOfStudyController,
                      decoration: const InputDecoration(
                        labelText: 'Desired Field of Study',
                        hintText: 'e.g., Computer Science, Business',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'hiring':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Desired Job Title/Position
            _buildFlatField(
              child: TextFormField(
                controller: _desiredJobTitleController,
                decoration: const InputDecoration(
                  labelText: 'Desired Job Title',
                  hintText: 'e.g., Sales Executive, Software Developer',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Your Qualifications & Experience
            _buildFlatField(
              child: TextFormField(
                controller: _qualificationsController,
                decoration: const InputDecoration(
                  labelText: 'Your Qualifications & Experience',
                  hintText:
                      'Describe your skills, education, and work experience',
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            // Employment Type You're Looking For
            _buildFlatField(
              child: DropdownButtonFormField<String>(
                value: _positionType,
                decoration:
                    const InputDecoration(labelText: 'Employment Type Desired'),
                items: const [
                  DropdownMenuItem(
                      value: 'Full-time', child: Text('Full-time')),
                  DropdownMenuItem(
                      value: 'Part-time', child: Text('Part-time')),
                  DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                  DropdownMenuItem(
                      value: 'Freelance', child: Text('Freelance')),
                  DropdownMenuItem(
                      value: 'Internship', child: Text('Internship')),
                ],
                onChanged: (v) =>
                    setState(() => _positionType = v ?? 'Full-time'),
              ),
            ),
            const SizedBox(height: 16),
            // Work Arrangement Preference
            _buildFlatField(
              child: DropdownButtonFormField<String>(
                value: _workArrangement,
                decoration: const InputDecoration(
                    labelText: 'Work Arrangement Preference'),
                items: const [
                  DropdownMenuItem(value: 'On-site', child: Text('On-site')),
                  DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid')),
                  DropdownMenuItem(value: 'Remote', child: Text('Remote')),
                ],
                onChanged: (v) =>
                    setState(() => _workArrangement = v ?? 'On-site'),
              ),
            ),
            const SizedBox(height: 16),
            // Salary Expectation
            _buildFlatField(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _salaryExpectationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Salary Expectation',
                      prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _payPeriod,
                    decoration: const InputDecoration(labelText: 'Pay Period'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'Hourly', child: Text('Hourly')),
                    ],
                    onChanged: (v) =>
                        setState(() => _payPeriod = v ?? 'Monthly'),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Salary is negotiable'),
                    value: _isSalaryNegotiable,
                    onChanged: (v) =>
                        setState(() => _isSalaryNegotiable = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Desired Benefits
            _buildFlatField(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Desired Benefits'),
                  ...['EPF/ETF', 'Meals', 'Accommodation', 'Transport', 'OT']
                      .map((b) {
                    final selected = _benefits.contains(b);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(b),
                      value: selected,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _benefits.add(b);
                        } else {
                          _benefits.remove(b);
                        }
                      }),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Experience & Education Level
            _buildFlatField(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _experienceYearsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Years of Experience',
                      hintText: 'e.g., 3',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _educationRequirement,
                    decoration: const InputDecoration(
                        labelText: 'Your Education Level'),
                    items: const [
                      DropdownMenuItem(value: 'O/L', child: Text('O/L')),
                      DropdownMenuItem(value: 'A/L', child: Text('A/L')),
                      DropdownMenuItem(
                          value: 'Diploma', child: Text('Diploma')),
                      DropdownMenuItem(value: 'Degree', child: Text('Degree')),
                      DropdownMenuItem(
                          value: 'Postgraduate', child: Text('Postgraduate')),
                    ],
                    onChanged: (v) =>
                        setState(() => _educationRequirement = v ?? 'O/L'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Your Skills
            _buildFlatField(
              child: TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Your Key Skills (comma separated)',
                  hintText: 'e.g., Sales, Communication, Excel',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Preferred Contact Method
            _buildFlatField(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _applyMethod,
                    decoration: const InputDecoration(
                        labelText: 'Preferred Contact Method'),
                    items: const [
                      DropdownMenuItem(value: 'In-App', child: Text('In-App')),
                      DropdownMenuItem(value: 'Call', child: Text('Call')),
                      DropdownMenuItem(value: 'Email', child: Text('Email')),
                    ],
                    onChanged: (v) =>
                        setState(() => _applyMethod = v ?? 'In-App'),
                  ),
                  const SizedBox(height: 12),
                  if (_applyMethod != 'In-App') ...[
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(labelText: 'Your Name'),
                    ),
                    const SizedBox(height: 8),
                    if (_applyMethod == 'Call')
                      TextFormField(
                        controller: _contactPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Your Phone Number'),
                      ),
                    if (_applyMethod == 'Email')
                      TextFormField(
                        controller: _contactEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(labelText: 'Your Email'),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Available Start Date
            _buildFlatField(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Start Date',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _applicationDeadline ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null)
                        setState(() => _applicationDeadline = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      color: const Color(0xFFF8F9FA),
                      child: Text(
                        _applicationDeadline == null
                            ? 'Select when you can start'
                            : _formatDate(_applicationDeadline!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Map<String, dynamic> _buildModuleFieldsPayload() {
    final module = _selectedModule?.toLowerCase();
    switch (module) {
      case 'tours':
        return {
          // General (for all tours module requests)
          'startDate': _tourStartDate?.millisecondsSinceEpoch,
          'endDate': _tourEndDate?.millisecondsSinceEpoch,
          'adults': _adults,
          'children': _children,
          // Tours & Experiences specific
          if (_selectedCategory.toLowerCase() == 'tours & experiences') ...{
            'tourType': _tourType,
            'preferredLanguage': _preferredLanguage,
            'otherLanguage': _preferredLanguage == 'Other'
                ? _otherLanguageController.text.trim()
                : null,
            'timeOfDayPrefs':
                _timeOfDayPrefs.isNotEmpty ? _timeOfDayPrefs.toList() : null,
            'jeepIncluded':
                _tourType == 'Wildlife & Safari' ? _jeepIncluded : null,
            'skillLevel':
                _tourType == 'Adventure & Water Sports' ? _skillLevel : null,
          },
          // Transportation specific
          if (_selectedCategory.toLowerCase() == 'transportation') ...{
            'transportType': _transportType,
            'transportPickup': _tourPickupController.text.trim().isNotEmpty
                ? _tourPickupController.text.trim()
                : null,
            'transportDropoff': _tourDropoffController.text.trim().isNotEmpty
                ? _tourDropoffController.text.trim()
                : null,
            'vehicleTypes':
                _vehicleTypes.isNotEmpty ? _vehicleTypes.toList() : null,
            'luggage': _transportType == 'Vehicle Rental (Self-Drive)'
                ? null
                : _luggageOption,
            'itinerary': _transportType == 'Hire Driver for Tour'
                ? _itineraryController.text.trim()
                : null,
            'flightNumber': _transportType == 'Airport Transfer'
                ? _flightNumberController.text.trim()
                : null,
            'flightTime': _transportType == 'Airport Transfer'
                ? _flightTimeController.text.trim()
                : null,
            'licenseConfirmed': _transportType == 'Vehicle Rental (Self-Drive)'
                ? _licenseConfirmed
                : null,
          },
          // Accommodation specific
          if (_selectedCategory.toLowerCase() == 'accommodation') ...{
            'accommodationType': _accommodationType,
            'unitsCount': _unitsCount,
            'unitsType': _unitsType,
            'amenities': _amenities.isNotEmpty ? _amenities.toList() : null,
            'boardBasis': _boardBasis,
            'cookStaffRequired': _accommodationType == 'Villa/Bungalow'
                ? _cookStaffRequired
                : null,
            'mealsWithHostFamily': _accommodationType == 'Guesthouse/Homestay'
                ? _mealsWithHostFamily
                : null,
            'hostelRoomType':
                _accommodationType == 'Hostel' ? _hostelRoomType : null,
          },
          // Legacy simple fields kept (optional)
          'needsGuide': _needsGuide,
          'pickupRequired': _pickupRequiredForTour,
        }..removeWhere((k, v) => v == null);
      case 'events':
        String? startStr;
        String? endStr;
        if (_eventStartTime != null) {
          final h = _eventStartTime!.hour.toString().padLeft(2, '0');
          final m = _eventStartTime!.minute.toString().padLeft(2, '0');
          startStr = '$h:$m';
        }
        if (_eventEndTime != null) {
          final h = _eventEndTime!.hour.toString().padLeft(2, '0');
          final m = _eventEndTime!.minute.toString().padLeft(2, '0');
          endStr = '$h:$m';
        }
        return {
          // General
          'eventType': _eventType == 'Other'
              ? (_eventOtherTypeController.text.trim().isNotEmpty
                  ? _eventOtherTypeController.text.trim()
                  : 'Other')
              : _eventType,
          'dateOfEvent': _eventDate?.millisecondsSinceEpoch,
          'startTime': startStr,
          'endTime': endStr,
          'guestsCount': _guestsCountController.text.trim().isNotEmpty
              ? int.tryParse(_guestsCountController.text.trim())
              : null,
          // Category-specific
          if (_selectedCategory.toLowerCase() == 'venues') ...{
            'venueType': _venueType,
            'requiredFacilities': _requiredFacilities.isNotEmpty
                ? _requiredFacilities.toList()
                : null,
          },
          if (_selectedCategory.toLowerCase() == 'food & beverage' ||
              _selectedCategory.toLowerCase() == 'food & beverages') ...{
            'cuisineTypes':
                _cuisineTypes.isNotEmpty ? _cuisineTypes.toList() : null,
            'serviceStyle': _serviceStyle,
            'dietaryNeeds': _dietaryNeedsController.text.trim().isNotEmpty
                ? _dietaryNeedsController.text.trim()
                : null,
          },
          if (_selectedCategory.toLowerCase() == 'entertainment & talent') ...{
            'talentType': _talentType.isNotEmpty
                ? _talentType
                : (_selectedSubcategory ?? ''),
            'durationRequired':
                _durationRequiredController.text.trim().isNotEmpty
                    ? _durationRequiredController.text.trim()
                    : null,
            'venueType': _talentVenueType,
          },
          if (_selectedCategory.toLowerCase() == 'services & staff') ...{
            'staffType': _staffType.isNotEmpty
                ? _staffType
                : (_selectedSubcategory ?? ''),
            'numberOfStaff': _staffCount,
            'hoursRequired': _hoursRequiredController.text.trim().isNotEmpty
                ? _hoursRequiredController.text.trim()
                : null,
          },
          if (_selectedCategory.toLowerCase().startsWith('rentals')) ...{
            'itemsList': _rentalItemsListController.text.trim().isNotEmpty
                ? _rentalItemsListController.text.trim()
                : null,
            'requiredServices': _rentalRequiredServices.isNotEmpty
                ? _rentalRequiredServices.toList()
                : null,
          },
        }..removeWhere((k, v) => v == null);
      case 'construction':
        return _buildConstructionPayload();
      case 'education':
        return {
          // General education
          'studentLevel': _educationLevel,
          'preferredMode': _preferredEducationMode,
          'numberOfStudents': _studentsCountController.text.trim().isNotEmpty
              ? int.tryParse(_studentsCountController.text.trim())
              : null,
          'sessionsPerWeek': _sessionsPerWeekController.text.trim().isNotEmpty
              ? int.tryParse(_sessionsPerWeekController.text.trim())
              : null,
          'detailedNeeds': _detailedNeedsController.text.trim().isNotEmpty
              ? _detailedNeedsController.text.trim()
              : null,
          // Category-specific
          if (_selectedCategory.toLowerCase() == 'academic tutoring') ...{
            'subjects': _subjectsController.text.trim().isNotEmpty
                ? _subjectsController.text.trim()
                : null,
            'syllabus': _syllabus,
            'syllabusOther': _syllabus == 'Other'
                ? _syllabusOtherController.text.trim()
                : null,
          },
          if (_selectedCategory.toLowerCase() ==
              'professional & skill development') ...{
            'courseOrSkill': _courseOrSkillController.text.trim().isNotEmpty
                ? _courseOrSkillController.text.trim()
                : null,
            'desiredOutcome':
                _desiredOutcomeControllerEdu.text.trim().isNotEmpty
                    ? _desiredOutcomeControllerEdu.text.trim()
                    : null,
          },
          if (_selectedCategory.toLowerCase() == 'arts & hobbies') ...{
            'artOrSport': _artOrSportController.text.trim().isNotEmpty
                ? _artOrSportController.text.trim()
                : null,
            'classType': _classType,
          },
          if (_selectedCategory.toLowerCase() == 'admissions & consulting') ...{
            'targetCountry': _targetCountryController.text.trim().isNotEmpty
                ? _targetCountryController.text.trim()
                : null,
            'fieldOfStudy': _fieldOfStudyController.text.trim().isNotEmpty
                ? _fieldOfStudyController.text.trim()
                : null,
          },
        }..removeWhere((k, v) => v == null);
      case 'hiring':
        final skills = _skillsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return {
          'desiredJobTitle': _desiredJobTitleController.text.trim().isNotEmpty
              ? _desiredJobTitleController.text.trim()
              : null,
          'qualifications': _qualificationsController.text.trim().isNotEmpty
              ? _qualificationsController.text.trim()
              : null,
          'positionType': _positionType,
          'workArrangement': _workArrangement,
          'salaryExpectation':
              _salaryExpectationController.text.trim().isNotEmpty
                  ? int.tryParse(_salaryExpectationController.text.trim())
                  : null,
          'payPeriod': _payPeriod,
          'salaryNegotiable': _isSalaryNegotiable,
          'desiredBenefits': _benefits.isNotEmpty ? _benefits.toList() : null,
          'experienceYears': _experienceYearsController.text.trim().isNotEmpty
              ? int.tryParse(_experienceYearsController.text.trim())
              : null,
          'educationLevel': _educationRequirement,
          'skills': skills.isNotEmpty ? skills : null,
          'preferredContactMethod': _applyMethod,
          'contactPerson': _applyMethod != 'In-App' &&
                  _contactPersonController.text.trim().isNotEmpty
              ? _contactPersonController.text.trim()
              : null,
          'contactPhone': _applyMethod == 'Call' &&
                  _contactPhoneController.text.trim().isNotEmpty
              ? _contactPhoneController.text.trim()
              : null,
          'contactEmail': _applyMethod == 'Email' &&
                  _contactEmailController.text.trim().isNotEmpty
              ? _contactEmailController.text.trim()
              : null,
          'availabilityStartDate': _applicationDeadline?.millisecondsSinceEpoch,
        }..removeWhere((k, v) => v == null);
      default:
        return {};
    }
  }

  // Tours module UI builder
  Widget _buildToursModuleFields() {
    final cat = _selectedCategory.toLowerCase();
    if (cat == 'tours & experiences') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type of Tour
          _buildFlatField(
            child: DropdownButtonFormField<String>(
              value: _tourType,
              decoration: const InputDecoration(labelText: 'Type of Tour'),
              items: const [
                DropdownMenuItem(
                    value: 'Cultural & Heritage',
                    child: Text('Cultural & Heritage')),
                DropdownMenuItem(
                    value: 'Wildlife & Safari',
                    child: Text('Wildlife & Safari')),
                DropdownMenuItem(
                    value: 'Nature & Hiking', child: Text('Nature & Hiking')),
                DropdownMenuItem(
                    value: 'Local Experience', child: Text('Local Experience')),
                DropdownMenuItem(
                    value: 'Adventure & Water Sports',
                    child: Text('Adventure & Water Sports')),
              ],
              onChanged: (v) => setState(() => _tourType = v ?? _tourType),
            ),
          ),
          const SizedBox(height: 16),
          // Preferred Language
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _preferredLanguage,
                  decoration:
                      const InputDecoration(labelText: 'Preferred Language'),
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Sinhala', child: Text('Sinhala')),
                    DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) =>
                      setState(() => _preferredLanguage = v ?? 'English'),
                ),
                if (_preferredLanguage == 'Other')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextFormField(
                      controller: _otherLanguageController,
                      decoration:
                          const InputDecoration(labelText: 'Specify Language'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Preferred Time of Day (multi-select)
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preferred Time of Day',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ...['Morning', 'Afternoon', 'Evening', 'Full Day'].map((t) {
                  final selected = _timeOfDayPrefs.contains(t);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t),
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _timeOfDayPrefs.add(t);
                      } else {
                        _timeOfDayPrefs.remove(t);
                      }
                    }),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sub-type specific
          if (_tourType == 'Wildlife & Safari')
            _buildFlatField(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jeep Included?'),
                value: _jeepIncluded,
                onChanged: (v) => setState(() => _jeepIncluded = v ?? false),
              ),
            ),
          if (_tourType == 'Adventure & Water Sports')
            _buildFlatField(
              child: DropdownButtonFormField<String>(
                value: _skillLevel,
                decoration: const InputDecoration(labelText: 'Skill Level'),
                items: const [
                  DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                      value: 'Intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                ],
                onChanged: (v) => setState(() => _skillLevel = v ?? 'Beginner'),
              ),
            ),
        ],
      );
    } else if (cat == 'transportation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type of Transport
          _buildFlatField(
            child: DropdownButtonFormField<String>(
              value: _transportType,
              decoration: const InputDecoration(labelText: 'Type of Transport'),
              items: const [
                DropdownMenuItem(
                    value: 'Hire Driver for Tour',
                    child: Text('Hire Driver for Tour')),
                DropdownMenuItem(
                    value: 'Airport Transfer', child: Text('Airport Transfer')),
                DropdownMenuItem(
                    value: 'Vehicle Rental (Self-Drive)',
                    child: Text('Vehicle Rental (Self-Drive)')),
                DropdownMenuItem(
                    value: 'Inter-city Taxi', child: Text('Inter-city Taxi')),
              ],
              onChanged: (v) =>
                  setState(() => _transportType = v ?? _transportType),
            ),
          ),
          const SizedBox(height: 16),
          // Pickup/Dropoff Locations
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pickup Location'),
                const SizedBox(height: 6),
                AccurateLocationPickerWidget(
                  controller: _tourPickupController,
                  countryCode: CountryService.instance.countryCode,
                  labelText: '',
                  hintText: 'Enter pickup location',
                  isRequired: true,
                  prefixIcon: Icons.my_location,
                  onLocationSelected: (address, lat, lng) {
                    _tourPickupController.text = address;
                  },
                ),
                const SizedBox(height: 12),
                const Text('Drop-off Location'),
                const SizedBox(height: 6),
                AccurateLocationPickerWidget(
                  controller: _tourDropoffController,
                  countryCode: CountryService.instance.countryCode,
                  labelText: '',
                  hintText: 'Enter drop-off location',
                  isRequired: true,
                  prefixIcon: Icons.location_on,
                  onLocationSelected: (address, lat, lng) {
                    _tourDropoffController.text = address;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Vehicle Type Preference (multi-select)
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle Type Preference'),
                ...[
                  'Car (Sedan)',
                  'Van (AC)',
                  'Tuk-Tuk',
                  'Motorbike/Scooter',
                  'Luxury Vehicle'
                ].map((vtype) {
                  final selected = _vehicleTypes.contains(vtype);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(vtype),
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _vehicleTypes.add(vtype);
                      } else {
                        _vehicleTypes.remove(vtype);
                      }
                    }),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Luggage (hidden for self-drive)
          if (_transportType != 'Vehicle Rental (Self-Drive)')
            _buildFlatField(
              child: DropdownButtonFormField<String>(
                value: _luggageOption,
                decoration: const InputDecoration(labelText: 'Luggage'),
                items: const [
                  DropdownMenuItem(
                      value: 'Small Bags Only', child: Text('Small Bags Only')),
                  DropdownMenuItem(
                      value: 'Medium Suitcases',
                      child: Text('Medium Suitcases')),
                  DropdownMenuItem(
                      value: 'Large Suitcases', child: Text('Large Suitcases')),
                ],
                onChanged: (v) =>
                    setState(() => _luggageOption = v ?? _luggageOption),
              ),
            ),
          // Sub-type specifics
          if (_transportType == 'Hire Driver for Tour') ...[
            const SizedBox(height: 16),
            _buildFlatField(
              child: TextFormField(
                controller: _itineraryController,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Itinerary / Key Stops'),
              ),
            ),
          ],
          if (_transportType == 'Airport Transfer') ...[
            const SizedBox(height: 16),
            _buildFlatField(
              child: TextFormField(
                controller: _flightNumberController,
                decoration: const InputDecoration(labelText: 'Flight Number'),
              ),
            ),
            const SizedBox(height: 16),
            _buildFlatField(
              child: TextFormField(
                controller: _flightTimeController,
                decoration:
                    const InputDecoration(labelText: 'Arrival/Departure Time'),
              ),
            ),
          ],
          if (_transportType == 'Vehicle Rental (Self-Drive)') ...[
            const SizedBox(height: 16),
            _buildFlatField(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Valid International/Local License?'),
                value: _licenseConfirmed,
                onChanged: (v) =>
                    setState(() => _licenseConfirmed = v ?? false),
              ),
            ),
          ],
        ],
      );
    } else if (cat == 'accommodation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type of Accommodation
          _buildFlatField(
            child: DropdownButtonFormField<String>(
              value: _accommodationType,
              decoration:
                  const InputDecoration(labelText: 'Type of Accommodation'),
              items: const [
                DropdownMenuItem(value: 'Hotel', child: Text('Hotel')),
                DropdownMenuItem(
                    value: 'Villa/Bungalow', child: Text('Villa/Bungalow')),
                DropdownMenuItem(
                    value: 'Guesthouse/Homestay',
                    child: Text('Guesthouse/Homestay')),
                DropdownMenuItem(value: 'Eco-Lodge', child: Text('Eco-Lodge')),
                DropdownMenuItem(value: 'Hostel', child: Text('Hostel')),
              ],
              onChanged: (v) => setState(() {
                _accommodationType = v ?? _accommodationType;
                if (_accommodationType == 'Hostel') {
                  _unitsType = 'beds';
                } else {
                  _unitsType = 'rooms';
                }
              }),
            ),
          ),
          const SizedBox(height: 16),
          // Rooms/Beds counter
          _buildFlatField(
            child: _buildCounterRow(
              _unitsType == 'beds' ? 'Number of Beds' : 'Number of Rooms',
              _unitsCount,
              (v) => setState(() => _unitsCount = v),
              min: 1,
            ),
          ),
          const SizedBox(height: 16),
          // Amenities (multi-select)
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Required Amenities'),
                ...[
                  'Air Conditioning (AC)',
                  'Hot Water',
                  'Wi-Fi',
                  'Kitchen Facilities',
                  'Swimming Pool',
                  'Parking',
                ].map((a) {
                  final selected = _amenities.contains(a);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a),
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _amenities.add(a);
                      } else {
                        _amenities.remove(a);
                      }
                    }),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Board Basis
          _buildFlatField(
            child: DropdownButtonFormField<String>(
              value: _boardBasis,
              decoration: const InputDecoration(labelText: 'Board Basis'),
              items: const [
                DropdownMenuItem(value: 'Room Only', child: Text('Room Only')),
                DropdownMenuItem(
                    value: 'Bed & Breakfast', child: Text('Bed & Breakfast')),
                DropdownMenuItem(
                    value: 'Half Board', child: Text('Half Board')),
                DropdownMenuItem(
                    value: 'Full Board', child: Text('Full Board')),
              ],
              onChanged: (v) => setState(() => _boardBasis = v ?? _boardBasis),
            ),
          ),
          const SizedBox(height: 16),
          // Sub-type specifics
          if (_accommodationType == 'Villa/Bungalow')
            _buildFlatField(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cook / Staff Required?'),
                value: _cookStaffRequired,
                onChanged: (v) =>
                    setState(() => _cookStaffRequired = v ?? false),
              ),
            ),
          if (_accommodationType == 'Hostel') ...[
            _buildFlatField(
              child: DropdownButtonFormField<String>(
                value: _hostelRoomType,
                decoration: const InputDecoration(labelText: 'Room Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'Dormitory', child: Text('Dormitory')),
                  DropdownMenuItem(
                      value: 'Private Room', child: Text('Private Room')),
                ],
                onChanged: (v) =>
                    setState(() => _hostelRoomType = v ?? _hostelRoomType),
              ),
            ),
          ],
          if (_accommodationType == 'Guesthouse/Homestay')
            _buildFlatField(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Meals with Host Family?'),
                value: _mealsWithHostFamily,
                onChanged: (v) =>
                    setState(() => _mealsWithHostFamily = v ?? false),
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // Construction module UI builder
  Widget _buildConstructionModuleFields() {
    // Detect selected main category from picker
    _constructionMainCategory = _selectedCategory;
    final main = _constructionMainCategory.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // General fields (apply to all Construction requests)
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              AccurateLocationPickerWidget(
                controller: _locationController,
                countryCode: CountryService.instance.countryCode,
                labelText: '',
                hintText: 'Enter site address or drop a pin',
                isRequired: true,
                prefixIcon: Icons.location_on,
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _locationController.text = address;
                    _selectedLatitude = lat;
                    _selectedLongitude = lng;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _projectLocationNoteController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Location Notes (optional)',
                    hintText: 'Landmark, access notes...'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Project Type and Service Needed are implicitly handled by CategoryPicker selection
        _buildFlatField(
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Detailed Project Description',
                hintText: 'Describe the work and expectations...'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter a description'
                : null,
          ),
        ),
        const SizedBox(height: 16),

        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload Plans or Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ImageUploadWidget(
                uploadPath: 'request_images/construction',
                onImagesChanged: (urls) {
                  setState(() {
                    _imageUrls = urls;
                  });
                },
                maxImages: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildFlatField(
          child: TextFormField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: CurrencyHelper.instance.getBudgetLabel(),
              hintText: 'Estimated Budget (optional)',
              prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildFlatField(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _preferredDateTime = date);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF8F9FA),
              child: Text(
                _preferredDateTime == null
                    ? 'Preferred Start Date'
                    : _formatDate(_preferredDateTime!),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (main == 'new construction' ||
            main == 'renovation & remodeling') ...[
          _buildFlatField(
            child: TextFormField(
              controller: _areaSizeController,
              decoration: const InputDecoration(
                labelText: 'Property Size / Area',
                hintText: 'e.g., 1200 sqft or 10 perches',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFlatField(
            child: _buildCounterRow('Number of Floors', _numberOfFloors, (v) {
              setState(() => _numberOfFloors = v);
            }, min: 1),
          ),
          const SizedBox(height: 16),
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status of Plans'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I have approved architectural plans.'),
                  value: _plansStatus == 'approved_plans',
                  onChanged: (v) {
                    setState(
                        () => _plansStatus = v == true ? 'approved_plans' : '');
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I have a basic sketch or idea.'),
                  value: _plansStatus == 'basic_sketch',
                  onChanged: (v) {
                    setState(
                        () => _plansStatus = v == true ? 'basic_sketch' : '');
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I need design and planning help.'),
                  value: _plansStatus == 'need_design_help',
                  onChanged: (v) {
                    setState(() =>
                        _plansStatus = v == true ? 'need_design_help' : '');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (main == 'specialized trades') ...[
          _buildFlatField(
            child: DropdownButtonFormField<String>(
              value: _constructionScopeOfWork,
              decoration: const InputDecoration(labelText: 'Scope of Work'),
              items: const [
                DropdownMenuItem(
                    value: 'Labor Only (I will provide materials).',
                    child: Text('Labor Only (I will provide materials).')),
                DropdownMenuItem(
                    value: 'Labor & Materials (Provide a full quote).',
                    child: Text('Labor & Materials (Provide a full quote).')),
              ],
              onChanged: (v) => setState(() =>
                  _constructionScopeOfWork = v ?? _constructionScopeOfWork),
            ),
          ),
          const SizedBox(height: 16),
          _buildFlatField(
            child: TextFormField(
              controller: _constructionMeasurementsController,
              decoration: const InputDecoration(
                labelText: 'Approximate Measurements',
                hintText: 'e.g., 250 sq. ft. tiling; 50 ft. wall',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (main == 'material & equipment') ...[
          _buildFlatField(
            child: TextFormField(
              controller: _constructionItemsListController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'List of Items',
                hintText: 'e.g., 500 cement bricks, 1 cube of sand',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFlatField(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rental Period (if renting equipment)'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: _rentalStartDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() => _rentalStartDate = d);
                    },
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFF8F9FA),
                        child: Text(_rentalStartDate == null
                            ? 'Rental Start Date'
                            : _formatDate(_rentalStartDate!))),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: _rentalEndDate ??
                              (_rentalStartDate ?? DateTime.now()),
                          firstDate: _rentalStartDate ?? DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() => _rentalEndDate = d);
                    },
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFF8F9FA),
                        child: Text(_rentalEndDate == null
                            ? 'Rental End Date'
                            : _formatDate(_rentalEndDate!))),
                  )),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildFlatField(
            child: SwitchListTile(
              title: const Text('Delivery Required?'),
              value: _constructionDeliveryRequired,
              onChanged: (v) =>
                  setState(() => _constructionDeliveryRequired = v),
            ),
          ),
        ],

        if (main == 'consultation & design') ...[
          _buildFlatField(
            child: DropdownButtonFormField<String>(
              value: _propertyType,
              decoration: const InputDecoration(labelText: 'Type of Property'),
              items: const [
                DropdownMenuItem(
                    value: 'Residential Land', child: Text('Residential Land')),
                DropdownMenuItem(
                    value: 'Commercial Property',
                    child: Text('Commercial Property')),
              ],
              onChanged: (v) =>
                  setState(() => _propertyType = v ?? _propertyType),
            ),
          ),
          const SizedBox(height: 16),
          _buildFlatField(
            child: TextFormField(
              controller: _landSizeController,
              decoration: const InputDecoration(
                labelText: 'Land Size',
                hintText: 'in Perches or Acres',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Map<String, dynamic> _buildConstructionPayload() {
    final main = _selectedCategory; // main category name from picker
    final payload = <String, dynamic>{
      'projectLocationNote':
          _projectLocationNoteController.text.trim().isNotEmpty
              ? _projectLocationNoteController.text.trim()
              : null,
      'estimatedBudget': _budgetController.text.trim().isNotEmpty
          ? double.tryParse(_budgetController.text.trim())
          : null,
      'preferredStartDate': _preferredDateTime?.millisecondsSinceEpoch,
    };

    final lower = main.toLowerCase();
    if (lower == 'new construction' || lower == 'renovation & remodeling') {
      payload.addAll({
        'propertyArea': _areaSizeController.text.trim().isNotEmpty
            ? _areaSizeController.text.trim()
            : null,
        'numberOfFloors': _numberOfFloors,
        'plansStatus': _plansStatus.isNotEmpty ? _plansStatus : null,
      });
    } else if (lower == 'specialized trades') {
      payload.addAll({
        'scopeOfWork': _constructionScopeOfWork,
        'approxMeasurements':
            _constructionMeasurementsController.text.trim().isNotEmpty
                ? _constructionMeasurementsController.text.trim()
                : null,
      });
    } else if (lower == 'material & equipment') {
      payload.addAll({
        'itemsList': _constructionItemsListController.text.trim().isNotEmpty
            ? _constructionItemsListController.text.trim()
            : null,
        'rentalStartDate': _rentalStartDate?.millisecondsSinceEpoch,
        'rentalEndDate': _rentalEndDate?.millisecondsSinceEpoch,
        'deliveryRequired': _constructionDeliveryRequired,
      });
    } else if (lower == 'consultation & design') {
      payload.addAll({
        'propertyType': _propertyType,
        'landSize': _landSizeController.text.trim().isNotEmpty
            ? _landSizeController.text.trim()
            : null,
      });
    }

    payload.removeWhere((k, v) => v == null);
    return payload;
  }

  // Helpers
  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  Widget _buildCounterRow(String label, int value, void Function(int) onChanged,
      {int min = 0, int max = 99}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRentalFields() {
    return Column(
      children: [
        // Item to Rent (Use Category Picker) – moved to top
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Item to Rent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result =
                      await showModalBottomSheet<Map<String, String>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => SizedBox(
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: CategoryPicker(
                        requestType: _getRequestTypeString(_selectedType),
                        module: _selectedType == RequestType.service
                            ? _selectedModule
                            : null,
                        scrollController: ScrollController(),
                      ),
                    ),
                  );

                  if (result != null && result['category'] != null) {
                    setState(() {
                      _selectedCategory = result['category']!;
                      _selectedSubcategory = result['subcategory'];
                      _selectedCategoryId =
                          result['categoryId'] ?? _selectedCategoryId;
                      _selectedSubCategoryId =
                          result['subcategoryId'] ?? _selectedSubCategoryId;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedSubcategory ?? 'Select item to rent',
                        style: TextStyle(
                          color: _selectedSubcategory != null
                              ? Colors.black
                              : Colors.grey.shade600,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Request Title
        _buildFlatField(
          child: TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Request Title',
              hintText: 'Enter a short, descriptive title',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Description
        _buildFlatField(
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText:
                  'Provide detailed information about the rental needed...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Category moved to the top

        // Start Date & Time
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start Date & Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _startDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  color: const Color(0xFFF8F9FA),
                  child: Text(
                    _startDateTime == null
                        ? 'Select start date and time'
                        : '${_startDateTime!.day}/${_startDateTime!.month}/${_startDateTime!.year} at ${TimeOfDay.fromDateTime(_startDateTime!).format(context)}',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // End Date & Time
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'End Date & Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDateTime ?? DateTime.now(),
                    firstDate: _startDateTime ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _endDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  color: const Color(0xFFF8F9FA),
                  child: Text(
                    _endDateTime == null
                        ? 'Select end date and time'
                        : '${_endDateTime!.day}/${_endDateTime!.month}/${_endDateTime!.year} at ${TimeOfDay.fromDateTime(_endDateTime!).format(context)}',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Location (Use Location Picker)
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              AccurateLocationPickerWidget(
                controller: _locationController,
                labelText: '',
                hintText: 'Enter rental pickup location',
                isRequired: true,
                prefixIcon: Icons.location_on,
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _locationController.text = address;
                    _selectedLatitude = lat;
                    _selectedLongitude = lng;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Budget
        _buildFlatField(
          child: TextFormField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Budget (per day/hour)',
              hintText: 'Enter your budget',
              prefixText: CurrencyHelper.instance.getCurrencyPrefix(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pickup / Dropoff
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pickup/Dropoff Preference',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _pickupDropoffPreference,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(
                      value: 'pickup', child: Text('I will pickup')),
                  DropdownMenuItem(
                      value: 'delivery', child: Text('Please deliver')),
                  DropdownMenuItem(
                      value: 'flexible', child: Text('Either option works')),
                ],
                onChanged: (value) {
                  setState(() {
                    _pickupDropoffPreference = value!;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Photo/Link
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo/Link (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload photo or share link of similar item you want to rent',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ImageUploadWidget(
                uploadPath: 'request_images/rentals',
                onImagesChanged: (urls) {
                  setState(() {
                    _imageUrls = urls;
                  });
                },
                maxImages: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryFields() {
    return Column(
      children: [
        // Item Categories (Use Category Picker) – at top
        _buildFlatField(
          child: GestureDetector(
            onTap: () async {
              final result = await showModalBottomSheet<Map<String, String>>(
                context: context,
                isScrollControlled: true,
                builder: (context) => DraggableScrollableSheet(
                  expand: false,
                  builder: (context, scrollController) => CategoryPicker(
                    requestType: _getRequestTypeString(_selectedType),
                    module: _selectedType == RequestType.service
                        ? _selectedModule
                        : null,
                    scrollController: scrollController,
                  ),
                ),
              );

              if (result != null) {
                setState(() {
                  _selectedCategory = result['category'] ?? _selectedCategory;
                  _selectedSubcategory =
                      result['subcategory'] ?? _selectedSubcategory;
                  _selectedCategoryId =
                      result['categoryId'] ?? _selectedCategoryId;
                  _selectedSubCategoryId =
                      result['subcategoryId'] ?? _selectedSubCategoryId;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedSubcategory ?? 'Select item category',
                    style: TextStyle(
                      color: _selectedSubcategory != null
                          ? Colors.black
                          : Colors.grey.shade600,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Request Title
        _buildFlatField(
          child: TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Request Title',
              hintText: 'Enter a short, descriptive title',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Pickup Location
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pickup Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              AccurateLocationPickerWidget(
                controller: _pickupLocationController,
                labelText: '',
                hintText: 'Enter pickup location',
                isRequired: true,
                prefixIcon: Icons.my_location,
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _pickupLocationController.text = address;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Drop-off Location
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Drop-off Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              AccurateLocationPickerWidget(
                controller: _dropoffLocationController,
                labelText: '',
                hintText: 'Enter drop-off location',
                isRequired: true,
                prefixIcon: Icons.location_on,
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _dropoffLocationController.text = address;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Item Description
        _buildFlatField(
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Item Description',
              hintText: 'Describe what needs to be delivered...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please describe the item(s)';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Weight & Dimensions
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weight & Dimensions (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Weight (kg)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dimensionsController,
                      decoration: const InputDecoration(
                        hintText: 'Dimensions (L x W x H)',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Preferred Delivery Time
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preferred Delivery Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _preferredDeliveryTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  color: const Color(0xFFF8F9FA),
                  child: Text(
                    _preferredDeliveryTime == null
                        ? 'Select preferred delivery time'
                        : '${_preferredDeliveryTime!.day}/${_preferredDeliveryTime!.month}/${_preferredDeliveryTime!.year} at ${TimeOfDay.fromDateTime(_preferredDeliveryTime!).format(context)}',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Special Instructions
        _buildFlatField(
          child: TextFormField(
            controller: _specialInstructionsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Special Instructions (Optional)',
              hintText: 'Any special handling requirements, access codes, etc.',
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Photo Upload
        _buildFlatField(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo Upload (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload photos of items to be delivered',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ImageUploadWidget(
                uploadPath: 'request_images/deliveries',
                onImagesChanged: (urls) {
                  setState(() {
                    _imageUrls = urls;
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

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for category selection based on request type
    if ((_selectedType == RequestType.service ||
            _selectedType == RequestType.delivery ||
            _selectedType == RequestType.rental) &&
        (_selectedCategoryId == null || _selectedCategoryId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a ${_selectedType.name} category'),
          backgroundColor: Colors.red,
        ),
      );
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

      // Debug log location data before creating request
      print('=== LOCATION DEBUG BEFORE CREATE ===');
      print('_locationController.text: "${_locationController.text}"');
      print('_selectedLatitude: $_selectedLatitude');
      print('_selectedLongitude: $_selectedLongitude');
      print('=====================================');

      // Create request using the service method
      LocationInfo? locationInfo;
      if (_locationController.text.trim().isNotEmpty) {
        if (_selectedLatitude != null && _selectedLongitude != null) {
          locationInfo = LocationInfo(
            address: _locationController.text.trim(),
            latitude: _selectedLatitude!,
            longitude: _selectedLongitude!,
          );
        } else {
          // Create location with just address if coordinates are not available
          locationInfo = LocationInfo(
            address: _locationController.text.trim(),
            latitude: 0.0, // Default coordinates
            longitude: 0.0,
          );
        }
      }

      print('=== FINAL LOCATION INFO ===');
      print('locationInfo: $locationInfo');
      if (locationInfo != null) {
        print('locationInfo.address: "${locationInfo.address}"');
        print('locationInfo.latitude: ${locationInfo.latitude}');
        print('locationInfo.longitude: ${locationInfo.longitude}');
      }
      print('===========================');

      await _requestService.createRequestCompat(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        location: locationInfo,
        budget: _budgetController.text.trim().isNotEmpty
            ? double.tryParse(_budgetController.text.trim())
            : null,
        images: _imageUrls,
        typeSpecificData: _getTypeSpecificData(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedModule == 'hiring'
                ? '${_getTypeDisplayNameWithModule()} posted successfully!'
                : '${_getTypeDisplayNameWithModule()} created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getTypeSpecificData() {
    switch (_selectedType) {
      case RequestType.item:
        return {
          'itemName': _itemNameController.text.trim(),
          'category': _selectedCategory,
          'categoryId': _selectedCategoryId ?? '',
          'subCategoryId': _selectedSubCategoryId ?? '',
          'subcategory': _selectedSubcategory ?? '',
          'quantity': int.tryParse(_quantityController.text.trim()),
          'condition': _selectedCondition,
        };
      case RequestType.service:
        return {
          'serviceType': (_selectedSubcategory?.isNotEmpty == true)
              ? _selectedSubcategory
              : _selectedCategory,
          // module/subtype hint for backend routing/analytics
          'module': _selectedModule,
          'categoryId': _selectedCategoryId ?? '',
          'subCategoryId': _selectedSubCategoryId ?? '',
          'category': _selectedCategory,
          'subcategory': _selectedSubcategory,
          'preferredDateTime': _preferredDateTime?.millisecondsSinceEpoch,
          'urgency': _selectedUrgency,
          'moduleFields': _buildModuleFieldsPayload(),
        };
      case RequestType.delivery:
        return {
          'pickupLocation': _pickupLocationController.text.trim(),
          'dropoffLocation': _dropoffLocationController.text.trim(),
          'itemCategory': _selectedCategory.trim(),
          'category': _selectedCategory.trim(),
          'categoryId': _selectedCategoryId?.trim() ?? '',
          'subcategory': _selectedSubcategory?.trim(),
          'subcategoryId': _selectedSubCategoryId?.trim() ?? '',
          'itemDescription': _descriptionController.text.trim(),
          'weight': _weightController.text.trim().isNotEmpty
              ? double.tryParse(_weightController.text.trim())
              : null,
          'dimensions': _dimensionsController.text.trim(),
          'preferredDeliveryTime':
              _preferredDeliveryTime?.millisecondsSinceEpoch,
          'specialInstructions': _specialInstructionsController.text.trim(),
        };
      case RequestType.rental:
        return {
          'itemToRent': _rentalItemController.text.trim(),
          'category': _selectedCategory,
          'categoryId': _selectedCategoryId ?? '',
          'subCategoryId': _selectedSubCategoryId ?? '',
          'subcategory': _selectedSubcategory ?? '',
          'startDate': _startDateTime?.millisecondsSinceEpoch,
          'endDate': _endDateTime?.millisecondsSinceEpoch,
          'pickupDropoffPreference': _pickupDropoffPreference,
        };
      default:
        return {};
    }
  }
}

class _ModuleTheme {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradient;
  const _ModuleTheme({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.gradient,
  });
}
