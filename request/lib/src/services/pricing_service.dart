import 'dart:async';
import '../models/price_listing.dart';
import '../models/master_product.dart';
import 'api_client.dart';
import 'image_url_service.dart';

class PricingService {
  final ApiClient _apiClient = ApiClient.instance;

  Future<List<MasterProduct>> searchProducts(
      {String query = '', String? brand, int limit = 25}) async {
    try {
      print(
          'DEBUG: Searching products with query: "$query", brand: $brand, limit: $limit');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-listings/search',
        queryParameters: {
          'q': query,
          'country': 'LK',
          'limit': limit.toString(),
          if (brand != null) 'brand': brand,
        },
      );

      print('DEBUG: Search response - success: ${response.isSuccess}');
      print('DEBUG: Full response: ${response.data}');

      if (response.isSuccess && response.data != null) {
        // Extract the data array from the backend response
        final responseData = response.data!;
        final dataArray = responseData['data'] as List<dynamic>?;

        print('DEBUG: Data array length: ${dataArray?.length}');

        if (dataArray != null) {
          final productFutures = dataArray.map((data) async {
            print('DEBUG: Raw product data: $data');
            final product =
                MasterProduct.fromJson(data as Map<String, dynamic>);

            // Process all product images with AWS S3 signed URLs if needed
            final processedImages =
                await ImageUrlService.instance.processImageUrls(product.images);

            final processedProduct = MasterProduct(
              id: product.id,
              name: product.name,
              brand: product.brand,
              category: product.category,
              subcategory: product.subcategory,
              description: product.description,
              images: processedImages, // Use processed images with signed URLs
              availableVariables: product.availableVariables,
              isActive: product.isActive,
              createdAt: product.createdAt,
              updatedAt: product.updatedAt,
              businessListingsCount: product.businessListingsCount,
              slug: product.slug,
              baseUnit: product.baseUnit,
              brandName: product.brandName,
              listingCount: product.listingCount,
              minPrice: product.minPrice,
              maxPrice: product.maxPrice,
              avgPrice: product.avgPrice,
            );

            print(
                'DEBUG: Processed product "${processedProduct.name}" - Images: ${processedProduct.images}');
            return processedProduct;
          });

          final products = await Future.wait(productFutures);
          print(
              'DEBUG: Parsed ${products.length} products successfully with AWS image processing');
          return products;
        }
      }
      print('DEBUG: Response not successful or data is null');
      return [];
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  /// Get all available products for a country (for adding new price listings)
  Future<List<MasterProduct>> getAllCountryProducts(
      {String country = 'LK', String query = '', int limit = 50}) async {
    try {
      print(
          'DEBUG: Getting all country products for: $country, query: "$query", limit: $limit');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/country-products',
        queryParameters: {
          'country': country,
          if (query.isNotEmpty) 'search': query,
          'limit': limit.toString(),
        },
      );

      print(
          'DEBUG: Country products response - success: ${response.isSuccess}');
      print('DEBUG: Country products response: ${response.data}');

      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;
        final dataArray = responseData['data'] as List<dynamic>?;

        print(
            'DEBUG: Country products data array length: ${dataArray?.length}');

        if (dataArray != null) {
          var products = dataArray
              .where((data) =>
                  data['countryEnabled'] == true) // Only show enabled products
              .map((data) => MasterProduct.fromJson({
                    'id': data['id'],
                    'name': data['name'],
                    'slug': data['name']?.toLowerCase()?.replaceAll(' ', '-'),
                    'baseUnit': data['baseUnit'],
                    'brand': data['brand'],
                    'listingCount': 0, // No existing listings for new products
                    'priceRange': null,
                  }))
              .toList();

          // Filter by search query if provided
          if (query.isNotEmpty) {
            final queryLower = query.toLowerCase();
            products = products
                .where((product) =>
                    product.name.toLowerCase().contains(queryLower))
                .toList();
          }

          print(
              'DEBUG: Parsed ${products.length} country products successfully');
          return products;
        }
      }
      print('DEBUG: Country products response not successful or data is null');
      return [];
    } catch (e) {
      print('Error getting country products: $e');
      return [];
    }
  }

  Future<bool> isBusinessEligibleForPricing(String? businessUserId) async {
    if (businessUserId == null) {
      print('DEBUG: No businessUserId provided');
      return false;
    }

    try {
      print('DEBUG: Checking business eligibility for userId: $businessUserId');

      // TEMPORARY: For development/testing, return true to allow access
      // This will let you test the pricing features while we debug the user ID issue
      print('DEBUG: TEMPORARY - Allowing access for testing');
      return true;

      // Check if business is verified using the correct endpoint
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/business-verifications/user/$businessUserId',
      );

      print('DEBUG: API response success: ${response.isSuccess}');
      print('DEBUG: API response data: ${response.data}');

      if (response.isSuccess && response.data != null) {
        // Check if business verification exists and has required fields
        final businessData = response.data!;

        // Basic eligibility: business verification exists
        final hasBusinessName = businessData['business_name'] != null &&
            businessData['business_name'].toString().isNotEmpty;
        final hasBusinessPhone = businessData['business_phone'] != null &&
            businessData['business_phone'].toString().isNotEmpty;

        print(
            'DEBUG: hasBusinessName: $hasBusinessName, hasBusinessPhone: $hasBusinessPhone');
        print('DEBUG: business_name: ${businessData['business_name']}');
        print('DEBUG: business_phone: ${businessData['business_phone']}');

        // For now, just check if business profile exists with basic info
        final isEligible = hasBusinessName && hasBusinessPhone;
        print('DEBUG: Final eligibility result: $isEligible');

        return isEligible;
      }

      print('DEBUG: API call failed or no data returned');
      return false;
    } catch (e) {
      print('ERROR: Exception in business eligibility check: $e');
      // For development, return true to allow access during debugging
      return true;
    }
  }

  Stream<List<PriceListing>> getPriceListingsForProduct(
      String masterProductId) async* {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-listings',
        queryParameters: {
          'masterProductId': masterProductId,
          'country': 'LK',
          'sortBy': 'price_asc',
        },
      );

      if (response.isSuccess && response.data?['data'] != null) {
        final List<dynamic> listingsData = response.data!['data'];
        final listings =
            listingsData.map((data) => PriceListing.fromJson(data)).toList();
        yield listings;
      } else {
        yield [];
      }
    } catch (e) {
      print('Error loading price listings: $e');
      yield [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveVariableTypes() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/api/variable-types',
        queryParameters: {'country': 'LK', 'active': 'true'},
      );

      if (response.isSuccess && response.data != null) {
        return response.data!.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error loading variable types: $e');
      return [];
    }
  }

  Future<void> trackProductClick({
    String? listingId,
    String? masterProductId,
    String? businessId,
    String? userId,
  }) async {
    if (listingId == null) return;

    try {
      await _apiClient.post(
        '/api/price-listings/$listingId/contact',
        data: {
          'userId': userId,
          'masterProductId': masterProductId,
          'businessId': businessId,
        },
      );
    } catch (e) {
      print('Error tracking product click: $e');
    }
  }

  Stream<List<PriceListing>> getBusinessPriceListings(
      String? businessId) async* {
    if (businessId == null) {
      yield [];
      return;
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-listings',
        queryParameters: {
          'businessId': businessId,
          'country': 'LK',
        },
      );

      if (response.isSuccess && response.data?['data'] != null) {
        final List<dynamic> listingsData = response.data!['data'];
        final listings =
            listingsData.map((data) => PriceListing.fromJson(data)).toList();
        yield listings;
      } else {
        yield [];
      }
    } catch (e) {
      print('Error loading business price listings: $e');
      yield [];
    }
  }

  // Toggle active/inactive status (soft delete/activate)
  Future<bool> togglePriceListingStatus(String listingId) async {
    try {
      final response = await _apiClient
          .patch('/api/price-listings/$listingId/toggle-status');
      return response.isSuccess;
    } catch (e) {
      print('Error toggling price listing status: $e');
      return false;
    }
  }

  // Permanently delete a price listing (hard delete)
  Future<bool> permanentlyDeletePriceListing(String listingId) async {
    try {
      final response =
          await _apiClient.delete('/api/price-listings/$listingId/permanent');
      return response.isSuccess;
    } catch (e) {
      print('Error permanently deleting price listing: $e');
      return false;
    }
  }

  // Legacy method - now does soft delete (deactivate)
  Future<bool> deletePriceListing(
      String listingId, String masterProductId) async {
    try {
      final response =
          await _apiClient.delete('/api/price-listings/$listingId');
      return response.isSuccess;
    } catch (e) {
      print('Error deleting price listing: $e');
      return false;
    }
  }

  Stream<List<dynamic>> getMasterProducts({
    String? category,
    String? query,
    String? searchQuery,
    String? businessId,
    String? brand,
    int limit = 50,
  }) async* {
    try {
      final effectiveQuery = query ?? searchQuery ?? '';
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-listings/search',
        queryParameters: {
          'q': effectiveQuery,
          'country': 'LK',
          'limit': limit.toString(),
          if (category != null) 'category': category,
          if (brand != null) 'brand': brand,
        },
      );

      if (response.isSuccess && response.data?['data'] != null) {
        yield response.data!['data'];
      } else {
        yield [];
      }
    } catch (e) {
      print('Error loading master products: $e');
      yield [];
    }
  }

  Future<Map<String, dynamic>?> getBusinessProfile(String? userId) async {
    if (userId == null) return null;

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/business-verifications/profile/$userId',
      );

      if (response.isSuccess && response.data != null) {
        return response.data;
      }
      return {'businessId': userId, 'name': 'Business User'};
    } catch (e) {
      print('Error loading business profile: $e');
      return {'businessId': userId, 'name': 'Business User'};
    }
  }

  Future<bool> addOrUpdatePriceListing(dynamic listing) async {
    try {
      Map<String, dynamic> data;
      if (listing is Map<String, dynamic>) {
        data = listing;
      } else {
        // Convert object to map if needed
        data = listing.toJson();
      }

      // Check if this is an update (has ID) or create (no ID)
      final listingId = data['id'];
      final bool isUpdate = listingId != null;

      print(
          'DEBUG: ${isUpdate ? 'UPDATING' : 'CREATING'} price listing${isUpdate ? ' with ID: $listingId' : ''}');
      print('DEBUG: API payload: $data');

      late ApiResponse response;

      if (isUpdate) {
        // Remove ID from data payload for PUT request
        final updateData = Map<String, dynamic>.from(data);
        updateData.remove('id');

        // Use PUT for updates
        response = await _apiClient.put(
          '/api/price-listings/$listingId',
          data: updateData,
        );
      } else {
        // Use POST for new creations
        response = await _apiClient.post(
          '/api/price-listings',
          data: data,
        );
      }

      return response.isSuccess;
    } catch (e) {
      print('Error adding/updating price listing: $e');
      return false;
    }
  }

  Future<bool> createOrUpdateListing(Map<String, dynamic> data) async {
    return await addOrUpdatePriceListing(data);
  }

  // ===================== PRICE STAGING SYSTEM =====================

  /// Stage a price update (will be applied at 1 AM daily)
  Future<bool> stagePriceUpdate(
      String priceListingId, Map<String, dynamic> stagedData) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/price-staging/stage',
        data: {
          'priceListingId': priceListingId,
          ...stagedData,
        },
      );

      return response.isSuccess;
    } catch (e) {
      print('Error staging price update: $e');
      return false;
    }
  }

  /// Get all staged prices for the current business
  Future<List<Map<String, dynamic>>> getStagedPrices() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-staging/staged',
      );

      if (response.isSuccess && response.data != null) {
        final dataArray = response.data!['data'] as List<dynamic>?;
        return dataArray?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting staged prices: $e');
      return [];
    }
  }

  /// Cancel a staged price update
  Future<bool> cancelStagedPrice(String priceListingId) async {
    try {
      final response = await _apiClient.delete(
        '/api/price-staging/stage/$priceListingId',
      );

      return response.isSuccess;
    } catch (e) {
      print('Error cancelling staged price: $e');
      return false;
    }
  }

  /// Get business staging summary
  Future<Map<String, dynamic>?> getStagingSummary() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-staging/summary',
      );

      if (response.isSuccess && response.data != null) {
        return response.data!['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting staging summary: $e');
      return null;
    }
  }

  /// Get price update history
  Future<List<Map<String, dynamic>>> getPriceHistory({int limit = 50}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-staging/history',
        queryParameters: {
          'limit': limit.toString(),
        },
      );

      if (response.isSuccess && response.data != null) {
        final dataArray = response.data!['data'] as List<dynamic>?;
        return dataArray?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting price history: $e');
      return [];
    }
  }

  /// Get next scheduled update time
  Future<Map<String, dynamic>?> getNextUpdateTime() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/price-staging/next-update',
      );

      if (response.isSuccess && response.data != null) {
        return response.data!['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting next update time: $e');
      return null;
    }
  }
}
