import 'package:flutter/foundation.dart';
import 'api_client.dart';

class PublicProfile {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String? email;
  final String? phone;
  final DateTime? createdAt;
  final Map<String, dynamic>? business; // latest business verification snapshot
  final Map<String, dynamic>? driver; // latest driver verification snapshot
  final double averageRating;
  final int reviewCount;
  final int responsesCount;

  PublicProfile({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.email,
    this.phone,
    this.createdAt,
    this.business,
    this.driver,
    required this.averageRating,
    required this.reviewCount,
    required this.responsesCount,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] ?? {}) as Map<String, dynamic>;
    final reviews = (json['reviews'] ?? {}) as Map<String, dynamic>;
    final responses = (json['responses'] ?? {}) as Map<String, dynamic>;
    return PublicProfile(
      id: (user['id'] ?? '').toString(),
      displayName: (user['display_name'] ?? 'User').toString(),
      photoUrl: user['photo_url']?.toString(),
      email: user['email']?.toString(),
      phone: user['phone']?.toString(),
      createdAt: user['created_at'] != null
          ? DateTime.tryParse(user['created_at'].toString())
          : null,
      business: json['business'] is Map<String, dynamic>
          ? (json['business'] as Map<String, dynamic>)
          : null,
      driver: json['driver'] is Map<String, dynamic>
          ? (json['driver'] as Map<String, dynamic>)
          : null,
      averageRating:
          double.tryParse((reviews['average_rating'] ?? '0').toString()) ?? 0.0,
      reviewCount:
          int.tryParse((reviews['review_count'] ?? '0').toString()) ?? 0,
      responsesCount:
          int.tryParse((responses['responses_count'] ?? '0').toString()) ?? 0,
    );
  }
}

class UserReviewItem {
  final String id;
  final String requestId;
  final String reviewerId;
  final String revieweeId;
  final int rating; // 1-5
  final String? comment;
  final String? countryCode;
  final DateTime createdAt;
  final String? reviewerName;
  final String? reviewerPhoto;

  UserReviewItem({
    required this.id,
    required this.requestId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    this.comment,
    this.countryCode,
    required this.createdAt,
    this.reviewerName,
    this.reviewerPhoto,
  });

  factory UserReviewItem.fromJson(Map<String, dynamic> json) {
    return UserReviewItem(
      id: (json['id'] ?? '').toString(),
      requestId: (json['request_id'] ?? '').toString(),
      reviewerId: (json['reviewer_id'] ?? '').toString(),
      revieweeId: (json['reviewee_id'] ?? '').toString(),
      rating: int.tryParse((json['rating'] ?? '0').toString()) ?? 0,
      comment: json['comment']?.toString(),
      countryCode: json['country_code']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      reviewerName: json['reviewer_name']?.toString(),
      reviewerPhoto: json['reviewer_photo']?.toString(),
    );
  }
}

class PagedUserReviews {
  final List<UserReviewItem> reviews;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PagedUserReviews({
    required this.reviews,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });
}

class RestUserService {
  RestUserService._();
  static final RestUserService instance = RestUserService._();
  final ApiClient _api = ApiClient.instance;

  Future<PublicProfile?> getPublicProfile(String userId) async {
    try {
      final res =
          await _api.get<Map<String, dynamic>>('/api/users/public/$userId');
      if (res.isSuccess && res.data != null) {
        final data = res.data!['data'] as Map<String, dynamic>?;
        if (data != null) return PublicProfile.fromJson(data);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching public profile: $e');
      return null;
    }
  }

  Future<PagedUserReviews?> getUserReviews(String userId,
      {int page = 1, int limit = 10}) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
          '/api/reviews/user/$userId?page=$page&limit=$limit');
      if (res.isSuccess && res.data != null) {
        final data = res.data!['data'] as Map<String, dynamic>?;
        if (data == null) return null;
        final list = (data['reviews'] as List<dynamic>? ?? [])
            .map((e) => UserReviewItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = (data['pagination'] ?? {}) as Map<String, dynamic>;
        return PagedUserReviews(
          reviews: list,
          page: int.tryParse((pagination['page'] ?? page).toString()) ?? page,
          limit:
              int.tryParse((pagination['limit'] ?? limit).toString()) ?? limit,
          total: int.tryParse((pagination['total'] ?? '0').toString()) ?? 0,
          totalPages:
              int.tryParse((pagination['totalPages'] ?? '1').toString()) ?? 1,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching user reviews: $e');
      return null;
    }
  }
}
