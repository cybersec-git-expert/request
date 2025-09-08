import 'package:flutter/material.dart';
import '../models/request_model.dart';
import '../models/enhanced_user_model.dart' as enhanced;
import '../services/country_filtered_data_service.dart';
import '../services/country_service.dart';
import '../services/module_service.dart';
import '../services/request_filtering_service.dart';
import '../services/enhanced_user_service.dart';
import 'unified_request_response/unified_request_view_screen.dart';

class EnhancedBrowseScreen extends StatefulWidget {
  const EnhancedBrowseScreen({super.key});

  @override
  State<EnhancedBrowseScreen> createState() => _EnhancedBrowseScreenState();
}

class _EnhancedBrowseScreenState extends State<EnhancedBrowseScreen> {
  final CountryFilteredDataService _dataService =
      CountryFilteredDataService.instance;
  final RequestFilteringService _filteringService =
      RequestFilteringService.instance;
  final EnhancedUserService _userService = EnhancedUserService();

  String _searchQuery = '';
  enhanced.RequestType? _selectedType;
  List<RequestModel> _allRequests = [];
  List<RequestModel> _filteredRequests = [];
  bool _isLoading = true;
  String? _error;
  String? _currencySymbol;
  CountryModules? _countryModules;
  List<enhanced.RequestType> _enabledRequestTypes = [];
  List<enhanced.RequestType> _userAvailableTypes = [];
  enhanced.UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load user data
      _currentUser = await _userService.getCurrentUserModel();

      // Load currency symbol
      _currencySymbol = CountryService.instance.getCurrencySymbol();

      // Load country modules configuration
      final countryCode = CountryService.instance.countryCode;
      if (countryCode != null) {
        _countryModules = await ModuleService.getCountryModules(countryCode);
        _enabledRequestTypes = _getEnabledRequestTypes();
      }

      // Get user's available request types based on their roles
      _userAvailableTypes =
          await _filteringService.getUserAvailableRequestTypes();

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

  List<enhanced.RequestType> _getEnabledRequestTypes() {
    if (_countryModules == null) return enhanced.RequestType.values;

    List<enhanced.RequestType> enabledTypes = [];
    _countryModules!.modules.forEach((moduleId, isEnabled) {
      if (isEnabled) {
        enhanced.RequestType? type = _getRequestTypeFromModuleId(moduleId);
        if (type != null) {
          enabledTypes.add(type);
        }
      }
    });

    return enabledTypes;
  }

  enhanced.RequestType? _getRequestTypeFromModuleId(String moduleId) {
    switch (moduleId) {
      case 'item':
        return enhanced.RequestType.item;
      case 'service':
        return enhanced.RequestType.service;
      case 'rent':
        return enhanced.RequestType.rental;
      case 'delivery':
        return enhanced.RequestType.delivery;
      case 'ride':
        return enhanced.RequestType.ride;
      case 'price':
        return enhanced.RequestType.price;
      default:
        return null;
    }
  }

  Future<void> _loadRequests() async {
    try {
      setState(() => _isLoading = true);

      // Load all requests from the country data service
      final requestsStream = _dataService.getCountryRequestsStream(
        status: null, // Get all statuses
        type: _selectedType?.name, // pass enum name as string for shim services
        limit: 100, // Increased limit since we'll filter client-side
      );

      // Get the first batch of requests
      _allRequests = await requestsStream.first;

      // Apply comprehensive filtering based on user role and country
      _filteredRequests =
          await _filteringService.filterRequestsForUser(_allRequests);

      // Apply search and type filters
      _applyLocalFilters();

      if (mounted) {
        setState(() {
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

  void _applyLocalFilters() {
    List<RequestModel> filtered = List.from(_filteredRequests);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((request) {
        return request.title.toLowerCase().contains(query) ||
            request.description.toLowerCase().contains(query) ||
            request.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // Apply type filter
    if (_selectedType != null) {
      filtered =
          filtered.where((request) => request.type == _selectedType).toList();
    }

    if (mounted) {
      setState(() {
        _filteredRequests = filtered;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyLocalFilters();
  }

  void _onTypeFilterChanged(enhanced.RequestType? type) {
    setState(() {
      _selectedType = type;
    });
    _loadRequests(); // Reload with new type filter
  }

  Future<void> _refreshRequests() async {
    await _loadData();
  }

  // Color helper methods
  Color _getTypeColor(enhanced.RequestType type) {
    switch (type) {
      case enhanced.RequestType.item:
        return const Color(0xFFFF6B35); // Orange/red
      case enhanced.RequestType.service:
        return const Color(0xFF00BCD4); // Teal
      case enhanced.RequestType.rental:
        return const Color(0xFF2196F3); // Blue
      case enhanced.RequestType.delivery:
        return const Color(0xFF4CAF50); // Green
      case enhanced.RequestType.ride:
        return const Color(0xFFFFC107); // Yellow
      case enhanced.RequestType.price:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  Color _getLightTypeColor(enhanced.RequestType type) {
    return _getTypeColor(type).withOpacity(0.1);
  }

  IconData _getTypeIcon(enhanced.RequestType type) {
    switch (type) {
      case enhanced.RequestType.item:
        return Icons.shopping_bag;
      case enhanced.RequestType.service:
        return Icons.build;
      case enhanced.RequestType.rental:
        return Icons.schedule;
      case enhanced.RequestType.delivery:
        return Icons.local_shipping;
      case enhanced.RequestType.ride:
        return Icons.directions_car;
      case enhanced.RequestType.price:
        return Icons.compare_arrows;
    }
  }

  String _getTypeDisplayName(enhanced.RequestType type) {
    switch (type) {
      case enhanced.RequestType.item:
        return 'Items';
      case enhanced.RequestType.service:
        return 'Services';
      case enhanced.RequestType.rental:
        return 'Rentals';
      case enhanced.RequestType.delivery:
        return 'Delivery';
      case enhanced.RequestType.ride:
        return 'Rides';
      case enhanced.RequestType.price:
        return 'Price Check';
    }
  }

  // Prefer module from metadata when available; fall back to main type name.
  String _getModuleOrTypeLabel(RequestModel request) {
    final raw = (request.typeSpecificData['module'] ??
            request.typeSpecificData['request_type'] ??
            request.typeSpecificData['type'])
        ?.toString()
        .toLowerCase()
        .trim();

    switch (raw) {
      case 'item':
      case 'items':
        return 'Item';
      case 'service':
      case 'services':
        return 'Service';
      case 'rental':
      case 'rent':
        return 'Rental';
      case 'delivery':
        return 'Delivery';
      case 'ride':
        return 'Ride';
      case 'price':
      case 'price_check':
        return 'Price';
      case 'tours':
      case 'tour':
        return 'Tours';
      case 'events':
      case 'event':
        return 'Events';
      case 'construction':
        return 'Construction';
      case 'education':
        return 'Education';
      case 'hiring':
      case 'hire':
        return 'Hiring';
      default:
        return _getTypeDisplayName(request.type);
    }
  }

  Widget _buildUserRoleIndicator() {
    if (_currentUser == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Viewing as: ${_currentUser!.activeRole.name.toUpperCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _getRoleFilterDescription(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _getRoleFilterDescription() {
    if (_currentUser == null) return '';

    switch (_currentUser!.activeRole) {
      case enhanced.UserRole.driver:
        return 'Showing ride requests for your vehicle type and general requests from your country';
      case enhanced.UserRole.business:
      case enhanced.UserRole.delivery:
        return 'Showing delivery requests and general requests from your country';
      case enhanced.UserRole.general:
        return 'Showing general requests (items, services, rentals, price checks) from your country';
    }
  }

  Widget _buildTypeFilter() {
    // Only show types that are both enabled for the country AND available for the user
    final availableTypes = _enabledRequestTypes
        .where((type) => _userAvailableTypes.contains(type))
        .toList();

    if (availableTypes.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: availableTypes.length + 1, // +1 for "All" option
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" option
            final isSelected = _selectedType == null;
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) _onTypeFilterChanged(null);
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            );
          }

          final type = availableTypes[index - 1];
          final isSelected = _selectedType == type;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                _getTypeIcon(type),
                size: 18,
                color: isSelected ? _getTypeColor(type) : Colors.grey,
              ),
              label: Text(_getTypeDisplayName(type)),
              selected: isSelected,
              onSelected: (selected) {
                _onTypeFilterChanged(selected ? type : null);
              },
              backgroundColor: _getLightTypeColor(type),
              selectedColor: _getTypeColor(type).withOpacity(0.2),
              checkmarkColor: _getTypeColor(type),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(RequestModel request) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnifiedRequestViewScreen(
                requestId: request.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLightTypeColor(request.type),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getTypeColor(request.type)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(request.type),
                          size: 14,
                          color: _getTypeColor(request.type),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getModuleOrTypeLabel(request),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getTypeColor(request.type),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (request.budget != null && _currencySymbol != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '$_currencySymbol${request.budget!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                request.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${int.tryParse((request.typeSpecificData['response_count'] ?? '0').toString()) ?? 0}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  if (request.location != null) ...[
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.location!.address,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (request.type == enhanced.RequestType.ride &&
                      request.rideData?.vehicleType != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.directions_car,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.rideData!.vehicleType!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ],
              ),
              if (request.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: request.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search requests...',
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Requests'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUserRoleIndicator(),
          _buildSearchBar(),
          _buildTypeFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading requests',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshRequests,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _filteredRequests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No requests found',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try adjusting your search or filters'
                                      : 'No requests available for your role and location',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshRequests,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredRequests.length,
                              itemBuilder: (context, index) {
                                return _buildRequestCard(
                                    _filteredRequests[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
