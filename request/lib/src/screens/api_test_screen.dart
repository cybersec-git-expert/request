import 'package:flutter/material.dart';
import '../services/rest_auth_service.dart';
import '../services/api_data_services.dart';
import '../services/requests_api_service.dart';

/// Test screen for REST API integration
class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final RestAuthService _authService = RestAuthService.instance;
  final CategoriesApiService _categoriesService = CategoriesApiService.instance;
  final CitiesApiService _citiesService = CitiesApiService.instance;
  final RequestsApiService _requestsService = RequestsApiService.instance;

  bool _isLoading = false;
  String _status = 'Ready to test APIs';
  List<CategoryModel> _categories = [];
  List<CityModel> _cities = [];
  List<RequestModel> _requests = [];
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() => _isLoading = true);

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        _currentUser = _authService.currentUser;
        setState(() => _status = 'Authenticated as: ${_currentUser?.email}');
      } else {
        setState(() => _status = 'Not authenticated');
      }
    } catch (e) {
      setState(() => _status = 'Auth check error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testRegister() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.register(
        email:
            'flutter_test_${DateTime.now().millisecondsSinceEpoch}@example.com',
        password: 'test123456',
        displayName: 'Flutter Test User',
      );

      if (result.isSuccess) {
        _currentUser = result.user;
        setState(
            () => _status = 'Registration successful: ${result.user?.email}');
      } else {
        setState(() => _status = 'Registration failed: ${result.error}');
      }
    } catch (e) {
      setState(() => _status = 'Registration error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.login(
        email: 'test@example.com',
        password: 'test123',
      );

      if (result.isSuccess) {
        _currentUser = result.user;
        setState(() => _status = 'Login successful: ${result.user?.email}');
      } else {
        setState(() => _status = 'Login failed: ${result.error}');
      }
    } catch (e) {
      setState(() => _status = 'Login error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testCategories() async {
    setState(() => _isLoading = true);

    try {
      final categories = await _categoriesService.getCategories();
      setState(() {
        _categories = categories;
        _status = 'Loaded ${categories.length} categories';
      });
    } catch (e) {
      setState(() => _status = 'Categories error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testCities() async {
    setState(() => _isLoading = true);

    try {
      final cities = await _citiesService.getCities();
      setState(() {
        _cities = cities;
        _status = 'Loaded ${cities.length} cities';
      });
    } catch (e) {
      setState(() => _status = 'Cities error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testRequests() async {
    setState(() => _isLoading = true);

    try {
      final result = await _requestsService.getRequests();
      if (result.success) {
        setState(() {
          _requests = result.requests;
          _status =
              'Loaded ${result.requests.length} requests (Total: ${result.pagination.total})';
        });
      } else {
        setState(() => _status = 'Requests error: ${result.error}');
      }
    } catch (e) {
      setState(() => _status = 'Requests error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testCreateRequest() async {
    if (_currentUser == null) {
      setState(() => _status = 'Please login first to create a request');
      return;
    }

    if (_categories.isEmpty || _cities.isEmpty) {
      setState(() => _status = 'Please load categories and cities first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _requestsService.createRequest(
        title: 'Flutter Test Request ${DateTime.now().millisecondsSinceEpoch}',
        description: 'This is a test request created from Flutter app',
        categoryId: _categories.first.id,
        cityId: _cities.first.id,
        budget: 3000,
        priority: 'normal',
      );

      if (result.success) {
        setState(() =>
            _status = 'Request created successfully: ${result.request?.id}');
        _testRequests(); // Refresh requests list
      } else {
        setState(() => _status = 'Create request failed: ${result.error}');
      }
    } catch (e) {
      setState(() => _status = 'Create request error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await _authService.logout();
    setState(() {
      _currentUser = null;
      _status = 'Logged out successfully';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test Screen'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Authentication tests
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication Tests',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_currentUser != null)
                      Text('Logged in as: ${_currentUser!.email}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _testRegister,
                          child: const Text('Test Register'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _testLogin,
                          child: const Text('Test Login'),
                        ),
                        if (_currentUser != null)
                          ElevatedButton(
                            onPressed: _isLoading ? null : _logout,
                            child: const Text('Logout'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Data tests
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data API Tests',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('Categories: ${_categories.length}'),
                    Text('Cities: ${_cities.length}'),
                    Text('Requests: ${_requests.length}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _testCategories,
                          child: const Text('Load Categories'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _testCities,
                          child: const Text('Load Cities'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _testRequests,
                          child: const Text('Load Requests'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _testCreateRequest,
                          child: const Text('Create Request'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Data display
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Categories'),
                        Tab(text: 'Cities'),
                        Tab(text: 'Requests'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Categories tab
                          ListView.builder(
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              return ListTile(
                                title: Text(category.name),
                                subtitle: Text('ID: ${category.id}'),
                                trailing: Icon(category.isActive
                                    ? Icons.check_circle
                                    : Icons.circle),
                              );
                            },
                          ),

                          // Cities tab
                          ListView.builder(
                            itemCount: _cities.length,
                            itemBuilder: (context, index) {
                              final city = _cities[index];
                              return ListTile(
                                title: Text(city.name),
                                subtitle: Text(
                                    '${city.countryCode} - ID: ${city.id}'),
                                trailing: Icon(city.isActive
                                    ? Icons.check_circle
                                    : Icons.circle),
                              );
                            },
                          ),

                          // Requests tab
                          ListView.builder(
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final request = _requests[index];
                              return ListTile(
                                title: Text(request.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(request.description),
                                    Text('Budget: ${request.budgetDisplay}'),
                                    Text(
                                        'City: ${request.cityName ?? request.locationCityId}'),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(request.status),
                                  backgroundColor: request.status == 'active'
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
