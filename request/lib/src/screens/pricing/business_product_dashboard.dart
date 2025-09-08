import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/pricing_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/file_upload_service.dart';
import '../../services/api_client.dart';
import '../../services/rest_auth_service.dart';
import '../../theme/glass_theme.dart';
import '../../services/user_registration_service.dart';

class BusinessProductDashboard extends StatefulWidget {
  const BusinessProductDashboard({super.key});

  @override
  State<BusinessProductDashboard> createState() =>
      _BusinessProductDashboardState();
}

class _BusinessProductDashboardState extends State<BusinessProductDashboard> {
  final PricingService _pricingService = PricingService();
  final EnhancedUserService _userService = EnhancedUserService();
  final FileUploadService _fileUploadService = FileUploadService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _countryProducts = [];
  List<dynamic> _myPriceListings = [];
  List<dynamic> _countryVariables =
      []; // Available variables from country table
  bool _isSearching = false;
  bool _isLoadingMyPrices = false;
  bool _isSaving = false; // Add loading state for save operations
  bool _isSeller = true; // gated after registration check

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print('DEBUG: Starting _loadData()...');

    // Determine if user is an approved business (seller)
    try {
      print('DEBUG: Checking user business registration...');
      final regs =
          await UserRegistrationService.instance.getUserRegistrations();
      _isSeller = regs?.isApprovedBusiness == true;
      print('DEBUG: User is seller: $_isSeller');
    } catch (e) {
      print('DEBUG: Error checking business registration: $e');
      _isSeller = false;
    }

    if (!_isSeller) {
      print(
          'DEBUG: User is not an approved business, showing registration prompt');
      setState(() {});
      return;
    }

    print('DEBUG: Loading data for approved business...');
    try {
      await Future.wait([
        _loadCountryProducts(),
        _loadMyPriceListings(),
        _loadCountryVariables(),
      ]).timeout(const Duration(seconds: 30));
      print('DEBUG: All data loaded successfully');
    } catch (e) {
      print('DEBUG: Error loading data: $e');
      // Continue anyway, individual methods have their own error handling
    }
  }

  Future<void> _loadCountryProducts() async {
    setState(() => _isSearching = true);
    try {
      // Use getAllCountryProducts for loading all available products to add prices for
      final products =
          await _pricingService.getAllCountryProducts(query: '', limit: 50);
      setState(() {
        _countryProducts = products;
        _isSearching = false;
      });
    } catch (e) {
      print('Error loading country products: $e');
      setState(() => _isSearching = false);
    }
  }

  Future<void> _loadMyPriceListings() async {
    setState(() => _isLoadingMyPrices = true);
    try {
      // Get the correct database user ID from the authenticated user
      String? userId = RestAuthService.instance.currentUser?.id;

      if (userId == null) {
        // Fallback to enhanced user service
        final authUser = _userService.currentUser;
        userId = authUser?.id;
        print('DEBUG: Got user ID from enhanced user service: $userId');
      }

      if (userId == null) {
        print('DEBUG: No user logged in, skipping price listings load');
        setState(() => _isLoadingMyPrices = false);
        return;
      }

      print('DEBUG: Loading price listings for user: $userId');
      await for (final listings
          in _pricingService.getBusinessPriceListings(userId).take(1)) {
        print('DEBUG: Loaded ${listings.length} price listings');

        // Debug staging status for each listing
        for (var listing in listings) {
          print(
              'DEBUG: Listing ${listing.productName} - hasPendingChanges: ${listing.hasPendingChanges}, stagingStatus: ${listing.stagingStatus}, price: ${listing.price}');
        }

        setState(() {
          _myPriceListings = listings;
          _isLoadingMyPrices = false;
        });
        break;
      }
    } catch (e) {
      print('Error loading my price listings: $e');
      setState(() => _isLoadingMyPrices = false);
    }
  }

  Future<void> _loadCountryVariables() async {
    print('DEBUG: Starting to load country variables...');
    try {
      // Get country variables from the backend
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        '/api/country-variable-types', // API endpoint for country variables
        queryParameters: {
          'country': 'LK', // Pass country code as query parameter
        },
      );

      print('DEBUG: API response success: ${response.isSuccess}');
      print('DEBUG: API response data: ${response.data}');

      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;
        final variablesArray = responseData['data'] as List<dynamic>?;

        print('DEBUG: Variables array length: ${variablesArray?.length}');

        if (variablesArray != null) {
          setState(() {
            _countryVariables = variablesArray.map((variable) {
              return {
                'id': variable['id'],
                'name': variable['name'],
                'type': variable['type'],
                'values': List<String>.from(variable['possibleValues'] ?? []),
                'description': variable['description'],
                'country_code': variable['country_code'],
                'is_active': variable['is_active'],
                'required': variable['required'] ?? false,
              };
            }).toList();
          });

          print('DEBUG: Loaded ${_countryVariables.length} country variables');
          print(
              'DEBUG: Variables: ${_countryVariables.map((v) => v['name']).join(', ')}');
        } else {
          print('DEBUG: Variables array is null');
        }
      } else {
        print('Failed to load country variables: ${response.error}');
        // Fallback to sample data if API fails
        _loadFallbackVariables();
      }
    } catch (e) {
      print('Error loading country variables: $e');
      // Fallback to sample data if API fails
      _loadFallbackVariables();
    }

    // Temporary: Always load fallback for testing
    if (_countryVariables.isEmpty) {
      print('DEBUG: No variables loaded from API, using fallback');
      _loadFallbackVariables();
    }
  }

  void _loadFallbackVariables() {
    setState(() {
      _countryVariables = [
        {
          'id': '1',
          'name': 'Color',
          'type': 'select',
          'values': ['Red', 'Blue', 'Green', 'Black', 'White', 'Yellow']
        },
        {
          'id': '2',
          'name': 'Size',
          'type': 'select',
          'values': ['XS', 'S', 'M', 'L', 'XL', 'XXL']
        },
        {
          'id': '3',
          'name': 'Material',
          'type': 'select',
          'values': ['Cotton', 'Polyester', 'Silk', 'Wool', 'Leather']
        },
        {'id': '4', 'name': 'Brand', 'type': 'text', 'values': []}
      ];
    });
  }

  Future<void> _searchProducts() async {
    if (_searchController.text.trim().isEmpty) {
      _loadCountryProducts();
      return;
    }

    setState(() => _isSearching = true);
    try {
      // Use getAllCountryProducts for searching all available products
      final products = await _pricingService.getAllCountryProducts(
        query: _searchController.text.trim(),
        limit: 50,
      );
      setState(() {
        _countryProducts = products;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching products: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSeller) {
      return Container(
        decoration: GlassTheme.backgroundGradient,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: GlassTheme.colors.textPrimary,
            title: Text('Product Dashboard', style: GlassTheme.titleLarge),
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    decoration: GlassTheme.glassContainer,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 72,
                          color: GlassTheme.colors.warningColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Become a verified business to add prices',
                          style: GlassTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Submit your business verification. Once approved, you can add and manage your product prices.',
                          style: GlassTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(
                                context, '/business-registration'),
                            style: GlassTheme.primaryButton,
                            child: const Text('Register Business'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: GlassTheme.backgroundGradient,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: GlassTheme.colors.textPrimary,
            title: Text('Find Products', style: GlassTheme.titleLarge),
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () async {
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data refreshed'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh data',
              ),
            ],
            bottom: TabBar(
              labelColor: GlassTheme.colors.textPrimary,
              unselectedLabelColor: GlassTheme.colors.textSecondary,
              tabs: const [
                Tab(text: 'Add Prices'),
                Tab(text: 'My Prices'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildAddPricesTab(),
              _buildMyPricesTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPricesTab() {
    return Column(
      children: [
        _buildSearchSection(),
        Expanded(child: _buildProductsList()),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Search products to add your prices',
              style: GlassTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Find requests by skill, item, or service',
              hintStyle: TextStyle(color: GlassTheme.colors.textSecondary),
              prefixIcon:
                  Icon(Icons.search, color: GlassTheme.colors.textTertiary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadCountryProducts();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black12.withOpacity(0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black26.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black12.withOpacity(0.05)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {});
              // Live search with debounce
              if (value.length >= 2) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _searchProducts();
                  }
                });
              } else if (value.isEmpty) {
                _loadCountryProducts();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_countryProducts.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: GlassTheme.glassContainer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 56, color: GlassTheme.colors.textTertiary),
              const SizedBox(height: 12),
              Text('No products found', style: GlassTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Try another keyword.',
                style: GlassTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _countryProducts.length,
      itemBuilder: (context, index) {
        final product = _countryProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(dynamic product) {
    final name = product.name ?? 'Unknown Product';
    final brand = product.brand ?? '';
    final hasExistingPrice = _myPriceListings
        .any((listing) => listing.masterProductId == product.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: GlassTheme.glassContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GlassTheme.titleSmall,
                  ),
                  if (brand.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      brand,
                      style: GlassTheme.bodyMedium,
                    ),
                  ],
                  if (hasExistingPrice) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: GlassTheme.colors.successColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'PRICE ADDED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _addEditPrice(product),
              style: GlassTheme.primaryButton.copyWith(
                backgroundColor: WidgetStatePropertyAll(
                  hasExistingPrice
                      ? GlassTheme.colors.warningColor
                      : GlassTheme.colors.primaryBlue,
                ),
              ),
              child: Text(hasExistingPrice ? 'Edit Price' : 'Add Price'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPricesTab() {
    if (_isLoadingMyPrices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myPriceListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.price_check_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No prices added yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add prices for products to start selling',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myPriceListings.length,
      itemBuilder: (context, index) {
        final listing = _myPriceListings[index];
        return _buildMyPriceCard(listing);
      },
    );
  }

  Widget _buildMyPriceCard(dynamic listing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: GlassTheme.glassContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.productName ?? 'Product',
                    style: GlassTheme.titleSmall,
                  ),
                  if (listing.brand?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      listing.brand,
                      style: GlassTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${listing.currency ?? 'LKR'} ${listing.price?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlassTheme.colors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: listing.hasPendingChanges
                            ? GlassTheme.colors.warningColor // pending
                            : (listing.isAvailable == true
                                ? GlassTheme.colors.successColor
                                : GlassTheme.colors.errorColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        listing.hasPendingChanges
                            ? 'PENDING'
                            : (listing.isAvailable == true
                                ? 'LIVE'
                                : 'INACTIVE'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: () => _editPrice(listing),
                        icon: const Icon(Icons.edit, size: 16),
                        color: GlassTheme.colors.primaryBlue,
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: () => _toggleActiveStatus(listing),
                        icon: Icon(
                            listing.isAvailable
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 16),
                        color: listing.isAvailable
                            ? GlassTheme.colors.warningColor
                            : GlassTheme.colors.successColor,
                        tooltip:
                            listing.isAvailable ? 'Deactivate' : 'Activate',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: () => _permanentlyDeletePrice(listing),
                        icon: const Icon(Icons.delete_forever, size: 16),
                        color: GlassTheme.colors.errorColor,
                        tooltip: 'Delete Permanently',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addEditPrice(dynamic product) {
    _showPriceDialog(product: product);
  }

  void _editPrice(dynamic listing) {
    print('DEBUG: Editing price listing: ${listing.id}');
    print('DEBUG: Existing selectedVariables: ${listing.selectedVariables}');
    print('DEBUG: Existing subcategory: ${listing.subcategory}');
    _showPriceDialog(existingListing: listing);
  }

  void _showPriceDialog({dynamic product, dynamic existingListing}) {
    print(
        'DEBUG: Opening price dialog, country variables count: ${_countryVariables.length}');
    print(
        'DEBUG: Country variables: ${_countryVariables.map((v) => v['name']).join(', ')}');

    final isEditing = existingListing != null;
    final TextEditingController priceController = TextEditingController(
      text: isEditing ? existingListing.price?.toString() ?? '' : '',
    );
    final TextEditingController whatsappController = TextEditingController(
      text: isEditing ? existingListing.whatsappNumber ?? '' : '',
    );
    final TextEditingController websiteController = TextEditingController(
      text: isEditing ? existingListing.productLink ?? '' : '',
    );
    final TextEditingController qtyController = TextEditingController(
      text: isEditing ? existingListing.stockQuantity?.toString() ?? '1' : '1',
    );
    final TextEditingController modelController = TextEditingController(
      text: isEditing ? existingListing.modelNumber ?? '' : '',
    );

    List<File> selectedImages = [];
    List<String> existingImageUrls =
        isEditing ? List<String>.from(existingListing.productImages ?? []) : [];

    // Track selected variables for two-step selection
    Map<String, bool> enabledVariables = {};
    Map<String, String> selectedVariableValues = isEditing
        ? Map<String, String>.from(existingListing.selectedVariables ?? {})
        : {};

    print('DEBUG: selectedVariableValues loaded: $selectedVariableValues');

    // Initialize enabled variables based on existing selections
    if (isEditing && selectedVariableValues.isNotEmpty) {
      print('DEBUG: Initializing enabled variables from existing data');
      for (var variable in _countryVariables) {
        final variableName = variable['name'];
        enabledVariables[variableName] =
            selectedVariableValues.containsKey(variableName);
        print(
            'DEBUG: Variable $variableName enabled: ${enabledVariables[variableName]}');
      }
    } else {
      print('DEBUG: No existing variable values to load');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Price' : 'Add Price',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Product name
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isEditing
                              ? existingListing.productName ?? 'Product'
                              : product?.name ?? 'Product',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Price and Quantity Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Price (LKR) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.inventory),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Model Number
                      TextField(
                        controller: modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model Number (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.model_training),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Two-Step Variable Selection
                      // Temporarily always show variables for debugging
                      if (true) ...[
                        Text(
                          'Product Variables (${_countryVariables.length} available)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Debug info
                        if (_countryVariables.isEmpty) ...[
                          const Text(
                            'DEBUG: No variables loaded - forcing fallback',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setDialogState(() {
                                _countryVariables = [
                                  {
                                    'id': '1',
                                    'name': 'Color',
                                    'type': 'select',
                                    'values': [
                                      'Red',
                                      'Blue',
                                      'Green',
                                      'Black',
                                      'White'
                                    ]
                                  },
                                  {
                                    'id': '2',
                                    'name': 'Size',
                                    'type': 'select',
                                    'values': ['XS', 'S', 'M', 'L', 'XL']
                                  },
                                ];
                              });
                            },
                            child: const Text('Load Test Variables'),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Show variables if available
                        if (_countryVariables.isNotEmpty) ...[
                          // Step 1: Select which variables to use
                          const Text(
                            'Step 1: Select which variables you want to specify',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Compact variable selection using chips
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _countryVariables.map((variable) {
                              final variableName = variable['name'];
                              final isSelected =
                                  enabledVariables[variableName] ?? false;

                              return FilterChip(
                                label: Text(
                                  variableName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (bool selected) {
                                  setDialogState(() {
                                    enabledVariables[variableName] = selected;
                                    if (!selected) {
                                      // Remove value when variable is disabled
                                      selectedVariableValues
                                          .remove(variableName);
                                    }
                                  });
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.blue,
                                checkmarkColor: Colors.white,
                                side: BorderSide.none, // Remove border
                                elevation: 0, // Remove shadow for flatter look
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),

                          // Step 2: Select values for enabled variables
                          if (enabledVariables.values
                              .any((enabled) => enabled)) ...[
                            const Text(
                              'Step 2: Select values for chosen variables',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._countryVariables.where((variable) {
                              final variableName = variable['name'];
                              return enabledVariables[variableName] ?? false;
                            }).map((variable) {
                              final variableName = variable['name'];
                              final variableType = variable['type'];
                              final variableValues =
                                  List<String>.from(variable['values'] ?? []);

                              if (variableType == 'text') {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: variableName,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      selectedVariableValues[variableName] =
                                          value;
                                    },
                                    controller: TextEditingController(
                                      text: selectedVariableValues[
                                              variableName] ??
                                          '',
                                    ),
                                  ),
                                );
                              } else {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DropdownButtonFormField<String>(
                                    value: selectedVariableValues[variableName],
                                    decoration: InputDecoration(
                                      labelText: variableName,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('Select $variableName'),
                                      ),
                                      ...variableValues
                                          .map<DropdownMenuItem<String>>(
                                              (value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value != null && value.isNotEmpty) {
                                          selectedVariableValues[variableName] =
                                              value;
                                        } else {
                                          selectedVariableValues
                                              .remove(variableName);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }
                            }).toList(),
                          ],
                          const SizedBox(height: 16),
                        ], // Close the inner if (_countryVariables.isNotEmpty)
                      ], // Close the outer if (true)

                      // Contact Information Section
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // WhatsApp number
                      TextField(
                        controller: whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Number (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '+94xxxxxxxxx',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Website/Product link
                      TextField(
                        controller: websiteController,
                        decoration: const InputDecoration(
                          labelText: 'Website/Product Link (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Images section
                      const Text(
                        'Product Images',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Show existing images
                      if (existingImageUrls.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: existingImageUrls
                              .map((url) => Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          image: DecorationImage(
                                            image: NetworkImage(url),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              existingImageUrls.remove(url);
                                            });
                                          },
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Show selected new images
                      if (selectedImages.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedImages
                              .map((file) => Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          image: DecorationImage(
                                            image: FileImage(file),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              selectedImages.remove(file);
                                            });
                                          },
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Add image button
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() {
                              selectedImages.add(File(image.path));
                            });
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Image'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Bottom buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  try {
                                    await _savePrice(
                                      product: product,
                                      existingListing: existingListing,
                                      price: priceController.text,
                                      whatsapp: whatsappController.text,
                                      website: websiteController.text,
                                      quantity: qtyController.text,
                                      modelNumber: modelController.text,
                                      variables: selectedVariableValues,
                                      newImages: selectedImages,
                                      existingImages: existingImageUrls,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  } finally {
                                    if (mounted)
                                      setState(() => _isSaving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlassTheme.colors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(isEditing ? 'Update Price' : 'Save Price'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _savePrice({
    dynamic product,
    dynamic existingListing,
    required String price,
    required String whatsapp,
    required String website,
    required String quantity,
    required String modelNumber,
    required Map<String, String> variables,
    required List<File> newImages,
    required List<String> existingImages,
  }) async {
    if (price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Upload new images
      List<String> imageUrls = List.from(existingImages);
      for (final imageFile in newImages) {
        final imageUrl = await _fileUploadService.uploadFile(
          imageFile,
          path: 'price_listings/${DateTime.now().millisecondsSinceEpoch}',
        );
        imageUrls.add(imageUrl);
      }

      // Create API payload
      final apiPayload = {
        'masterProductId': existingListing?.masterProductId ?? product.id,
        'title': existingListing?.productName ?? product.name,
        'price': double.parse(price),
        'currency': 'LKR',
        'countryCode': 'LK',
        'categoryId': '732f29d3-637b-4c20-9c6d-e90f472143f7', // Electronics
        'subCategoryId': existingListing?.subcategory ??
            product.subcategory ??
            '6a8b9c2d-e3f4-5678-9abc-def123456789', // Default subcategory
        'images': imageUrls,
        'stockQuantity': int.tryParse(quantity) ?? 1,
        if (modelNumber.isNotEmpty) 'modelNumber': modelNumber,
        if (variables.isNotEmpty) 'selectedVariables': variables,
        if (whatsapp.isNotEmpty) 'whatsapp': whatsapp,
        if (website.isNotEmpty) 'website': website,
        // Add listing ID for updates
        if (existingListing != null) 'id': existingListing.id,
      };

      print('DEBUG: API payload: $apiPayload');

      bool success;
      String successMessage;

      if (existingListing != null) {
        // For existing listings, use staging system
        final stagingData = {
          'price': double.parse(price),
          'stockQuantity': int.tryParse(quantity) ?? 1,
          'isAvailable': true,
          if (whatsapp.isNotEmpty) 'whatsappNumber': whatsapp,
          if (website.isNotEmpty) 'productLink': website,
          if (modelNumber.isNotEmpty) 'modelNumber': modelNumber,
          if (variables.isNotEmpty) 'selectedVariables': variables,
        };

        success = await _pricingService.stagePriceUpdate(
            existingListing.id, stagingData);
        successMessage = success
            ? 'Price staged successfully! Will be applied at 1 AM daily update.'
            : 'Failed to stage price update';
      } else {
        // For new listings, create directly
        success = await _pricingService.addOrUpdatePriceListing(apiPayload);
        successMessage =
            success ? 'Price added successfully!' : 'Failed to add price';
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        await _loadData(); // Refresh data
      } else {
        throw Exception(successMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving price: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleActiveStatus(dynamic listing) async {
    final action = listing.isAvailable ? 'deactivate' : 'activate';
    final actionCapitalized = action[0].toUpperCase() + action.substring(1);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionCapitalized Price Listing'),
        content: Text(
            'Are you sure you want to $action "${listing.productName}"?\n\n'
            '${listing.isAvailable ? "This will hide the listing from public view but keep it in your account." : "This will make the listing visible to customers again."}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor:
                    listing.isAvailable ? Colors.orange : Colors.green),
            child: Text(actionCapitalized),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await _pricingService.togglePriceListingStatus(listing.id);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Price listing ${action}d successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to $action price listing'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Refresh data to show updated status
        await _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        await _loadData();
      }
    }
  }

  Future<void> _permanentlyDeletePrice(dynamic listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete Price Listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to permanently delete "${listing.productName}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('Warning:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          )),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                      'This action cannot be undone. The listing will be completely removed from the database.'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await _pricingService.permanentlyDeletePriceListing(listing.id);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Price listing permanently deleted'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete price listing'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Refresh data to remove deleted listing
        await _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        await _loadData();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
