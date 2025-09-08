import 'package:flutter/material.dart';
import '../../models/enhanced_user_model.dart';
import '../../services/rest_request_service.dart';
import '../../services/country_service.dart';
import '../../services/module_service.dart';
import '../../screens/unified_request_response/unified_request_view_screen.dart';

class BrowseRequestsScreen extends StatefulWidget {
  const BrowseRequestsScreen({super.key});

  @override
  State<BrowseRequestsScreen> createState() => _BrowseRequestsScreenState();
}

class _BrowseRequestsScreenState extends State<BrowseRequestsScreen> {
  String _searchQuery = '';
  RequestType? _selectedType;
  List<RequestModel> _requests = [];
  bool _isLoading = true;
  String? _error;
  String? _currencySymbol;
  CountryModules? _countryModules;
  List<RequestType> _enabledRequestTypes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _currencySymbol = CountryService.instance.getCurrencySymbol();

      // Load country modules configuration
      final countryCode = CountryService.instance.countryCode;
      if (countryCode != null) {
        _countryModules = await ModuleService.getCountryModules(countryCode);
        _enabledRequestTypes = _getEnabledRequestTypes();
      }

      await _loadRequests();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<RequestType> _getEnabledRequestTypes() {
    if (_countryModules == null) return RequestType.values;

    List<RequestType> enabledTypes = [];
    _countryModules!.modules.forEach((moduleId, isEnabled) {
      if (isEnabled) {
        RequestType? type = _getRequestTypeFromModuleId(moduleId);
        if (type != null) {
          enabledTypes.add(type);
        }
      }
    });

    return enabledTypes;
  }

  RequestType? _getRequestTypeFromModuleId(String moduleId) {
    switch (moduleId) {
      case 'item':
        return RequestType.item;
      case 'service':
        return RequestType.service;
      case 'rent':
        return RequestType.rental;
      case 'delivery':
        return RequestType.delivery;
      case 'ride':
        return RequestType.ride;
      case 'price':
        return RequestType.price;
      default:
        return null;
    }
  }

  Future<void> _loadRequests() async {
    try {
      setState(() => _isLoading = true);

      // Use RestRequestService to get requests
      final response = await RestRequestService.instance.getRequests(
        page: 1,
        limit: 50,
        categoryId: null, // Get all categories
      );

      if (response != null && mounted) {
        setState(() {
          _requests = response.requests;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Add color helper methods
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

  Color _getLightTypeColor(RequestType type) {
    switch (type) {
      case RequestType.item:
        return const Color(0xFFFF6B35).withOpacity(0.1); // Light orange/red
      case RequestType.service:
        return const Color(0xFF00BCD4).withOpacity(0.1); // Light teal
      case RequestType.rental:
        return const Color(0xFF2196F3).withOpacity(0.1); // Light blue
      case RequestType.delivery:
        return const Color(0xFF4CAF50).withOpacity(0.1); // Light green
      case RequestType.ride:
        return const Color(0xFFFFC107).withOpacity(0.1); // Light yellow
      case RequestType.price:
        return const Color(0xFF9C27B0).withOpacity(0.1); // Light purple
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light gray background
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Modern Search Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Discover Requests',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find requests that match your skills',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Modern Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  'Search by title, location, description... (use commas to separate)',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Colors.grey[500],
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),

                        // Quick Filter Chips
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All', _selectedType == null),
                              ..._enabledRequestTypes.map((type) =>
                                  _buildFilterChip(_getTypeDisplayName(type),
                                      _selectedType == type)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Results List
                  Expanded(
                    child: _error != null
                        ? _buildErrorWidget()
                        : _buildRequestsList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (label == 'All') {
              _selectedType = null;
            } else {
              _selectedType = _getRequestTypeFromName(label);
            }
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.blue[50],
        checkmarkColor: Colors.blue[600],
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[600] : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.blue[200]! : Colors.grey[300]!,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Error',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    final filteredRequests = _getFilteredRequests();

    if (filteredRequests.isEmpty) {
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
            const Text(
              'No requests found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredRequests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(filteredRequests[index]);
        },
      ),
    );
  }

  // Derive enum RequestType from REST model fields, preferring metadata.module,
  // and fall back to smart heuristics from title/description.
  RequestType _typeOf(RequestModel r) {
    // 1) Prefer explicit database or metadata hints
    final module = r.metadata != null
        ? r.metadata!['module']?.toString().trim().toLowerCase()
        : null;
    final typed = (r.requestType ??
            r.categoryType ??
            (r.metadata != null
                    ? (r.metadata!['request_type'] ?? r.metadata!['type'])
                    : '')
                .toString())
        .trim()
        .toLowerCase();

    String hint = module?.isNotEmpty == true ? module! : typed;
    switch (hint) {
      case 'item':
      case 'items':
      case 'product':
      case 'products':
        return RequestType.item;
      case 'service':
      case 'services':
        return RequestType.service;
      case 'rental':
      case 'rent':
      case 'rentals':
        return RequestType.rental;
      case 'delivery':
      case 'deliver':
      case 'courier':
      case 'parcel':
        return RequestType.delivery;
      case 'ride':
      case 'rides':
      case 'transport':
      case 'trip':
        return RequestType.ride;
      case 'price':
      case 'price_comparison':
      case 'pricing':
        return RequestType.price;
    }

    // 2) Heuristic inference from text when hints are missing/ambiguous
    final text = '${r.title} ${r.description}'.toLowerCase();
    bool matchesAny(List<String> words) => words
        .any((w) => RegExp('\\b' + RegExp.escape(w) + '\\b').hasMatch(text));

    if (matchesAny(['hire', 'rent', 'rental', 'lease', 'book', 'booking'])) {
      return RequestType.rental;
    }
    if (matchesAny(['deliver', 'delivery', 'courier', 'parcel', 'ship'])) {
      return RequestType.delivery;
    }
    if (matchesAny(['ride', 'pickup', 'drop', 'driver', 'taxi', 'transport'])) {
      return RequestType.ride;
    }
    if (matchesAny(['quote', 'quotes', 'price', 'pricing', 'estimate'])) {
      return RequestType.price;
    }
    if (matchesAny(
        ['repair', 'fix', 'install', 'installation', 'cleaning', 'service'])) {
      return RequestType.service;
    }

    // 3) Default to item when nothing else matches
    return RequestType.item;
  }

  String? _cityOf(RequestModel r) => r.cityName;

  Widget _buildRequestCard(RequestModel request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _getLightTypeColor(_typeOf(request)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getTypeColor(_typeOf(request)).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToRequestView(request),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type and status
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(_typeOf(request)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _displayModuleOrType(request),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (request.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.priority_high,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'URGENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      request.status.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                request.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                request.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Footer with budget, responses and location
              Row(
                children: [
                  if (request.budget != null) ...[
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    Text(
                      '${_currencySymbol ?? ''} ${request.budget!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getTypeColor(_typeOf(request)),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  // Responses count chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 14, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text('${request.responseCount}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_cityOf(request) != null &&
                      _cityOf(request)!.isNotEmpty) ...[
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _cityOf(request)!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Prefer module from metadata for badge, but if it conflicts with inferred
  // type from text/fields, show the inferred type label. Ensures 'van hire'
  // appears as Rent, not Item.
  String _displayModuleOrType(RequestModel r) {
    String labelFromType(RequestType t) {
      switch (t) {
        case RequestType.item:
          return 'Item';
        case RequestType.service:
          return 'Service';
        case RequestType.rental:
          return 'Rent';
        case RequestType.delivery:
          return 'Delivery';
        case RequestType.ride:
          return 'Ride';
        case RequestType.price:
          return 'Price';
      }
    }

    // Inferred type using robust logic
    final inferred = _typeOf(r);

    // Map module string to a RequestType to detect conflicts
    RequestType? typeFromModule(String m) {
      switch (m) {
        case 'item':
        case 'items':
          return RequestType.item;
        case 'rent':
        case 'rental':
        case 'rentals':
          return RequestType.rental;
        case 'delivery':
          return RequestType.delivery;
        case 'ride':
          return RequestType.ride;
        case 'service':
        case 'other':
          return RequestType.service;
        case 'price':
        case 'pricing':
          return RequestType.price;
        default:
          return null;
      }
    }

    final module =
        r.metadata != null ? r.metadata!['module']?.toString() : null;
    final m = module?.trim().toLowerCase();
    final moduleType = (m != null && m.isNotEmpty) ? typeFromModule(m) : null;

    // If module absent or conflicts with inferred type, use inferred
    if (moduleType == null || moduleType != inferred) {
      return labelFromType(inferred);
    }

    // Use module label when consistent
    return labelFromType(moduleType);
  }

  String _getTypeDisplayName(RequestType type) {
    switch (type) {
      case RequestType.item:
        return 'Items';
      case RequestType.service:
        return 'Services';
      case RequestType.rental:
        return 'Rentals';
      case RequestType.delivery:
        return 'Delivery';
      case RequestType.ride:
        return 'Rides';
      case RequestType.price:
        return 'Quotes';
    }
  }

  RequestType? _getRequestTypeFromName(String name) {
    switch (name) {
      case 'Items':
        return RequestType.item;
      case 'Services':
        return RequestType.service;
      case 'Rentals':
        return RequestType.rental;
      case 'Delivery':
        return RequestType.delivery;
      case 'Rides':
        return RequestType.ride;
      case 'Quotes':
        return RequestType.price;
      default:
        return null;
    }
  }

  String _getModuleIdFromRequestType(RequestType requestType) {
    switch (requestType) {
      case RequestType.item:
        return 'item';
      case RequestType.service:
        return 'service';
      case RequestType.rental:
        return 'rent';
      case RequestType.delivery:
        return 'delivery';
      case RequestType.ride:
        return 'ride';
      case RequestType.price:
        return 'price';
    }
  }

  List<RequestModel> _getFilteredRequests() {
    var filtered = List<RequestModel>.from(_requests);

    // Apply module-based filtering first - only show requests for enabled modules
    if (_countryModules != null) {
      filtered = filtered.where((request) {
        // Get the module ID for this request type
        String moduleId = _getModuleIdFromRequestType(_typeOf(request));

        // Check if this module is enabled for the user's country
        return _countryModules!.isModuleEnabled(moduleId);
      }).toList();
    }

    // Filter by type
    if (_selectedType != null) {
      filtered = filtered
          .where((request) => _typeOf(request) == _selectedType)
          .toList();
    }

    // Filter by search query with comma support
    if (_searchQuery.isNotEmpty) {
      final searchTerms = _searchQuery
          .toLowerCase()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);

      filtered = filtered.where((request) {
        final title = request.title.toLowerCase();
        final description = request.description.toLowerCase();
        final location = _cityOf(request)?.toLowerCase() ?? '';
        final type = _getTypeDisplayName(_typeOf(request)).toLowerCase();

        return searchTerms.any((term) =>
            title.contains(term) ||
            description.contains(term) ||
            location.contains(term) ||
            type.contains(term));
      }).toList();
    }

    // Always sort with urgent first, then most recent
    filtered.sort((a, b) {
      // Urgent to top
      if (a.isUrgent != b.isUrgent) {
        return a.isUrgent ? -1 : 1;
      }
      // Newest first
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  void _navigateToRequestView(RequestModel request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedRequestViewScreen(requestId: request.id),
      ),
    );
  }
}
