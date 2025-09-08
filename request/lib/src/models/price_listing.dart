class PaymentMethodRef {
  final String id;
  final String name;
  final String category;
  final String? imageUrl;

  PaymentMethodRef({
    required this.id,
    required this.name,
    required this.category,
    this.imageUrl,
  });

  factory PaymentMethodRef.fromJson(Map<String, dynamic> json) {
    return PaymentMethodRef(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'other',
      imageUrl: json['imageUrl'] ?? json['image_url'],
    );
  }
}

class PriceListing {
  final String id;
  final String businessId;
  final String businessName;
  final String businessLogo;
  final String masterProductId;
  final String productName;
  final String brand;
  final String category;
  final String subcategory;
  final double price;
  final String currency;
  final String? modelNumber;
  final Map<String, String> selectedVariables;
  final List<String> productImages;
  final String? productLink;
  final String? whatsappNumber;
  final bool isAvailable;
  final int stockQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int clickCount;
  final double rating;
  final int reviewCount;
  final String? country; // Country code (e.g., "LK")
  final String? countryName; // Country name (e.g., "Sri Lanka")
  final List<PaymentMethodRef> paymentMethods;
  final bool hasPendingChanges; // True if price has pending staging changes
  final String stagingStatus; // 'pending' or 'active'

  PriceListing({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.businessLogo,
    required this.masterProductId,
    required this.productName,
    required this.brand,
    required this.category,
    required this.subcategory,
    required this.price,
    required this.currency,
    this.modelNumber,
    required this.selectedVariables,
    required this.productImages,
    this.productLink,
    this.whatsappNumber,
    required this.isAvailable,
    required this.stockQuantity,
    required this.createdAt,
    required this.updatedAt,
    this.clickCount = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.country,
    this.countryName,
    this.paymentMethods = const [],
    this.hasPendingChanges = false,
    this.stagingStatus = 'active',
  });

  factory PriceListing.fromJson(Map<String, dynamic> json) {
    // Parse business payment methods if present
    final List<dynamic>? pmList =
        json['business']?['paymentMethods'] as List<dynamic>?;
    final methods = (pmList ?? [])
        .map((e) => PaymentMethodRef.fromJson(e as Map<String, dynamic>))
        .toList();

    // Parse staging data
    final hasPending =
        json['hasPendingChanges'] ?? json['has_pending_changes'] ?? false;
    final stagingStatus =
        json['stagingStatus'] ?? json['staging_status'] ?? 'active';

    return PriceListing(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? json['businessId'] ?? '',
      businessName: json['business']?['name'] ?? json['businessName'] ?? '',
      businessLogo: json['business']?['logo'] ?? json['businessLogo'] ?? '',
      masterProductId:
          json['master_product_id'] ?? json['masterProductId'] ?? '',
      productName: json['title'] ?? json['productName'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'LKR',
      modelNumber: json['model_number'] ?? json['modelNumber'],
      selectedVariables: Map<String, String>.from(
          json['selected_variables'] ?? json['selectedVariables'] ?? {}),
      productImages:
          List<String>.from(json['images'] ?? json['productImages'] ?? []),
      productLink: json['website'] ?? json['productLink'],
      whatsappNumber: json['whatsapp'] ?? json['whatsappNumber'],
      isAvailable: json['is_active'] ?? json['isAvailable'] ?? true,
      stockQuantity: json['stock_quantity'] ?? json['stockQuantity'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ??
          json['createdAt'] ??
          DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ??
          json['updatedAt'] ??
          DateTime.now().toIso8601String()),
      clickCount: json['contact_count'] ?? json['clickCount'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['review_count'] ?? json['reviewCount'] ?? 0,
      country: json['country_code'] ?? json['country'],
      countryName: json['countryName'],
      paymentMethods: methods,
      hasPendingChanges: hasPending,
      stagingStatus: stagingStatus,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'businessLogo': businessLogo,
      'masterProductId': masterProductId,
      'productName': productName,
      'brand': brand,
      'category': category,
      'subcategory': subcategory,
      'price': price,
      'currency': currency,
      'modelNumber': modelNumber,
      'selectedVariables': selectedVariables,
      'productImages': productImages,
      'productLink': productLink,
      'whatsappNumber': whatsappNumber,
      'isAvailable': isAvailable,
      'stockQuantity': stockQuantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'clickCount': clickCount,
      'rating': rating,
      'reviewCount': reviewCount,
      'country': country,
      'countryName': countryName,
    };
  }

  PriceListing copyWith({
    String? id,
    String? businessId,
    String? businessName,
    String? businessLogo,
    String? masterProductId,
    String? productName,
    String? brand,
    String? category,
    String? subcategory,
    double? price,
    String? currency,
    String? modelNumber,
    Map<String, String>? selectedVariables,
    List<String>? productImages,
    String? productLink,
    String? whatsappNumber,
    bool? isAvailable,
    int? stockQuantity,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? clickCount,
    double? rating,
    int? reviewCount,
    String? country,
    String? countryName,
    List<PaymentMethodRef>? paymentMethods,
    bool? hasPendingChanges,
    String? stagingStatus,
  }) {
    return PriceListing(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessLogo: businessLogo ?? this.businessLogo,
      masterProductId: masterProductId ?? this.masterProductId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      modelNumber: modelNumber ?? this.modelNumber,
      selectedVariables: selectedVariables ?? this.selectedVariables,
      productImages: productImages ?? this.productImages,
      productLink: productLink ?? this.productLink,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clickCount: clickCount ?? this.clickCount,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      country: country ?? this.country,
      countryName: countryName ?? this.countryName,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      hasPendingChanges: hasPendingChanges ?? this.hasPendingChanges,
      stagingStatus: stagingStatus ?? this.stagingStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'masterProductId': masterProductId,
      'title': productName,
      'description': modelNumber != null
          ? '$brand $productName ($modelNumber)'
          : '$brand $productName',
      'price': price,
      'currency': currency,
      'deliveryCharge': 0, // Default delivery charge
      'website': productLink,
      'whatsapp': whatsappNumber,
      'countryCode': country ?? 'LK',
      'unit': 'piece', // Default unit
      'selectedVariables': selectedVariables,
    };
  }
}
