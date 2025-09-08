import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../widgets/glass_page.dart';
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart';
import '../../services/enhanced_request_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/messaging_service.dart';
import '../messaging/conversation_screen.dart';
import 'unified_response_edit_screen.dart';
import '../../utils/module_field_localizer.dart';
import '../../widgets/smart_network_image.dart';
import '../../services/rest_user_service.dart';

class UnifiedResponseViewScreen extends StatefulWidget {
  final RequestModel request;
  final ResponseModel response;

  const UnifiedResponseViewScreen({
    super.key,
    required this.request,
    required this.response,
  });

  @override
  State<UnifiedResponseViewScreen> createState() =>
      _UnifiedResponseViewScreenState();
}

class _UnifiedResponseViewScreenState extends State<UnifiedResponseViewScreen> {
  final EnhancedRequestService _requestService = EnhancedRequestService();
  final EnhancedUserService _userService = EnhancedUserService();

  UserModel? _currentUser;
  UserModel? _responder;
  String? _responderNameFallback;
  String? _responderEmailFallback;
  String? _responderPhoneFallback;
  bool _anyAcceptedForRequest = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _responderPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final currentUser = await _userService.getCurrentUserModel();
      UserModel? responder;
      try {
        responder = await _userService.getUserById(widget.response.responderId);
      } catch (_) {
        responder = null;
      }
      if (responder == null) {
        final info = widget.response.additionalInfo;
        _responderNameFallback = info['responder_name']?.toString();
        _responderEmailFallback = info['responder_email']?.toString();
        _responderPhoneFallback = info['responder_phone']?.toString();
      }
      // Defer avatar fetch until after frame
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final profile = await RestUserService.instance
              .getPublicProfile(widget.response.responderId);
          if (!mounted) return;
          setState(() => _responderPhotoUrl = profile?.photoUrl);
        } catch (_) {}
      });

      // Fetch responses to determine if any has been accepted
      try {
        final page =
            await _requestService.getResponsesForRequest(widget.request.id);
        _anyAcceptedForRequest = page.any((r) => r.isAccepted);
      } catch (_) {
        _anyAcceptedForRequest = widget.response.isAccepted;
      }

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _responder = responder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading response details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptResponse() async {
    if (_isProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Response'),
        content: const Text('Are you sure you want to accept this response?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final ok = await _requestService.acceptResponse(
          widget.response.requestId, widget.response.id);

      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Response accepted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept response'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting response: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _rejectResponse() async {
    if (_isProcessing) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Response'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Rejection reason...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, reasonController.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _requestService.rejectResponse(widget.response.id, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response rejected successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting response: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _editResponse() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedResponseEditScreen(
          request: widget.request,
          response: widget.response,
        ),
      ),
    ).then((updated) async {
      if (updated is ResponseModel) {
        setState(() {
          // Replace response with updated one
          widget.response.additionalInfo.clear();
        });
        // Rebuild with new instance by recreating state variables
        setState(() {
          // Can't reassign final field; instead create a shallow copy via local variable usage in builders.
        });
      }
      await _loadData();
    });
  }

  String _getTypeDisplayName(RequestType type) {
    switch (type) {
      case RequestType.item:
        return 'Item Request';
      case RequestType.service:
        return 'Service Request';
      case RequestType.rental:
        return 'Rental Request';
      case RequestType.delivery:
        return 'Delivery Request';
      case RequestType.ride:
        return 'Ride Request';
      case RequestType.price:
        return 'Price Request';
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

  Widget _buildActionButtons() {
    final isRequester = _currentUser?.id == widget.request.requesterId;

    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    // Hide actions if any response is already accepted for this request
    if (isRequester && !widget.response.isAccepted && !_anyAcceptedForRequest) {
      // Requester can accept or reject pending responses
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _acceptResponse,
              icon: const Icon(Icons.check),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _rejectResponse,
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusBadge() {
    if (widget.response.isAccepted) {
      return const Text(
        'Accepted',
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    } else if (widget.response.rejectionReason != null) {
      return const Text(
        'Rejected',
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    } else {
      return const Text(
        'Pending',
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }
  }

  Widget _buildTypeSpecificDetails() {
    final additionalInfo = widget.response.additionalInfo;

    switch (widget.request.type) {
      case RequestType.rental:
        return _buildRentalDetails(additionalInfo);
      case RequestType.item:
        return _buildItemDetails(additionalInfo);
      case RequestType.service:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show request module context and moduleFields so the response is read in context
            _buildRequestModuleContext(),
            const SizedBox(height: 12),
            _buildServiceDetails(additionalInfo),
          ],
        );
      case RequestType.delivery:
        return _buildDeliveryDetails(additionalInfo);
      case RequestType.ride:
        return _buildRideDetails(additionalInfo);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRentalDetails(Map<String, dynamic> info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info['rentalPeriod'] != null) ...[
          _buildDetailRow('Rental Period', info['rentalPeriod']),
          const SizedBox(height: 8),
        ],
        if (info['securityDeposit'] != null) ...[
          _buildDetailRow('Security Deposit',
              '${widget.response.currency ?? 'LKR'} ${_formatPrice(info['securityDeposit'])}'),
          const SizedBox(height: 8),
        ],
        if (info['itemCondition'] != null) ...[
          _buildDetailRow('Item Condition', info['itemCondition']),
          const SizedBox(height: 8),
        ],
        if (info['pickupDeliveryOption'] != null) ...[
          _buildDetailRow('Pickup/Delivery', info['pickupDeliveryOption']),
        ],
      ],
    );
  }

  Widget _buildItemDetails(Map<String, dynamic> info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info['offerDescription'] != null) ...[
          _buildDetailRow('Description', info['offerDescription']),
          const SizedBox(height: 8),
        ],
        if (info['itemCondition'] != null) ...[
          _buildDetailRow('Condition', info['itemCondition']),
          const SizedBox(height: 8),
        ],
        if (info['deliveryMethod'] != null) ...[
          _buildDetailRow('Delivery Method', info['deliveryMethod']),
          const SizedBox(height: 8),
        ],
        if (info['deliveryCost'] != null) ...[
          _buildDetailRow('Delivery Cost',
              '${widget.response.currency ?? 'LKR'} ${_formatPrice(info['deliveryCost'])}'),
          const SizedBox(height: 8),
        ],
        if (info['estimatedDelivery'] != null) ...[
          _buildDetailRow(
              'Estimated Delivery', '${info['estimatedDelivery']} days'),
          const SizedBox(height: 8),
        ],
        if (info['warranty'] != null) ...[
          _buildDetailRow('Warranty', info['warranty']),
        ],
      ],
    );
  }

  Widget _buildServiceDetails(Map<String, dynamic> info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info['priceType'] != null) ...[
          _buildDetailRow('Price Type', info['priceType']),
          const SizedBox(height: 8),
        ],
        if (info['timeframe'] != null) ...[
          _buildDetailRow('Timeframe', info['timeframe']),
        ],
      ],
    );
  }

  // Renders the request's service module and any captured moduleFields for added context
  Widget _buildRequestModuleContext() {
    final tsd = widget.request.typeSpecificData;
    final module = tsd['module']?.toString();
    final fields = tsd['moduleFields'];
    if (module == null || module.isEmpty) return const SizedBox.shrink();

    List<Widget> fieldRows = [];
    if (fields is Map) {
      fields.forEach((k, v) {
        if (v == null || (v is String && v.toString().trim().isEmpty)) return;
        fieldRows.add(
            _buildDetailRow(ModuleFieldLocalizer.getLabel(k), v.toString()));
        fieldRows.add(const SizedBox(height: 6));
      });
      if (fieldRows.isNotEmpty) {
        fieldRows.removeLast(); // remove trailing SizedBox
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                'Service Module: ${module[0].toUpperCase()}${module.substring(1)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (fieldRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...fieldRows,
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails(Map<String, dynamic> info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info['vehicleType'] != null) ...[
          _buildDetailRow('Vehicle Type', info['vehicleType']),
          const SizedBox(height: 8),
        ],
        if (info['estimatedPickupTime'] != null) ...[
          _buildDetailRow(
            'Pickup Date',
            _formatEpochDate(info['estimatedPickupTime']),
          ),
          const SizedBox(height: 8),
        ],
        if (info['estimatedDropoffTime'] != null) ...[
          _buildDetailRow(
            'Drop-off Date',
            _formatEpochDate(info['estimatedDropoffTime']),
          ),
          const SizedBox(height: 8),
        ],
        if (info['specialInstructions'] != null &&
            (info['specialInstructions'] as String).trim().isNotEmpty) ...[
          _buildDetailRow('Special Instructions', info['specialInstructions']),
        ],
      ],
    );
  }

  Widget _buildRideDetails(Map<String, dynamic> info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info['vehicleType'] != null) ...[
          _buildDetailRow('Vehicle Type', info['vehicleType']),
          const SizedBox(height: 8),
        ],
        if (info['routeDescription'] != null) ...[
          _buildDetailRow('Route', info['routeDescription']),
          const SizedBox(height: 8),
        ],
        if (info['driverNotes'] != null &&
            (info['driverNotes'] as String).trim().isNotEmpty) ...[
          _buildDetailRow('Driver Notes', info['driverNotes']),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '';
    double? priceValue =
        price is double ? price : double.tryParse(price.toString());
    if (priceValue == null) return '';

    // Remove unnecessary decimal places
    if (priceValue == priceValue.roundToDouble()) {
      return priceValue.round().toString();
    } else {
      return priceValue.toString();
    }
  }

  String _formatEpochDate(dynamic value) {
    try {
      int? ms;
      if (value is int) {
        ms = value;
      } else if (value is String) {
        ms = int.tryParse(value);
      }
      if (ms == null) return value.toString();
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return value.toString();
    }
  }

  void _startConversation() async {
    try {
      // Fallback to response.responderId if user lookup failed
      final responderId = _responder?.id ?? widget.response.responderId;
      if (responderId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to start chat: missing responder')),
          );
        }
        return;
      }

      final conversation = await MessagingService().getOrCreateConversation(
        requestId: widget.request.id,
        requestTitle: widget.request.title,
        requesterId: widget.request.requesterId,
        responderId: responderId,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassPage(
        title: 'Response Details',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassPage(
      title: 'Response to ${_getTypeDisplayName(widget.request.type)}',
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Response status badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Response Status',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Responder information
                  GlassTheme.glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Responder Information',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildResponderAvatar(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _responder?.name ??
                                        _responderNameFallback ??
                                        'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  // Email (if available)
                                  if (((_responder?.email ?? '').isNotEmpty) ||
                                      ((_responderEmailFallback ?? '')
                                          .isNotEmpty)) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.email,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _responder?.email ??
                                                _responderEmailFallback ??
                                                '',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  // Phone (only if available)
                                  if (((_responder?.phoneNumber ?? '')
                                          .isNotEmpty) ||
                                      ((_responderPhoneFallback ?? '')
                                          .isNotEmpty)) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          _responder?.phoneNumber ??
                                              _responderPhoneFallback ??
                                              '',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (widget.response.additionalInfo[
                                              'location_address'] !=
                                          null ||
                                      widget.response.additionalInfo[
                                              'locationAddress'] !=
                                          null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 16, color: Colors.redAccent),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            widget
                                                    .response
                                                    .additionalInfo[
                                                        'location_address']
                                                    ?.toString() ??
                                                widget
                                                    .response
                                                    .additionalInfo[
                                                        'locationAddress']
                                                    ?.toString() ??
                                                '',
                                            style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Message button
                            IconButton(
                              onPressed: () => _startConversation(),
                              icon: Icon(
                                Icons.message,
                                color: _getTypeColor(widget.request.type),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Response details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Response Details',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // Price
                        if (widget.response.price != null) ...[
                          _buildDetailRow('Price',
                              '${widget.response.currency ?? 'LKR'} ${_formatPrice(widget.response.price!)}'),
                          const SizedBox(height: 12),
                        ],

                        // Message
                        _buildDetailRow('Message', widget.response.message),
                        const SizedBox(height: 12),

                        // Availability
                        if (widget.response.availableFrom != null ||
                            widget.response.availableUntil != null) ...[
                          if (widget.response.availableFrom != null)
                            _buildDetailRow('Available From',
                                '${widget.response.availableFrom!.day}/${widget.response.availableFrom!.month}/${widget.response.availableFrom!.year}'),
                          const SizedBox(height: 8),
                          if (widget.response.availableUntil != null)
                            _buildDetailRow('Available Until',
                                '${widget.response.availableUntil!.day}/${widget.response.availableUntil!.month}/${widget.response.availableUntil!.year}'),
                          const SizedBox(height: 12),
                        ],

                        // Type-specific details
                        _buildTypeSpecificDetails(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Images (if any)
                  if (widget.response.images.isNotEmpty ||
                      (widget.response.additionalInfo['images'] is List &&
                          (widget.response.additionalInfo['images'] as List)
                              .isNotEmpty)) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Images',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: (widget.response.images.isNotEmpty
                                      ? widget.response.images
                                      : List<String>.from(widget.response
                                          .additionalInfo['images'] as List))
                                  .length,
                              itemBuilder: (context, index) {
                                final images = widget.response.images.isNotEmpty
                                    ? widget.response.images
                                    : List<String>.from(widget.response
                                        .additionalInfo['images'] as List);
                                return Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      images[index],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Rejection reason (if any)
                  if (widget.response.rejectionReason != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejection Reason',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.response.rejectionReason!,
                            style: TextStyle(color: Colors.red[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  const Spacer(),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: (_currentUser?.id == widget.response.responderId &&
              !widget.response.isAccepted)
          ? FloatingActionButton.extended(
              onPressed: _editResponse,
              backgroundColor: _getTypeColor(widget.request.type),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            )
          : null,
    );
  }

  Widget _buildResponderAvatar() {
    final display = _responder?.name ?? _responderNameFallback ?? 'User';
    final initial =
        display.trim().isNotEmpty ? display.trim()[0].toUpperCase() : 'U';
    const double size = 60;
    final url = _responderPhotoUrl;
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
        backgroundColor: Colors.blue[100],
        child: Text(
          ch,
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
            fontSize: size * 0.33,
          ),
        ),
      );
}
