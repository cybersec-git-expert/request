import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../widgets/glass_page.dart';
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart';
import '../../services/enhanced_request_service.dart';
import '../../services/messaging_service.dart';
import '../messaging/conversation_screen.dart';
import 'unified_response_view_screen.dart';
import '../account/public_profile_screen.dart';
import '../../services/rest_request_service.dart' show ReviewsService;

class ViewAllResponsesScreen extends StatefulWidget {
  final RequestModel request;

  const ViewAllResponsesScreen({
    super.key,
    required this.request,
  });

  @override
  State<ViewAllResponsesScreen> createState() => _ViewAllResponsesScreenState();
}

class _ViewAllResponsesScreenState extends State<ViewAllResponsesScreen> {
  final EnhancedRequestService _requestService = EnhancedRequestService();
  List<ResponseModel> _responses = [];
  Map<String, UserModel> _responders = {};
  bool _isLoading = true;
  String _sortBy = 'date'; // 'date', 'price_low', 'price_high'
  final Map<String, Map<String, dynamic>> _reviewStats =
      {}; // userId -> { average_rating, review_count }
  final Set<String> _statsLoading = {};

  // Safely convert dynamic API values (num or string like "0.00") to double
  double _asDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    try {
      // Fetch responses; these already include joined user_name/email/phone in additionalInfo
      final responses =
          await _requestService.getResponsesForRequest(widget.request.id);

      setState(() {
        _responses = responses.cast<ResponseModel>();
        _responders = const {}; // avoid per-user fetch to prevent 403s
        _isLoading = false;
      });

      _sortResponses();
    } catch (e) {
      print('Error loading responses: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading responses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sortResponses() {
    setState(() {
      switch (_sortBy) {
        case 'price_low':
          _responses.sort((a, b) {
            final priceA = a.price ?? 0.0;
            final priceB = b.price ?? 0.0;
            return priceA.compareTo(priceB);
          });
          break;
        case 'price_high':
          _responses.sort((a, b) {
            final priceA = a.price ?? 0.0;
            final priceB = b.price ?? 0.0;
            return priceB.compareTo(priceA);
          });
          break;
        case 'date':
        default:
          _responses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }
    });
  }

  String _getTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'item':
        return 'Item';
      case 'service':
        return 'Service';
      case 'delivery':
        return 'Delivery';
      case 'ride':
        return 'Ride';
      case 'rental':
        return 'Rental';
      case 'price':
        return 'Price';
      default:
        return type;
    }
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

  Widget _buildResponseItem(ResponseModel response, UserModel? responder) {
    final anyAccepted = _responses.any((r) => r.isAccepted);
    // Fallbacks from additionalInfo (populated by REST layer)
    final addl = response.additionalInfo;
    final fallbackName = addl['responder_name']?.toString();
    final fallbackEmail = addl['responder_email']?.toString();
    final fallbackPhone = addl['responder_phone']?.toString();
    final module = widget.request.type == RequestType.service
        ? (widget.request.typeSpecificData['module']?.toString() ?? '')
        : '';

    // Lazy-load review stats per responder
    final uid = response.responderId;
    Map<String, dynamic>? stats = _reviewStats[uid];
    if (stats == null && !_statsLoading.contains(uid) && uid.isNotEmpty) {
      _statsLoading.add(uid);
      ReviewsService.instance.getUserReviewStats(uid).then((value) {
        if (!mounted) return;
        if (value != null) {
          setState(() {
            _reviewStats[uid] = value;
          });
        }
        _statsLoading.remove(uid);
      }).catchError((_) {
        if (mounted) setState(() => _statsLoading.remove(uid));
      });
    }
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnifiedResponseViewScreen(
                  request: widget.request,
                  response: response,
                ),
              ),
            );
          },
          child: GlassTheme.glassCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with responder info and status
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final uid = response.responderId;
                          if (uid.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PublicProfileScreen(userId: uid),
                              ),
                            );
                          }
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[200],
                          child: Text(
                            (responder != null && responder.name.isNotEmpty)
                                ? responder.name[0]
                                : (fallbackName != null &&
                                        fallbackName.isNotEmpty
                                    ? fallbackName[0]
                                    : 'U'),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final uid = response.responderId;
                                if (uid.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PublicProfileScreen(userId: uid),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                responder?.name ??
                                    fallbackName ??
                                    'Unknown User',
                                style: GlassTheme.titleSmall,
                              ),
                            ),
                            if (stats != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _stars(_asDouble(stats['average_rating'])),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${(stats['review_count'] ?? 0).toString()})',
                                    style: GlassTheme.bodySmall.copyWith(
                                        color: GlassTheme.colors.textTertiary),
                                  ),
                                ],
                              ),
                            ],
                            Text(
                              'Response to ${_getTypeDisplayName(widget.request.type.toString().split('.').last)}',
                              style: GlassTheme.bodySmall,
                            ),
                            if (((responder?.email ?? '').isNotEmpty) ||
                                ((fallbackEmail ?? '').isNotEmpty)) ...[
                              Text(
                                responder?.email ?? fallbackEmail ?? '',
                                style: GlassTheme.bodySmall.copyWith(
                                  color: GlassTheme.colors.textTertiary,
                                ),
                              ),
                            ],
                            if ((fallbackPhone ?? '').isNotEmpty) ...[
                              Text(
                                fallbackPhone!,
                                style: GlassTheme.bodySmall.copyWith(
                                  color: GlassTheme.colors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildStatusBadge(response),
                      IconButton(
                        onPressed: () => _startConversation(
                            response.responderId, responder?.name ?? 'User'),
                        icon: Icon(
                          Icons.message,
                          color: _getTypeColor(widget.request.type),
                        ),
                        tooltip: 'Message',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Module badge for service requests
                  if (module.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.blueGrey.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.category,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            'Module: ${module[0].toUpperCase()}${module.substring(1)}',
                            style: GlassTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Price
                  if (response.price != null) ...[
                    Text(
                      '${response.currency ?? 'LKR'} ${_formatPrice(response.price!)}',
                      style: GlassTheme.titleMedium.copyWith(
                        color: GlassTheme.colors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Message preview
                  Text(
                    response.message,
                    style: GlassTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Additional details
                  if (response.availableFrom != null ||
                      response.availableUntil != null) ...[
                    Row(
                      children: [
                        if (response.availableFrom != null) ...[
                          Icon(Icons.calendar_today,
                              size: 14, color: GlassTheme.colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'From: ${response.availableFrom!.day}/${response.availableFrom!.month}/${response.availableFrom!.year}',
                            style: GlassTheme.bodySmall,
                          ),
                        ],
                        if (response.availableFrom != null &&
                            response.availableUntil != null)
                          const SizedBox(width: 16),
                        if (response.availableUntil != null) ...[
                          Icon(Icons.event,
                              size: 14, color: GlassTheme.colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Until: ${response.availableUntil!.day}/${response.availableUntil!.month}/${response.availableUntil!.year}',
                            style: GlassTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Images indicator
                  if (response.images.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.photo,
                            size: 14, color: GlassTheme.colors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${response.images.length} image${response.images.length > 1 ? 's' : ''}',
                          style: GlassTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Accept button hidden if any response is accepted for this request
                  if (!anyAccepted &&
                      !response.isAccepted &&
                      response.rejectionReason == null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _acceptResponse(response),
                        icon: const Icon(Icons.check),
                        label: const Text('Accept Response'),
                        style: OutlinedButton.styleFrom(
                          side:
                              BorderSide(color: GlassTheme.colors.glassBorder),
                          foregroundColor: GlassTheme.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (response.isAccepted)
          Positioned(
            right: 12,
            bottom: 10,
            child: _acceptedCornerIcon(),
          ),
      ],
    );
  }

  Widget _acceptedCornerIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: const Icon(Icons.verified, color: Colors.white, size: 16),
    );
  }

  Widget _stars(double avg) {
    final rounded = avg.isNaN ? 0 : avg.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rounded ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ResponseModel response) {
    if (response.isAccepted) {
      return Text(
        'Accepted',
        style: GlassTheme.bodySmall.copyWith(
          color: GlassTheme.colors.successColor,
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (response.rejectionReason != null) {
      return Text(
        'Rejected',
        style: GlassTheme.bodySmall.copyWith(
          color: GlassTheme.colors.errorColor,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      return Text(
        'Pending',
        style: GlassTheme.bodySmall.copyWith(
          color: GlassTheme.colors.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '';
    double? priceValue =
        price is double ? price : double.tryParse(price.toString());
    if (priceValue == null) return '';

    if (priceValue == priceValue.roundToDouble()) {
      return priceValue.round().toString();
    } else {
      return priceValue.toString();
    }
  }

  void _startConversation(String responderId, String responderName) async {
    try {
      // Fallback in case responderId is empty
      final id = (responderId.isNotEmpty)
          ? responderId
          : (_responses.isNotEmpty ? _responses.first.responderId : '');

      if (id.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to start chat: no responder id')),
          );
        }
        return;
      }

      // Immediate feedback so users see the tap did something
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Opening chat...'),
              duration: Duration(milliseconds: 800)),
        );
      }

      final conversation = await MessagingService().getOrCreateConversation(
        requestId: widget.request.id,
        requestTitle: widget.request.title,
        requesterId: widget.request.requesterId,
        responderId: id,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationScreen(
              conversation: conversation,
              request: widget.request,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting conversation: $e')),
        );
      }
    }
  }

  void _acceptResponse(ResponseModel response) async {
    try {
      final ok =
          await _requestService.acceptResponse(response.requestId, response.id);

      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Response accepted successfully')),
          );
          _loadResponses();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to accept response')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting response: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Responses (${_responses.length})',
      appBarBackgroundColor: GlassTheme.isDarkMode
          ? const Color(0x1AFFFFFF)
          : const Color(0xCCFFFFFF),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              _sortBy = value;
            });
            _sortResponses();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'date',
              child: Text('Sort by Date'),
            ),
            const PopupMenuItem(
              value: 'price_low',
              child: Text('Price: Low to High'),
            ),
            const PopupMenuItem(
              value: 'price_high',
              child: Text('Price: High to Low'),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.sort),
          ),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _responses.isEmpty
              ? Center(
                  child: Text(
                    'No responses yet',
                    style: GlassTheme.bodyLarge.copyWith(
                      color: GlassTheme.colors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _responses.length,
                  itemBuilder: (context, index) {
                    final response = _responses[index];
                    final responder = _responders[response.responderId];
                    return _buildResponseItem(response, responder);
                  },
                ),
    );
  }
}
