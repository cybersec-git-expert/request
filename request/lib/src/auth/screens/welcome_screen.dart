import 'package:flutter/material.dart';
import '../../widgets/custom_logo.dart';
import '../../models/country.dart';
import '../../services/country_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  Country? _selectedCountry;
  List<Country> _availableCountries = [];
  List<Country> _filteredCountries = [];
  final CountryService _countryService = CountryService.instance; // Added
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _loadAvailableCountries();
    _checkExistingCountry();

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  Future<void> _loadAvailableCountries() async {
    try {
      final fetched = await _countryService.getAllCountries();
      setState(() {
        _availableCountries = fetched;
        _filteredCountries = fetched; // Initialize filtered list
        _isLoading = false;

        // Set Sri Lanka as default if no country is selected
        if (_selectedCountry == null && fetched.isNotEmpty) {
          final sriLanka = fetched.firstWhere(
            (country) =>
                country.code.toLowerCase() == 'lk' ||
                country.name.toLowerCase().contains('sri lanka'),
            orElse: () => fetched
                .first, // Fallback to first country if Sri Lanka not found
          );
          _selectedCountry = sriLanka;
        }
      });
    } catch (e) {
      debugPrint('Error loading countries: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = _availableCountries;
      } else {
        _filteredCountries = _availableCountries.where((country) {
          return country.name.toLowerCase().contains(query.toLowerCase()) ||
              country.phoneCode.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _checkExistingCountry() async {
    try {
      // Load any previously saved country
      await _countryService.loadPersistedCountry();

      // Check if a country was already selected
      final existingCountryCode = _countryService.countryCode;
      if (existingCountryCode != null && mounted) {
        // Set the previously selected country but don't auto-navigate
        // Find the country in the available countries list
        final existingCountry = _availableCountries.firstWhere(
          (country) => country.code == existingCountryCode,
          orElse: () => Country(
            code: existingCountryCode,
            name: _countryService.countryName,
            flagEmoji: null, // Don't show fallback globe
            phoneCode: _countryService.phoneCode,
            isEnabled: true,
          ),
        );
        setState(() {
          _selectedCountry = existingCountry;
        });
      }
    } catch (e) {
      debugPrint('Error checking existing country: $e');
    }
    // Always show the welcome screen for country selection
  }

  void _onCountrySelected(Country country) async {
    if (!country.isEnabled) {
      // Show coming soon dialog for disabled countries
      _showComingSoonDialog(country);
      return;
    }

    setState(() {
      _selectedCountry = country;
    });

    try {
      // Save the selected country to persistence
      await _countryService.setCountryFromObject(country);
    } catch (e) {
      debugPrint('Error saving country: $e');
    }

    // Navigate to login screen
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      '/login',
      arguments: {
        'countryCode': country.code,
        'phoneCode': country.phoneCode,
        'countryName': country.name,
      },
    );
  }

  void _selectCountryOnly(Country country) async {
    if (!country.isEnabled) {
      // Show coming soon dialog for disabled countries
      _showComingSoonDialog(country);
      return;
    }

    setState(() {
      _selectedCountry = country;
    });

    try {
      // Save the selected country to persistence
      await _countryService.setCountryFromObject(country);
    } catch (e) {
      debugPrint('Error saving country: $e');
    }
  }

  void _showComingSoonDialog(Country country) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(child: Text(country.name)),
            ],
          ),
          content: Text(
            country.comingSoonMessage.isNotEmpty
                ? country.comingSoonMessage
                : 'Coming soon to ${country.name}! Stay tuned for updates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showCountryListBottomSheet() {
    // Reset search when opening
    _searchController.clear();
    _filteredCountries = _availableCountries;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Title
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Select Country',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Search bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search country',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          onChanged: (query) {
                            setModalState(() {
                              _filterCountries(query);
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Countries list
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _filteredCountries.length,
                          itemBuilder: (context, index) {
                            final country = _filteredCountries[index];
                            return ListTile(
                              leading: Text(
                                country.flag,
                                style: const TextStyle(fontSize: 24),
                              ),
                              title: Text(country.name),
                              subtitle: Text(country.phoneCode),
                              trailing: country.isEnabled
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : const Icon(Icons.schedule,
                                      color: Colors.orange),
                              onTap: () {
                                Navigator.pop(context);
                                _selectCountryOnly(country);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Top spacing - make it flexible
                    SizedBox(height: size.height * 0.06),

                    // Logo
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: CustomLogo.large(),
                    ),

                    SizedBox(height: size.height * 0.04),

                    // Welcome content
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              'Welcome to',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Request',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D), // Charcoal color
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Connect with local businesses and\nservice providers effortlessly',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                                height: 1.5,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Flexible spacer
                    SizedBox(height: size.height * 0.08),

                    // Country selection
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Select your country',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: _isLoading
                                    ? null
                                    : _showCountryListBottomSheet,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      if (_selectedCountry != null) ...[
                                        Text(
                                          _selectedCountry!.flag,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedCountry!.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ),
                                        if (!_selectedCountry!.isEnabled)
                                          const Icon(Icons.schedule,
                                              color: Colors.orange),
                                      ] else if (_isLoading) ...[
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Loading countries...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        Expanded(
                                          child: Text(
                                            'Choose your country',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ),
                                      ],
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Continue button
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _selectedCountry == null || _isLoading
                                ? null
                                : () async {
                                    _onCountrySelected(_selectedCountry!);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassTheme.colors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Flexible bottom spacing
                    SizedBox(height: size.height * 0.04),

                    // Powered by footer
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Powered by Request (Pvt) Ltd',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ), // Padding
            ), // ConstrainedBox
          ), // SingleChildScrollView
        ), // SafeArea
      ), // Scaffold
    ); // GlassTheme.backgroundContainer
  }
}
