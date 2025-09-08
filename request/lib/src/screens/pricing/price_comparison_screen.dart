import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/price_listing.dart';
import '../../services/pricing_service.dart';
import '../../services/payment_methods_service.dart';
import '../../services/s3_image_upload_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass_theme.dart';

class PriceComparisonScreen extends StatefulWidget {
  const PriceComparisonScreen({super.key});

  @override
  State<PriceComparisonScreen> createState() => _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  final PricingService _pricingService = PricingService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _products = [];
  List<PriceListing> _priceListings = [];
  bool _isSearching = false;
  bool _isLoadingPrices = false;
  String? _selectedProductId;
  String? _selectedProductName;

  @override
  void initState() {
    super.initState();
    _loadPopularProducts();
  }

  Future<void> _loadPopularProducts() async {
    setState(() => _isSearching = true);
    try {
      final products =
          await _pricingService.searchProducts(query: '', limit: 20);
      setState(() {
        _products = products;
        _isSearching = false;
      });
    } catch (e) {
      print('Error loading popular products: $e');
      setState(() => _isSearching = false);
    }
  }

  Future<void> _searchProducts([String? query]) async {
    final searchQuery = query ?? _searchController.text.trim();
    if (searchQuery.isEmpty) {
      _loadPopularProducts();
      return;
    }

    setState(() => _isSearching = true);
    try {
      final products = await _pricingService.searchProducts(
        query: searchQuery,
        limit: 50,
      );
      setState(() {
        _products = products;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching products: $e');
      setState(() => _isSearching = false);
    }
  }

  Future<void> _loadPricesForProduct(
      String productId, String productName) async {
    setState(() {
      _isLoadingPrices = true;
      _selectedProductId = productId;
      _selectedProductName = productName;
      _priceListings = [];
    });

    try {
      await for (final listings
          in _pricingService.getPriceListingsForProduct(productId).take(1)) {
        setState(() {
          _priceListings = listings;
          _isLoadingPrices = false;
        });
      }
    } catch (e) {
      print('Error loading prices: $e');
      setState(() => _isLoadingPrices = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _priceListings = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedProductId == null,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedProductId != null) {
          _clearSelection();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.textPrimary,
          title: Text('Price Comparison',
              style: TextStyle(color: AppTheme.textPrimary)),
          elevation: 0,
          leading: _selectedProductId != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _clearSelection,
                )
              : null,
          actions: [
            if (_selectedProductId != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSelection,
              ),
          ],
        ),
        body: GlassTheme.backgroundContainer(
          child: SafeArea(
            child: Column(
              children: [
                _buildSearchSection(),
                Expanded(
                  child: _selectedProductId == null
                      ? _buildProductsList()
                      : _buildPriceComparisonList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for products (iPhone, Samsung TV, Rice, etc.)',
          prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _loadPopularProducts();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: GlassTheme.colors.glassBackground.first,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: TextStyle(color: AppTheme.textPrimary),
        onChanged: (value) {
          setState(() {});
          if (value.length >= 2) {
            _searchProducts(value);
          } else if (value.isEmpty) {
            _loadPopularProducts();
          }
        },
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final name = product.name ?? 'Unknown Product';
    final brand = product.brand ?? '';
    final listingCount =
        product.listingCount ?? product.businessListingsCount ?? 0;
    final minPrice = product.minPrice;
    final maxPrice = product.maxPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadPricesForProduct(product.id, name),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: GlassTheme.glassContainer,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Product image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.7),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: product.images != null && product.images.isNotEmpty
                        ? Image.network(
                            product.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderImage(name);
                            },
                          )
                        : _buildPlaceholderImage(name),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (brand.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: GlassTheme.colors.primaryBlue
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  size: 14,
                                  color: GlassTheme.colors.primaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$listingCount sellers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: GlassTheme.colors.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (minPrice != null && maxPrice != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Starting from',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  'LKR ${minPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: GlassTheme.colors.primaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(String productName) {
    final name = productName.toLowerCase();
    IconData icon;
    Color backgroundColor;

    if (name.contains('iphone') ||
        name.contains('samsung') ||
        name.contains('phone')) {
      icon = Icons.smartphone;
      backgroundColor = Colors.blue[100]!;
    } else if (name.contains('laptop') ||
        name.contains('macbook') ||
        name.contains('dell')) {
      icon = Icons.laptop;
      backgroundColor = Colors.purple[100]!;
    } else if (name.contains('tv') || name.contains('television')) {
      icon = Icons.tv;
      backgroundColor = Colors.green[100]!;
    } else if (name.contains('watch')) {
      icon = Icons.watch;
      backgroundColor = Colors.orange[100]!;
    } else if (name.contains('headphone') || name.contains('earphone')) {
      icon = Icons.headphones;
      backgroundColor = Colors.red[100]!;
    } else if (name.contains('camera')) {
      icon = Icons.camera_alt;
      backgroundColor = Colors.indigo[100]!;
    } else if (name.contains('shoe') ||
        name.contains('nike') ||
        name.contains('jordan')) {
      icon = Icons.sports_baseball;
      backgroundColor = Colors.teal[100]!;
    } else if (name.contains('car') || name.contains('vehicle')) {
      icon = Icons.directions_car;
      backgroundColor = Colors.cyan[100]!;
    } else {
      icon = Icons.shopping_bag;
      backgroundColor = Colors.grey[200]!;
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: Colors.grey[700],
        size: 24,
      ),
    );
  }

  Widget _buildPriceComparisonList() {
    return Column(
      children: [
        // Selected product header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedProductName ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Comparing prices from ${_priceListings.length} sellers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Price listings
        Expanded(
          child: _isLoadingPrices
              ? const Center(child: CircularProgressIndicator())
              : _priceListings.isEmpty
                  ? _buildNoPricesFound()
                  : _buildPricesList(),
        ),
      ],
    );
  }

  Widget _buildNoPricesFound() {
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
            'No prices available yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to know when businesses add prices for this product',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPricesList() {
    // Sort by price (cheapest first)
    final sortedListings = List<PriceListing>.from(_priceListings)
      ..sort((a, b) => a.price.compareTo(b.price));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedListings.length,
      itemBuilder: (context, index) {
        final listing = sortedListings[index];
        final isLowestPrice = index == 0;

        return _buildPriceCard(listing, isLowestPrice);
      },
    );
  }

  Widget _buildPriceCard(PriceListing listing, bool isLowestPrice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: GlassTheme.glassContainer,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with business logo, price and badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Logo
                GestureDetector(
                  onTap: () => _showBusinessBottomSheet(listing),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.7),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: listing.businessLogo.isNotEmpty
                          ? FutureBuilder<String?>(
                              future: () {
                                print(
                                    '🏢 [BusinessLogo] Business: ${listing.businessName}, Logo URL: "${listing.businessLogo}"');
                                return _getBusinessLogoUrl(
                                    listing.businessLogo);
                              }(),
                              builder: (context, snapshot) {
                                print(
                                    '🏢 [BusinessLogo] FutureBuilder state: hasData=${snapshot.hasData}, data=${snapshot.data}, error=${snapshot.error}');
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.network(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print(
                                          '❌ [BusinessLogo] Image.network error: $error');
                                      return _buildBusinessLogoPlaceholder(
                                          listing.businessName);
                                    },
                                  );
                                } else {
                                  return _buildBusinessLogoPlaceholder(
                                      listing.businessName);
                                }
                              },
                            )
                          : _buildBusinessLogoPlaceholder(listing.businessName),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${listing.currency} ${listing.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (isLowestPrice) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LOWEST PRICE',
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
                      // (name removed here to avoid showing twice; kept small info row below)
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Product details
            if (listing.modelNumber?.isNotEmpty == true) ...[
              Text(
                'Model: ${listing.modelNumber}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Contact info
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  listing.businessName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contact buttons
            Row(
              children: [
                if (listing.whatsappNumber?.isNotEmpty == true) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _contactBusiness('whatsapp', listing.whatsappNumber!),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (listing.productLink?.isNotEmpty == true) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _contactBusiness('website', listing.productLink!),
                      icon: const Icon(Icons.web, size: 16),
                      label: const Text('Website'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessLogoPlaceholder(String businessName) {
    final firstLetter =
        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B';
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.7),
            AppTheme.primaryColor,
          ],
        ),
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showBusinessBottomSheet(PriceListing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
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
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Business header
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.grey[100],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: listing.businessLogo.isNotEmpty
                                ? FutureBuilder<String?>(
                                    future: () {
                                      print(
                                          '🏢 [BusinessLogo-Modal] Business: ${listing.businessName}, Logo URL: "${listing.businessLogo}"');
                                      return _getBusinessLogoUrl(
                                          listing.businessLogo);
                                    }(),
                                    builder: (context, snapshot) {
                                      print(
                                          '🏢 [BusinessLogo-Modal] FutureBuilder state: hasData=${snapshot.hasData}, data=${snapshot.data}');
                                      if (snapshot.hasData &&
                                          snapshot.data != null) {
                                        return Image.network(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            print(
                                                '❌ [BusinessLogo-Modal] Image.network error: $error');
                                            return _buildBusinessLogoPlaceholder(
                                                listing.businessName);
                                          },
                                        );
                                      } else {
                                        return _buildBusinessLogoPlaceholder(
                                            listing.businessName);
                                      }
                                    },
                                  )
                                : _buildBusinessLogoPlaceholder(
                                    listing.businessName),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listing.businessName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Icon(Icons.verified,
                                  size: 18, color: Colors.green),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Offer tile
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.productName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'In stock',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${listing.currency} ${listing.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
                    const SizedBox(height: 12),

                    // Payment methods
                    if ((listing.paymentMethods).isNotEmpty) ...[
                      Text(
                        'Payment methods',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: listing.paymentMethods.take(8).map((pm) {
                          return _buildPaymentMethodChip(pm.name, pm.id);
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            size: 18, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Free shipping available',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.delivery_dining,
                            size: 18, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Pickup and delivery options',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showBusinessBottomSheet(listing),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'More information about ${listing.businessName}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[600]),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Primary CTA
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: listing.productLink?.isNotEmpty == true
                            ? () => _contactBusiness(
                                'website', listing.productLink!)
                            : (listing.whatsappNumber?.isNotEmpty == true
                                ? () => _contactBusiness(
                                    'whatsapp', listing.whatsappNumber!)
                                : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Shop at ${listing.businessName}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _getPaymentMethodImageUrl(String paymentMethodId) async {
    return await PaymentMethodsService.getPaymentMethodImageUrl(
        paymentMethodId);
  }

  Future<String?> _getBusinessLogoUrl(String logoUrl) async {
    print('🏢 [BusinessLogo] Processing logo URL: $logoUrl');

    // If it's already a full HTTP URL, check if it's an S3 URL that needs signing
    if (logoUrl.startsWith('https://requestappbucket.s3.amazonaws.com/')) {
      try {
        print('🏢 [BusinessLogo] Detected S3 URL, generating signed URL');
        // Extract the S3 key from the URL
        final uri = Uri.parse(logoUrl);
        final s3Key = uri.path.substring(1); // Remove leading slash
        print('🏢 [BusinessLogo] S3 Key: $s3Key');
        final signedUrl = await S3ImageUploadService.getSignedUrlForKey(s3Key);
        print('🏢 [BusinessLogo] Generated signed URL: $signedUrl');
        return signedUrl;
      } catch (e) {
        print('❌ Error getting signed URL for business logo: $e');
        return logoUrl; // Fallback to original URL
      }
    }
    // If it's not an S3 URL, return as-is
    print('🏢 [BusinessLogo] Non-S3 URL, returning as-is: $logoUrl');
    return logoUrl;
  }

  Widget _buildPaymentMethodChip(String name, String paymentMethodId) {
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<String?>(
          future: _getPaymentMethodImageUrl(paymentMethodId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Padding(
                padding: const EdgeInsets.all(6.0),
                child: Image.network(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[50],
                    child:
                        const Icon(Icons.payment, size: 24, color: Colors.grey),
                  ),
                ),
              );
            } else {
              return Container(
                color: Colors.grey[50],
                child: const Icon(Icons.payment, size: 24, color: Colors.grey),
              );
            }
          },
        ),
      ),
    );
  }

  void _contactBusiness(String type, String contact) {
    // Track the contact attempt
    _pricingService.trackProductClick(
      listingId: _selectedProductId,
      masterProductId: _selectedProductId,
      businessId: null, // We'd need to pass this from the listing
    );

    // Here you would implement the actual contact functionality
    // For WhatsApp: launch WhatsApp with the number
    // For Website: launch the website URL
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact: $contact'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
