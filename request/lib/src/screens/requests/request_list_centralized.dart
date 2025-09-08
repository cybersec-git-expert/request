import 'package:flutter/material.dart';
import '../../services/centralized_request_service.dart';
import '../../services/country_service.dart';
import '../../models/request_model.dart';

/// Example: Request List Screen using Centralized Country Filtering
/// This demonstrates how to use the new centralized services in Flutter screens
class RequestListCentralized extends StatefulWidget {
  const RequestListCentralized({super.key});

  @override
  State<RequestListCentralized> createState() => _RequestListCentralizedState();
}

class _RequestListCentralizedState extends State<RequestListCentralized> {
  final CentralizedRequestService _requestService = CentralizedRequestService();
  final CountryService _countryService = CountryService.instance;

  List<RequestModel> _requests = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _checkCountryAndLoadRequests();
  }

  Future<void> _checkCountryAndLoadRequests() async {
    try {
      // Validate user has country set
      if (_countryService.countryCode == null) {
        setState(() {
          _error = 'Please select your country first';
          _loading = false;
        });
        return;
      }

      // Load country-filtered requests
      _loadRequests();
    } catch (e) {
      setState(() {
        _error = 'Error loading requests: $e';
        _loading = false;
      });
    }
  }

  void _loadRequests() {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Get country-filtered requests stream
    _requestService
        .getCountryRequestsStream(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      type: _selectedType,
      limit: 50,
    )
        .listen(
      (requests) {
        if (mounted) {
          setState(() {
            _requests = List<RequestModel>.from(requests)
              ..sort((a, b) {
                // Urgent priority first, then newest
                final aUrgent = a.priority == Priority.urgent;
                final bUrgent = b.priority == Priority.urgent;
                if (aUrgent != bUrgent) return aUrgent ? -1 : 1;
                return b.createdAt.compareTo(a.createdAt);
              });
            _loading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'Error loading requests: $error';
            _loading = false;
          });
        }
      },
    );
  }

  Widget _buildCountryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Showing requests from ${_countryService.countryName.isNotEmpty ? _countryService.countryName : 'your country'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['All', 'Transport', 'Food', 'Service', 'Items']
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                      _loadRequests();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Types'),
                    ),
                    const DropdownMenuItem<String?>(
                      value: 'delivery',
                      child: Text('DELIVERY'),
                    ),
                    const DropdownMenuItem<String?>(
                      value: 'ride',
                      child: Text('RIDE'),
                    ),
                    const DropdownMenuItem<String?>(
                      value: 'service',
                      child: Text('SERVICE'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                    _loadRequests();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(RequestModel request) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Chip(
                  label: Text(request.type.name.toUpperCase()),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  request.location?.address ?? 'Location not specified',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const Spacer(),
                if (request.budget != null)
                  Chip(
                    label: Text(_countryService.formatPrice(request.budget!)),
                    backgroundColor: Colors.green[50],
                    labelStyle: TextStyle(color: Colors.green[700]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  request.countryName ?? 'Unknown',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const Spacer(),
                Text(
                  _formatDate(request.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Country header
          _buildCountryHeader(),

          // Filters
          _buildFilters(),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create request screen
          Navigator.pushNamed(context, '/create-request');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRequests,
              child: const Text('Retry'),
            ),
            if (_error!.contains('country')) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Navigate to country selection
                  Navigator.pushNamed(context, '/welcome');
                },
                child: const Text('Select Country'),
              ),
            ],
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading requests from your country...'),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Requests Found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No requests found in ${_countryService.countryName.isNotEmpty ? _countryService.countryName : 'your country'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create-request');
              },
              child: const Text('Create First Request'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadRequests();
      },
      child: ListView.builder(
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // Navigate to request details
              Navigator.pushNamed(
                context,
                '/request-details',
                arguments: _requests[index].id,
              );
            },
            child: _buildRequestCard(_requests[index]),
          );
        },
      ),
    );
  }
}
