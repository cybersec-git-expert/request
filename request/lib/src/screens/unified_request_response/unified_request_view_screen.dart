import 'package:flutter/material.dart';
import '../../widgets/glass_page.dart';
import '../../theme/glass_theme.dart';
import '../../services/rest_request_service.dart' as rest;
import '../../services/rest_auth_service.dart';
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart';
import '../../utils/image_url_helper.dart';
import '../../widgets/smart_network_image.dart';
import 'unified_response_create_screen.dart';
import 'unified_request_edit_screen.dart';
import 'view_all_responses_screen.dart';
import 'unified_response_edit_screen.dart';
import '../chat/conversation_screen.dart';
import '../../services/chat_service.dart';
import '../../services/rest_request_service.dart' show ReviewsService;
import '../account/public_profile_screen.dart';
import '../../services/rest_user_service.dart';
import '../membership/quick_upgrade_sheet.dart';
import '../../../services/entitlements_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UnifiedRequestViewScreen (Minimal REST Migration)
/// Legacy Firebase-based logic removed. Displays core request info only.
class UnifiedRequestViewScreen extends StatefulWidget {
  final String requestId;
  const UnifiedRequestViewScreen({super.key, required this.requestId});
  @override
  State<UnifiedRequestViewScreen> createState() =>
      _UnifiedRequestViewScreenState();
}

class _UnifiedRequestViewScreenState extends State<UnifiedRequestViewScreen> {
  final rest.RestRequestService _service = rest.RestRequestService.instance;
  rest.RequestModel? _request;
  bool _loading = true;
  bool _isOwner = false;
  // Added state
  List<rest.ResponseModel> _responses = [];
  bool _responsesLoading = false;
  // Removed per simplification: individual response update/delete no longer supported here
  bool _updatingRequest = false;
  bool _deletingRequest = false;
  bool _submittingReview = false;
  bool _alreadyReviewed = false;
  String? _requesterPhotoUrl;
  // Entitlements and membership gating
  final EntitlementsService _entitlementsService = EntitlementsService();
  UserEntitlements? _entitlements;
  bool _membershipCompleted = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadEntitlementsAndPrefs();
  }

  Future<void> _loadEntitlementsAndPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('membership_completed') ??
          true; // Default to true for new users

      // Get current user ID
      final userId = RestAuthService.instance.currentUser?.uid;
      UserEntitlements? ent;

      if (userId != null) {
        print('DEBUG: Loading entitlements for user $userId...');

        // Try both methods to ensure we get fresh data
        ent = await _entitlementsService.getUserEntitlements();
        if (ent == null) {
          print(
              'DEBUG: Main entitlements method failed, trying simple method...');
          ent = await _entitlementsService.getUserEntitlementsSimple(userId);
        }

        print(
            'DEBUG: Loaded entitlements for user $userId: canRespond=${ent?.canRespond}, responseCount=${ent?.responseCount}, remaining=${ent?.remainingResponses}');
        print('DEBUG: Full entitlements object: $ent');
      } else {
        print('DEBUG: No user ID found, skipping entitlements load');
      }

      if (!mounted) return;
      setState(() {
        _membershipCompleted = completed;
        _entitlements = ent;
      });
    } catch (e) {
      print('Error loading entitlements: $e');
      // Use permissive defaults for new users when API fails
      if (!mounted) return;
      setState(() {
        _membershipCompleted = true;
        _entitlements = UserEntitlements.fromJson({
          'canSeeContactDetails': true,
          'canSendMessages': true,
          'canRespond': true,
          'responseCount': 0,
          'remainingResponses': 3,
          'subscriptionType': 'free',
          'planName': 'Free Plan',
        });
      });
    }
  }

  Widget _buildRequesterAvatar(rest.RequestModel r) {
    final name = (r.userName ?? 'User').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    const double size = 24;
    final url = _requesterPhotoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: SmartNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Color(0xFFEAEAEA),
                shape: BoxShape.circle,
              ),
            ),
            errorBuilder: (c, e, st) => _initialsAvatar(initial, size),
          ),
        ),
      );
    }
    return _initialsAvatar(initial, size);
  }

  Widget _initialsAvatar(String ch, double size) => CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey.shade300,
        child: Text(ch, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _service.getRequestById(widget.requestId);
      final currentUserId = RestAuthService.instance.currentUser?.uid;
      bool owner =
          r != null && currentUserId != null && r.userId == currentUserId;
      List<rest.ResponseModel> responses = [];
      if (r != null) {
        try {
          final page = await _service.getResponses(r.id, page: 1, limit: 50);
          responses = page.responses;
        } catch (_) {}
        // Check if current user already reviewed (if owner)
        if (owner) {
          try {
            final mine =
                await ReviewsService.instance.getMyReviewForRequest(r.id);
            _alreadyReviewed = mine != null;
          } catch (_) {}
        }
      }
      if (mounted) {
        setState(() {
          _request = r;
          _isOwner = owner;
          _responses = responses;
          _loading = false;
        });
        // Lazy fetch requester avatar after first frame
        if (r != null && (r.userId).isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final profile =
                  await RestUserService.instance.getPublicProfile(r.userId);
              if (!mounted) return;
              setState(() {
                _requesterPhotoUrl = profile?.photoUrl;
              });
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load request: $e')));
      }
    }
  }

  Future<void> _reloadResponses() async {
    if (_request == null) return;
    setState(() => _responsesLoading = true);
    try {
      print('DEBUG: Reloading responses for request ${_request!.id}');

      // Add a small delay to ensure backend has processed the update
      await Future.delayed(const Duration(milliseconds: 500));

      final page =
          await _service.getResponses(_request!.id, page: 1, limit: 50);

      print('DEBUG: Loaded ${page.responses.length} responses');
      if (page.responses.isNotEmpty) {
        final firstResponse = page.responses.first;
        print('DEBUG: First response message: "${firstResponse.message}"');
        print('DEBUG: First response updated_at: ${firstResponse.updatedAt}');
      }

      if (mounted) setState(() => _responses = page.responses);
    } catch (e) {
      print('DEBUG: Error reloading responses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reload responses: $e')));
      }
    } finally {
      if (mounted) setState(() => _responsesLoading = false);
    }
  }

  bool get _canRespond {
    if (_request == null) {
      print('DEBUG: _canRespond = false (no request)');
      return false;
    }
    final userId = RestAuthService.instance.currentUser?.uid;
    if (userId == null) {
      print('DEBUG: _canRespond = false (no user ID)');
      return false;
    }
    if (userId == _request!.userId) {
      print('DEBUG: _canRespond = false (user is owner)');
      return false; // owner cannot respond
    }
    final status = _request!.status.toLowerCase();
    if (!(status == 'active' || status == 'open')) {
      print('DEBUG: _canRespond = false (status not active/open: $status)');
      return false;
    }
    // Skip old canMessage check - now using entitlements system
    // if (_request?.canMessage == false) {
    //   print('DEBUG: _canRespond = false (canMessage = false)');
    //   return false;
    // }
    // Check entitlements - now defaults to restrictive when API fails
    if (_entitlements != null && _entitlements!.canRespond == false) {
      print(
          'DEBUG: _canRespond = false (entitlements deny: ${_entitlements!.canRespond})');
      print(
          'DEBUG: _entitlements responseCount: ${_entitlements!.responseCount}, remainingResponses: ${_entitlements!.remainingResponses}');
      return false;
    }
    // Only allow one response per user on this screen
    final hasExistingResponse = _responses.any((r) => r.userId == userId);
    if (hasExistingResponse) {
      print('DEBUG: _canRespond = false (user already responded)');
      return false;
    }

    print(
        'DEBUG: _canRespond = true (all checks passed, entitlements: ${_entitlements?.canRespond})');
    print(
        'DEBUG: Current entitlements: responseCount=${_entitlements?.responseCount}, remaining=${_entitlements?.remainingResponses}');
    return true;
  }

  /// Check business verification status for smart routing
  Future<String> _checkBusinessVerificationStatus() async {
    try {
      final userService = EnhancedUserService();
      final user = await userService.getCurrentUser();
      if (user == null) return 'no_auth';

      // Check if user has business role
      if (!user.roles.contains(UserRole.business)) {
        return 'no_business_role';
      }

      // Check business verification status
      final resp = await ApiClient.instance
          .get('/api/business-verifications/user/${user.uid}');
      if (resp.isSuccess && resp.data != null) {
        final responseWrapper = resp.data as Map<String, dynamic>;
        final data = responseWrapper['data'] as Map<String, dynamic>?;
        if (data != null) {
          final status =
              (data['status'] ?? 'pending').toString().trim().toLowerCase();
          return status; // 'approved', 'pending', 'rejected'
        }
      }
      return 'no_verification';
    } catch (e) {
      print('Error checking business verification: $e');
      return 'error';
    }
  }

  /// Smart navigation to subscription plans based on business verification status
  Future<void> _navigateToSubscriptionPlans() async {
    final verificationStatus = await _checkBusinessVerificationStatus();

    switch (verificationStatus) {
      case 'approved':
        // User is verified business, go to role management to manage subscription
        Navigator.pushNamed(context, '/role-management');
        break;
      case 'pending':
        // User has pending verification, go to role management
        Navigator.pushNamed(context, '/role-management');
        break;
      case 'rejected':
        // User was rejected, show message and go to role management
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Your business verification was rejected. Please check your role management for details.')),
        );
        Navigator.pushNamed(context, '/role-management');
        break;
      case 'no_business_role':
      case 'no_verification':
      case 'error':
      default:
        // New user or no existing business role, go to role management to see options
        Navigator.pushNamed(context, '/role-management');
        break;
    }
  }

  void _openCreateResponseSheet() {
    if (_request == null) return;
    () async {
      // Check entitlements instead of old canMessage flag
      final userId = RestAuthService.instance.currentUser?.uid;
      bool canRespond = true;

      if (userId != null && _entitlements != null) {
        canRespond = _entitlements!.canRespond;
      }

      if (!canRespond) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'You have reached your response limit for this month.'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
        // Offer quick navigation to membership page
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Upgrade membership to continue responding'),
            action: SnackBarAction(
              label: 'View Plans',
              onPressed: () async {
                final reqType =
                    (_request?.requestType ?? _request?.categoryType ?? '')
                        .toString()
                        .toLowerCase();
                final isRide = reqType.contains('ride');
                await QuickUpgradeSheet.show(
                    context, isRide ? 'driver' : 'business');
              },
            ),
          ),
        );
        return;
      }
      // Gate by membership completion and entitlements
      if (!_membershipCompleted ||
          (_entitlements != null && !_entitlements!.canRespond)) {
        if (!mounted) return;
        final reqType = (_request?.requestType ?? _request?.categoryType ?? '')
            .toString()
            .toLowerCase();
        final isRide = reqType.contains('ride');
        await QuickUpgradeSheet.show(context, isRide ? 'driver' : 'business');
        return;
      }
      if (!mounted) return;
      final requestModel = _convertToRequestModel(_request!);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              UnifiedResponseCreateScreen(request: requestModel),
        ),
      ).then((_) {
        _reloadResponses();
        _loadEntitlementsAndPrefs(); // Refresh entitlements after response creation
      });
    }();
  }

  Future<void> _messageRequester(rest.RequestModel r) async {
    final currentUserId = RestAuthService.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to chat')));
      return;
    }
    if (currentUserId == r.userId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('This is your own request. You cannot message yourself.')));
      return;
    }
    // Skip old canMessage check for messaging - now using entitlements
    // New entitlements system will handle this via checkCanSendMessages
    try {
      final (convo, messages) = await ChatService.instance.openConversation(
          requestId: r.id, currentUserId: currentUserId, otherUserId: r.userId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
              conversation: convo, initialMessages: messages),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to open chat: $e')));
    }
  }

  void _navigateToRequestEdit() {
    if (_request == null) return;

    // Convert REST model to enhanced model
    final requestModel = _convertToRequestModel(_request!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedRequestEditScreen(request: requestModel),
      ),
    ).then((_) => _load()); // Refresh when returning
  }

  void _navigateToViewAllResponses() {
    if (_request == null) return;

    // Convert REST model to enhanced model
    final requestModel = _convertToRequestModel(_request!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewAllResponsesScreen(request: requestModel),
      ),
    ).then((_) => _reloadResponses()); // Refresh responses when returning
  }
  // Removed _navigateToResponseEdit (individual response editing hidden here)

  void _navigateToResponseEdit(rest.ResponseModel response) {
    if (_request == null) return;
    final requestModel = _convertToRequestModel(_request!);
    final responseModel = _convertToResponseModel(response);

    print('DEBUG: Navigating to edit screen with response:');
    print('  Response ID: ${response.id}');
    print('  Message: "${response.message}"');
    print('  Price: ${response.price}');
    print('  Updated At: ${response.updatedAt}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedResponseEditScreen(
          request: requestModel,
          response: responseModel,
        ),
      ),
    ).then((updatedResponse) async {
      print('DEBUG: Response edit completed');

      // Always reload responses to ensure we have the latest data
      // This is more reliable than trying to map between different model types
      print('DEBUG: Reloading responses after edit');
      await _reloadResponses();

      if (updatedResponse != null) {
        print(
            'DEBUG: Response was updated successfully: ${updatedResponse.id}');
      }
    });
  }

  RequestType _getCurrentRequestType() {
    if (_request == null) return RequestType.item;

    // Check multiple possible locations for the type
    String? typeString;

    // First check metadata
    if (_request!.metadata != null) {
      typeString = _request!.metadata!['type']?.toString();
    }

    // If no type in metadata, try to infer from category name
    if (typeString == null || typeString.isEmpty) {
      typeString = _inferTypeFromCategory(_request!.categoryName);
    }

    // If still no type, try to infer from title
    if (typeString.isEmpty || typeString == 'item') {
      final titleType = _inferTypeFromTitle(_request!.title);
      if (titleType != 'item') {
        typeString = titleType;
      }
    }

    return _getRequestTypeFromString(
        typeString.isNotEmpty ? typeString : 'item');
  }

  String _inferTypeFromCategory(String? categoryName) {
    if (categoryName == null) return 'item';
    final category = categoryName.toLowerCase();

    if (category.contains('delivery') ||
        category.contains('transport') ||
        category.contains('shipping') ||
        category.contains('courier')) {
      return 'delivery';
    } else if (category.contains('service') ||
        category.contains('repair') ||
        category.contains('maintenance') ||
        category.contains('installation')) {
      return 'service';
    } else if (category.contains('rental') ||
        category.contains('rent') ||
        category.contains('hire') ||
        category.contains('lease')) {
      return 'rental';
    } else if (category.contains('ride') ||
        category.contains('taxi') ||
        category.contains('uber') ||
        category.contains('transport')) {
      return 'ride';
    } else if (category.contains('price') ||
        category.contains('quote') ||
        category.contains('estimate') ||
        category.contains('valuation')) {
      return 'price';
    }

    return 'item'; // Default to item
  }

  String _inferTypeFromTitle(String? title) {
    if (title == null) return 'item';
    final titleLower = title.toLowerCase();

    if (titleLower.contains('delivery') ||
        titleLower.contains('transport') ||
        titleLower.contains('shipping') ||
        titleLower.contains('courier')) {
      return 'delivery';
    } else if (titleLower.contains('service') ||
        titleLower.contains('repair') ||
        titleLower.contains('fix') ||
        titleLower.contains('install')) {
      return 'service';
    } else if (titleLower.contains('rental') ||
        titleLower.contains('rent') ||
        titleLower.contains('hire') ||
        titleLower.contains('lease')) {
      return 'rental';
    } else if (titleLower.contains('ride') ||
        titleLower.contains('taxi') ||
        titleLower.contains('uber') ||
        titleLower.contains('trip')) {
      return 'ride';
    } else if (titleLower.contains('price') ||
        titleLower.contains('quote') ||
        titleLower.contains('estimate') ||
        titleLower.contains('cost')) {
      return 'price';
    }

    return 'item'; // Default to item
  }

  Color _getTypeColor(RequestType type) {
    switch (type) {
      case RequestType.item:
        return const Color(0xFFFF6B35); // Orange/red
      case RequestType.service:
        return const Color(0xFF00BCD4); // Teal
      case RequestType.rental:
        return const Color(0xFF2196F3); // Blue
      case RequestType.delivery:
        return const Color(0xFF4CAF50); // Green
      case RequestType.ride:
        return const Color(0xFFFFC107); // Yellow
      case RequestType.price:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  // Helper method to convert REST RequestModel to enhanced RequestModel
  RequestModel _convertToRequestModel(rest.RequestModel restRequest) {
    return RequestModel(
      id: restRequest.id,
      title: restRequest.title,
      description: restRequest.description,
      requesterId: restRequest.userId,
      type: _getRequestTypeFromString(
          restRequest.metadata?['type']?.toString() ?? 'item'),
      status: _getRequestStatusFromString(restRequest.status),
      createdAt: restRequest.createdAt,
      updatedAt: restRequest.updatedAt,
      budget: restRequest.budget,
      currency: restRequest.currency,
      images: restRequest.imageUrls ?? [],
      tags: [],
      priority: Priority.medium,
      location: restRequest.locationAddress != null &&
              restRequest.locationLatitude != null &&
              restRequest.locationLongitude != null
          ? LocationInfo(
              latitude: restRequest.locationLatitude!,
              longitude: restRequest.locationLongitude!,
              address: restRequest.locationAddress!,
              city: restRequest.cityName ?? restRequest.locationAddress!,
              country: restRequest.countryCode,
            )
          : (restRequest.cityName != null
              ? LocationInfo(
                  latitude: 0.0,
                  longitude: 0.0,
                  address: restRequest.cityName!,
                  city: restRequest.cityName!,
                  country: restRequest.countryCode,
                )
              : null),
      typeSpecificData: restRequest.metadata ?? {},
      country: restRequest.countryCode,
    );
  }

  // Removed _convertToResponseModel (no individual response render)

  RequestType _getRequestTypeFromString(String type) {
    // Handle both "RequestType.item" and "item" formats
    String cleanType = type.toLowerCase();
    if (cleanType.startsWith('requesttype.')) {
      cleanType = cleanType.substring('requesttype.'.length);
    }

    switch (cleanType) {
      case 'item':
        return RequestType.item;
      case 'service':
        return RequestType.service;
      case 'delivery':
        return RequestType.delivery;
      case 'rental':
      case 'rent':
        return RequestType.rental;
      case 'ride':
        return RequestType.ride;
      case 'price':
        return RequestType.price;
      default:
        return RequestType.item;
    }
  }

  // Needed again for response edit navigation
  ResponseModel _convertToResponseModel(rest.ResponseModel restResponse) {
    return ResponseModel(
      id: restResponse.id,
      requestId: restResponse.requestId,
      responderId: restResponse.userId,
      message: restResponse.message,
      price: restResponse.price,
      currency: restResponse.currency,
      images: restResponse.imageUrls ?? [],
      isAccepted: _request?.acceptedResponseId == restResponse.id,
      createdAt: restResponse.createdAt,
      availableFrom: null,
      availableUntil: null,
      additionalInfo: {
        ...?restResponse.metadata,
        if (restResponse.locationAddress != null)
          'location_address': restResponse.locationAddress,
        if (restResponse.locationLatitude != null)
          'location_latitude': restResponse.locationLatitude,
        if (restResponse.locationLongitude != null)
          'location_longitude': restResponse.locationLongitude,
        if (restResponse.countryCode != null)
          'country_code': restResponse.countryCode,
        if (restResponse.userName != null)
          'responder_name': restResponse.userName,
        if (restResponse.userEmail != null)
          'responder_email': restResponse.userEmail,
        if (restResponse.userPhone != null)
          'responder_phone': restResponse.userPhone,
      },
      rejectionReason: null,
    );
  }

  RequestStatus _getRequestStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return RequestStatus.active;
      case 'open':
        return RequestStatus.open;
      case 'completed':
        return RequestStatus.completed;
      case 'cancelled':
        return RequestStatus.cancelled;
      case 'inprogress':
        return RequestStatus.inProgress;
      case 'expired':
        return RequestStatus.expired;
      default:
        return RequestStatus.active;
    }
  }

  Future<void> _markCompleted() async {
    if (_request == null) return;
    final updated = await _service.markRequestCompleted(_request!.id);
    if (updated != null) {
      setState(() => _request = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request marked as completed')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark as completed')));
    }
  }

  Future<void> _promptReviewAcceptedResponder() async {
    if (_request == null) return;
    final acceptedId = _request!.acceptedResponseId;
    if (acceptedId == null) return;
    // Find the accepted response to show context
    // Ensure responses loaded; dialog does not display responder info for now
    int rating = 5;
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rate your experience'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How was the responder?'),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (ctx, setD) {
              return Row(
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setD(() => rating = i + 1),
                  );
                }),
              );
            }),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(hintText: 'Optional comment'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: _submittingReview
                ? null
                : () async {
                    setState(() => _submittingReview = true);
                    final ok = await ReviewsService.instance.createReview(
                      requestId: _request!.id,
                      rating: rating,
                      comment: commentCtrl.text.trim(),
                    );
                    if (mounted) setState(() => _submittingReview = false);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Review submitted'
                            : 'Failed to submit review')));
                  },
            child: _submittingReview
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // Removed edit & delete response methods (aggregate-only view)

  void _openEditRequestSheet() {
    if (_request == null) return;
    final r = _request!;
    final titleController = TextEditingController(text: r.title);
    final descController = TextEditingController(text: r.description);
    final budgetController =
        TextEditingController(text: r.budget?.toStringAsFixed(0) ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setSheet) {
          final busy = _updatingRequest;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Edit Request',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx))
                  ]),
                  TextField(
                      controller: titleController,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Budget')),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                final desc = descController.text.trim();
                                if (title.isEmpty || desc.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Title and description are required')),
                                  );
                                  return;
                                }
                                setSheet(() => _updatingRequest = true);
                                try {
                                  final budgetText =
                                      budgetController.text.trim();
                                  final payload = <String, dynamic>{
                                    'title': title,
                                    'description': desc,
                                    if (budgetText.isNotEmpty)
                                      'budget': double.tryParse(budgetText),
                                  };
                                  final updated = await _service.updateRequest(
                                      _request!.id, payload);
                                  if (updated != null) {
                                    if (mounted) {
                                      setState(() => _request = updated);
                                      Navigator.pop(ctx);
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Failed to save changes')));
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error: ${e.toString()}')));
                                  }
                                } finally {
                                  setSheet(() => _updatingRequest = false);
                                }
                              },
                        icon: const Icon(Icons.save_outlined),
                        label: Text(busy ? 'Saving...' : 'Save Changes'),
                      )),
                  const SizedBox(height: 12),
                ]),
          );
        }),
      ),
    );
  }

  Widget _ownerActions() {
    if (_request == null || !_isOwner) return const SizedBox.shrink();
    final status = _request!.status.toLowerCase();
    final hasAccepted = _request!.acceptedResponseId != null;
    return Row(
      children: [
        if (hasAccepted && status != 'completed')
          FilledButton.icon(
            onPressed: _markCompleted,
            icon: const Icon(Icons.flag_circle_outlined),
            label: const Text('Mark completed'),
          ),
        const SizedBox(width: 12),
        if (status == 'completed' && hasAccepted)
          OutlinedButton.icon(
            onPressed: _alreadyReviewed ? null : _promptReviewAcceptedResponder,
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(
                _alreadyReviewed ? 'Already reviewed' : 'Review responder'),
          ),
      ],
    );
  }

  Future<void> _toggleStatus() async {
    if (_request == null) return;
    if (_updatingRequest) return;
    final cur = _request!.status.toLowerCase();
    final newStatus = cur == 'active' ? 'closed' : 'active';
    setState(() => _updatingRequest = true);
    final updated =
        await _service.updateRequest(_request!.id, {'status': newStatus});
    if (updated != null) {
      setState(() => _request = updated);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status set to ${updated.status}')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')));
    }
    if (mounted) setState(() => _updatingRequest = false);
  }

  Future<void> _confirmDeleteRequest() async {
    if (_request == null) return;
    if (_deletingRequest) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
            'Delete this request permanently? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deletingRequest = true);
    final success = await _service.deleteRequest(_request!.id);
    if (success) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete request')));
    }
    if (mounted) setState(() => _deletingRequest = false);
  }

  // (Removed obsolete placeholder _messageRequester definition; real implementation placed earlier.)

  void _showImageFullScreen(String imageUrl) {
    // Ensure we have the full URL
    final fullImageUrl = ImageUrlHelper.getFullImageUrl(imageUrl);
    ImageUrlHelper.debugImageUrl(imageUrl); // Debug output

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: SmartNetworkImage(
                  imageUrl: fullImageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 50),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fullImageUrl,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const GlassPage(
        title: 'Loading...',
        body: Center(child: CircularProgressIndicator()),
        leading: SizedBox.shrink(),
      );
    }
    if (_request == null) {
      return const GlassPage(
        title: 'Request',
        body: Center(child: Text('Request not found.')),
      );
    }
    final r = _request!;
    final fab = () {
      // Check if current user has a response
      final currentUserId = RestAuthService.instance.currentUser?.uid;
      rest.ResponseModel? myResponse;
      if (currentUserId != null) {
        for (final resp in _responses) {
          if (resp.userId == currentUserId) {
            myResponse = resp;
            break;
          }
        }
      }

      // If user has a response, show edit button
      if (myResponse != null) {
        return FloatingActionButton.extended(
          onPressed: () => _navigateToResponseEdit(myResponse!),
          backgroundColor: _getTypeColor(_getCurrentRequestType()),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
        );
      }

      // If user can respond but hasn't yet, show respond button
      if (_canRespond) {
        return FloatingActionButton.extended(
          onPressed: _openCreateResponseSheet,
          backgroundColor: _getTypeColor(_getCurrentRequestType()),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.reply),
          label: const Text('Respond'),
        );
      }

      // No floating action button when user can't respond
      return null;
    }();

    return GlassPage(
      title: r.title.isNotEmpty ? r.title : 'Request',
      appBarBackgroundColor: GlassTheme.isDarkMode
          ? const Color(0x1AFFFFFF)
          : const Color(0xCCFFFFFF),
      actions: [
        IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload'),
        if (_isOwner)
          PopupMenuButton<String>(
            onSelected: (val) {
              switch (val) {
                case 'edit':
                  _openEditRequestSheet();
                  break;
                case 'edit_full':
                  _navigateToRequestEdit();
                  break;
                case 'status':
                  _toggleStatus();
                  break;
                case 'delete':
                  _confirmDeleteRequest();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('Quick Edit')),
              const PopupMenuItem(
                  value: 'edit_full', child: Text('Full Edit Screen')),
              PopupMenuItem(
                  value: 'status',
                  child: Text(_request!.status.toLowerCase() == 'active'
                      ? 'Close Request'
                      : 'Reopen Request')),
              const PopupMenuItem(
                  value: 'delete', child: Text('Delete Request')),
            ],
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(r.title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(r.description,
                      style: TextStyle(color: Colors.grey[700], height: 1.4)),

                  // Debug subscription banner logic
                  ...() {
                    final currentUserId =
                        RestAuthService.instance.currentUser?.uid;
                    final hasResponded = _responses
                        .any((response) => response.userId == currentUserId);
                    final isOwner = currentUserId == r.userId;
                    final canRespond = _entitlements?.canRespond ?? true;
                    print(
                        'DEBUG Banner: entitlements=${_entitlements != null}, canRespond=$canRespond, isOwner=$isOwner, hasResponded=$hasResponded, responsesCount=${_responses.length}');
                    return <Widget>[];
                  }(),

                  // Subscription limit banner - only show if user hasn't responded to this request
                  if (_entitlements != null &&
                      !_entitlements!.canRespond &&
                      RestAuthService.instance.currentUser?.uid != r.userId &&
                      !_responses.any((response) =>
                          response.userId ==
                          RestAuthService.instance.currentUser?.uid)) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.1),
                            Colors.orange.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.star,
                                    color: Colors.orange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Response Limit Reached',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'ve reached your monthly limit of 3 responses. Subscribe to continue responding to requests and view contact details.',
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _navigateToSubscriptionPlans();
                            },
                            icon: const Icon(Icons.star),
                            label: const Text('View Subscription Plans'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Images Section
                  if (r.imageUrls != null && r.imageUrls!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Images',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        // Clean and filter valid image URLs
                        final validImageUrls =
                            ImageUrlHelper.cleanImageUrls(r.imageUrls);

                        if (validImageUrls.isEmpty) {
                          return Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported,
                                      color: Colors.grey[400], size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No valid images available',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (r.imageUrls!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r.imageUrls!.length} invalid URL(s) filtered out',
                                      style: TextStyle(
                                        color: Colors.orange[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        return SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: validImageUrls.length,
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () =>
                                  _showImageFullScreen(validImageUrls[index]),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  // Border removed
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SmartNetworkImage(
                                    imageUrl: validImageUrls[index],
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Debug the image URL issue
                                      ImageUrlHelper.debugImageUrl(
                                          r.imageUrls![index]);
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                                Icons.image_not_supported),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Load Error',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${index + 1}/${validImageUrls.length}',
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip(Icons.category, r.categoryName ?? r.categoryId),
                    if (r.cityName != null)
                      _chip(Icons.location_on, r.cityName!),
                    _chip(Icons.flag, r.countryCode),
                    _chip(Icons.access_time, _relativeTime(r.createdAt)),
                    _chip(Icons.info_outline, r.status.toUpperCase()),
                    if (r.isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.priority_high,
                                size: 14, color: Colors.redAccent),
                            SizedBox(width: 4),
                            Text('Urgent',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ]),

                  // Requester Information Section
                  const SizedBox(height: 20),
                  const Text('Requester Information',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show only one subscribe prompt if user has reached their limit and hasn't responded
                        if (!_isOwner &&
                            _entitlements != null &&
                            (!_entitlements!.canSendMessages ||
                                !_entitlements!.canRespond) &&
                            !_responses.any((response) =>
                                response.userId ==
                                RestAuthService.instance.currentUser?.uid))
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 24, color: Colors.amber.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Subscribe to view details and message instantly.',
                                    style: TextStyle(
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Row(children: [
                            _buildRequesterAvatar(r),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if ((r.userId).isNotEmpty) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PublicProfileScreen(
                                            userId: r.userId),
                                      ),
                                    );
                                  }
                                },
                                child: Text(r.userName ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ),
                            // Debug message icon visibility
                            ...() {
                              final canMessage =
                                  _entitlements?.canSendMessages ?? true;
                              print(
                                  'DEBUG Message Icon: isOwner=$_isOwner, canSendMessages=$canMessage, membershipCompleted=$_membershipCompleted');
                              return <Widget>[];
                            }(),
                            if (!_isOwner)
                              IconButton(
                                onPressed: () => _messageRequester(r),
                                icon: Icon(
                                  Icons.message,
                                  color:
                                      _getTypeColor(_getCurrentRequestType()),
                                  size: 20,
                                ),
                                tooltip: 'Message Requester',
                              ),
                          ]),
                        ],
                        const SizedBox(height: 8),
                        if (r.contactVisible &&
                            (r.userPhone?.isNotEmpty == true) &&
                            (_entitlements?.canSeeContactDetails == true))
                          Row(children: [
                            Icon(Icons.phone,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(r.userPhone!,
                                  style: TextStyle(color: Colors.grey[700])),
                            ),
                          ]),
                        // Show subscription prompt if contact details are hidden due to limits
                        if (r.contactVisible &&
                            (r.userPhone?.isNotEmpty == true) &&
                            (_entitlements?.canSeeContactDetails == false))
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.withOpacity(0.08),
                                  Colors.orange.withOpacity(0.04),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.visibility_off,
                                    size: 16, color: Colors.orange[600]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Contact details hidden. Subscribe to view.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextButton(
                                  onPressed: () async {
                                    final reqType = (_request?.requestType ??
                                            _request?.categoryType ??
                                            '')
                                        .toString()
                                        .toLowerCase();
                                    final isRide = reqType.contains('ride');
                                    await QuickUpgradeSheet.show(context,
                                        isRide ? 'driver' : 'business');
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                  ),
                                  child: const Text('Subscribe',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),

                  // Location Information Section
                  if (r.locationAddress != null &&
                      r.locationAddress!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Location Information',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.location_on,
                                size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(r.locationAddress!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          // Coordinates intentionally hidden per requirement: show only human-readable location
                        ],
                      ),
                    ),
                  ],

                  // Request Details Section
                  if (r.metadata != null && r.metadata!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Request Details',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Budget first
                          if (r.budget != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    width: 80,
                                    child: Text('Budget:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12)),
                                  ),
                                  Expanded(
                                    child: Text(_formatBudget(r),
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          // Service module context (if applicable)
                          if (_getCurrentRequestType() == RequestType.service)
                            ..._buildServiceModuleContext(r),
                          // Then metadata entries with proper formatting (excluding IDs)
                          ...r.metadata!.entries
                              .where((e) => !_shouldHideField(e.key))
                              .take(10)
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 80,
                                            child: Text('${_formatKey(e.key)}:',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12)),
                                          ),
                                          Expanded(
                                            child: Text(_formatValue(e.value),
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                          ),
                                        ]),
                                  )),
                          if (r.metadata!.length > 10)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                  '+${r.metadata!.length - 10} more details',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_isOwner) ...[
                    const SizedBox(height: 24),
                    Row(children: [
                      if (_updatingRequest)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      Text('Status: ${r.status}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      TextButton.icon(
                          onPressed: _toggleStatus,
                          icon: Icon(
                              r.status.toLowerCase() == 'active'
                                  ? Icons.lock
                                  : Icons.lock_open,
                              size: 16),
                          label: Text(r.status.toLowerCase() == 'active'
                              ? 'Close'
                              : 'Reopen')),
                      TextButton.icon(
                          onPressed: _navigateToRequestEdit,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit')),
                      TextButton.icon(
                          onPressed: _confirmDeleteRequest,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete')),
                    ]),
                    const SizedBox(height: 8),
                    _ownerActions(),
                  ],
                ])),
            const SizedBox(height: 20),
            _responsesSection(),
          ]),
        ),
      ),
      floatingActionButton: fab,
    );
  }

  Widget _sectionCard({required Widget child}) => GlassTheme.glassCard(
        padding: const EdgeInsets.all(20),
        child: child,
      );

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatBudget(rest.RequestModel r) {
    final cur = r.currency ?? '';
    if (r.budget == null) return 'No budget';
    return '$cur${r.budget!.toStringAsFixed(0)}';
  }

  String _formatKey(String key) {
    // Convert camelCase to readable text
    switch (key.toLowerCase()) {
      case 'itemname':
        return 'Item Name';
      case 'categoryid':
        return 'Category ID';
      case 'subcategoryid':
      case 'subcategory_id':
        return 'Subcategory ID';
      case 'startdate':
        return 'Start Date';
      case 'enddate':
        return 'End Date';
      case 'pickupdropoffpreference':
        return 'Pickup/Dropoff';
      default:
        // Convert camelCase to space-separated words
        return key
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .trim()
            .split(' ')
            .map((word) =>
                word[0].toUpperCase() + word.substring(1).toLowerCase())
            .join(' ');
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';

    // Handle list values
    if (value is List) {
      try {
        return value.map((e) => _formatValue(e)).join(', ');
      } catch (_) {
        return value.join(', ');
      }
    }

    // Handle timestamp values (large numbers that look like epoch timestamps)
    if (value is int && value > 1000000000000) {
      try {
        final date = DateTime.fromMillisecondsSinceEpoch(value);
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } catch (e) {
        return value.toString();
      }
    }

    // Handle boolean values
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    // Handle RequestType enum values
    if (value.toString().startsWith('RequestType.')) {
      return value.toString().split('.').last.toUpperCase();
    }

    return value.toString();
  }

  bool _shouldHideField(String key) {
    final keyLower = key.toLowerCase();

    // Hide internal ID fields that users don't need to see
    final hiddenFields = [
      'categoryId',
      'categoryid',
      'category_id',
      'subCategoryId',
      'subcategoryId',
      'subcategory_id',
      'subcategoryid',
      'sub_category_id',
      'type', // Also hide the type since it's already shown in the header
      // hide service module metadata keys because we render a nicer section
      'module',
      'modulefields',
    ];

    // Also hide any field that ends with "id" or contains "categoryid" or "subcategoryid"
    final shouldHide = hiddenFields.contains(keyLower) ||
        keyLower.endsWith('id') &&
            (keyLower.contains('category') || keyLower.contains('subcategory'));

    return shouldHide;
  }

  List<Widget> _buildServiceModuleContext(rest.RequestModel r) {
    final meta = r.metadata ?? {};
    final rawModule = meta['module']?.toString();
    final module = rawModule == null || rawModule.isEmpty
        ? (meta['typeSpecificData'] is Map
            ? (meta['typeSpecificData']['module']?.toString())
            : null)
        : rawModule;
    final fields = meta['moduleFields'] ??
        (meta['typeSpecificData'] is Map
            ? meta['typeSpecificData']['moduleFields']
            : null);

    if (module == null || module.isEmpty) return const [];

    String prettyLabel(String key) {
      switch (key) {
        // Construction module
        case 'projectLocationNote':
          return 'Location Notes';
        case 'preferredStartDate':
          return 'Preferred Start Date';
        case 'propertyArea':
          return 'Property Size / Area';
        case 'numberOfFloors':
          return 'Number of Floors';
        case 'plansStatus':
          return 'Status of Plans';
        case 'scopeOfWork':
          return 'Scope of Work';
        case 'approxMeasurements':
          return 'Approximate Measurements';
        case 'itemsList':
          return 'List of Items';
        case 'rentalStartDate':
          return 'Rental Start Date';
        case 'rentalEndDate':
          return 'Rental End Date';
        case 'deliveryRequired':
          return 'Delivery Required';
        case 'propertyType':
          return 'Type of Property';
        case 'landSize':
          return 'Land Size';
        // Tours module common
        case 'startDate':
          return 'Start Date';
        case 'endDate':
          return 'End Date';
        case 'adults':
          return 'Adults';
        case 'children':
          return 'Children';
        // Tours & Experiences
        case 'tourType':
          return 'Tour Type';
        case 'preferredLanguage':
          return 'Preferred Language';
        case 'otherLanguage':
          return 'Other Language';
        case 'timeOfDayPrefs':
          return 'Preferred Time';
        case 'jeepIncluded':
          return 'Jeep Included?';
        case 'skillLevel':
          return 'Skill Level';
        // Transportation
        case 'transportType':
          return 'Type of Transport';
        case 'transportPickup':
          return 'Pickup Location';
        case 'transportDropoff':
          return 'Drop-off Location';
        case 'vehicleTypes':
          return 'Vehicle Types';
        case 'luggage':
          return 'Luggage';
        case 'itinerary':
          return 'Itinerary';
        case 'flightNumber':
          return 'Flight Number';
        case 'flightTime':
          return 'Flight Time';
        case 'licenseConfirmed':
          return 'License Confirmed';
        // Accommodation
        case 'accommodationType':
          return 'Accommodation Type';
        case 'unitsCount':
          return 'Units Count';
        case 'unitsType':
          return 'Units Type';
        case 'amenities':
          return 'Amenities';
        case 'boardBasis':
          return 'Board Basis';
        case 'cookStaffRequired':
          return 'Cook/Staff Required';
        case 'mealsWithHostFamily':
          return 'Meals with Host Family';
        case 'hostelRoomType':
          return 'Hostel Room Type';
        // Events general
        case 'eventType':
          return 'Event Type';
        case 'dateOfEvent':
          return 'Event Date';
        case 'startTime':
          return 'Start Time';
        case 'endTime':
          return 'End Time';
        // Events: Venues
        case 'venueType':
          return 'Venue Type';
        case 'requiredFacilities':
          return 'Required Facilities';
        // Events: Food & Beverage
        case 'cuisineTypes':
          return 'Cuisine Types';
        case 'serviceStyle':
          return 'Service Style';
        case 'dietaryNeeds':
          return 'Dietary Requirements';
        // Events: Entertainment & Talent
        case 'talentType':
          return 'Talent Type';
        case 'durationRequired':
          return 'Duration Required';
        // Events: Services & Staff
        case 'staffType':
          return 'Staff Type';
        case 'numberOfStaff':
          return 'Number of Staff';
        case 'hoursRequired':
          return 'Hours Required';
        // Events: Rentals & Supplies
        case 'requiredServices':
          return 'Required Services';
        case 'peopleCount':
          return 'People Count';
        case 'durationDays':
          return 'Duration (days)';
        case 'needsGuide':
          return 'Needs Guide';
        case 'pickupRequired':
          return 'Pickup Required';
        case 'guestsCount':
          return 'Guests Count';
        case 'areaSizeSqft':
          return 'Area Size (sqft)';
        case 'level':
          return 'Level';
        // Education general
        case 'studentLevel':
          return 'Student Level';
        case 'preferredMode':
          return 'Preferred Mode';
        case 'numberOfStudents':
          return 'Number of Students';
        case 'sessionsPerWeek':
          return 'Sessions/Week';
        case 'detailedNeeds':
          return 'Detailed Needs';
        // Education: Academic Tutoring
        case 'subjects':
          return 'Subject(s)';
        case 'syllabus':
          return 'Syllabus';
        case 'syllabusOther':
          return 'Syllabus (Other)';
        // Education: Professional & Skill Development
        case 'courseOrSkill':
          return 'Course/Skill';
        case 'desiredOutcome':
          return 'Desired Outcome';
        // Education: Arts & Hobbies
        case 'artOrSport':
          return 'Art/Sport';
        case 'classType':
          return 'Class Type';
        // Education: Admissions & Consulting
        case 'targetCountry':
          return 'Target Country';
        case 'fieldOfStudy':
          return 'Field of Study';
        case 'positionType':
          return 'Position Type';
        case 'experienceYears':
          return 'Experience (years)';
        // Hiring extended
        case 'jobTitle':
          return 'Job Title';
        case 'companyName':
          return 'Company';
        case 'workArrangement':
          return 'Work Arrangement';
        case 'salary':
          return 'Salary / Pay';
        case 'payPeriod':
          return 'Pay Period';
        case 'salaryNegotiable':
          return 'Salary Negotiable';
        case 'benefits':
          return 'Benefits';
        case 'educationRequirement':
          return 'Minimum Education';
        case 'skills':
          return 'Key Skills';
        case 'applyMethod':
          return 'How to Apply';
        case 'contactPerson':
          return 'Contact Person';
        case 'contactPhone':
          return 'Contact Phone';
        case 'applicationDeadline':
          return 'Application Deadline';
        default:
          return key
              .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
              .replaceAll('_', ' ')
              .trim()
              .split(' ')
              .map((w) => w.isEmpty
                  ? w
                  : w[0].toUpperCase() + w.substring(1).toLowerCase())
              .join(' ');
      }
    }

    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Icon(Icons.category, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              'Service Module: ${module[0].toUpperCase()}${module.substring(1)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ];
    final skipKeys = {'estimatedBudget'}; // budget shown separately
    fields.forEach((k, v) {
      if (skipKeys.contains(k)) return;
      if (v == null || (v is String && v.toString().trim().isEmpty)) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text('${prettyLabel(k)}:',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12)),
              ),
              Expanded(
                child:
                    Text(_formatValue(v), style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    });

    return widgets;
  }

  Widget _responsesSection() {
    // Compute cheapest price
    // Removed cheapest price computation per requirement

    final typeColor = _getTypeColor(_getCurrentRequestType());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Responses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_responses.isNotEmpty && _isOwner)
                TextButton(
                  onPressed: _navigateToViewAllResponses,
                  child: const Text('View All'),
                ),
              IconButton(
                tooltip: 'Reload',
                icon: const Icon(Icons.refresh),
                onPressed: _responsesLoading ? null : _reloadResponses,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_responsesLoading)
            const SizedBox(
              height: 24,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (!_responsesLoading) ...[
            if (_responses.isEmpty)
              Text(
                _canRespond ? 'Be the first to respond.' : 'No responses yet.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            if (_responses.isNotEmpty)
              Row(
                children: [
                  _infoChip(
                    label: 'Total',
                    value: _responses.length.toString(),
                    color: typeColor,
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(
          {required String label,
          required String value,
          required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // Removed individual response tiles & accept/unaccept logic per new privacy requirement.
}
