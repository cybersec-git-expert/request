import 'package:flutter/material.dart';
import '../../services/country_service.dart';
import '../../theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import '../../models/country.dart'; // Added
import '../../theme/glass_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final CountryService _countryService = CountryService.instance;
  List<Country> _availableCountries = [];
  List<Country> _disabledCountries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _countryService.loadPersistedCountry();
    _checkExistingCountry();
  }

  Future<void> _checkExistingCountry() async {
    // Check if user already selected a country
    final existingCountryCode = _countryService.countryCode;
    if (existingCountryCode != null) {
      // Country already selected, navigate to login
      final existingPhoneCode = _countryService.phoneCode;
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              countryCode: existingCountryCode,
              phoneCode: existingPhoneCode,
            ),
          ),
        );
        return;
      }
    }

    // No country selected, load available countries
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final allCountries = await _countryService.getAllCountries();

      setState(() {
        _availableCountries = allCountries.where((c) => c.isEnabled).toList();
        _disabledCountries = allCountries.where((c) => !c.isEnabled).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load countries: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCountry(Country country) async {
    try {
      await _countryService.setCountryFromObject(country);

      if (mounted) {
        // Navigate to login screen with country details
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              countryCode: country.code,
              phoneCode: country.phoneCode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting country: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showComingSoonDialog(Country country) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Text(
              country.flag,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                country.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          country.comingSoonMessage.isNotEmpty
              ? country.comingSoonMessage
              : 'Coming soon to your country! Stay tuned for updates.',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
        child: Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 40),
              const Icon(
                Icons.public,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Request',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your country to get started',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading countries...',
              style: TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCountries,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_availableCountries.isEmpty && _disabledCountries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            SizedBox(height: 16),
            Text(
              'No countries configured yet.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available countries
          if (_availableCountries.isNotEmpty) ...[
            const Text(
              'Available Now',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._availableCountries.map((country) => _buildCountryTile(
                  country: country,
                  isEnabled: true,
                )),
          ],

          // Coming soon countries
          if (_disabledCountries.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._disabledCountries.map((country) => _buildCountryTile(
                  country: country,
                  isEnabled: false,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCountryTile({
    required Country country,
    required bool isEnabled,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Text(
          country.flag,
          style: const TextStyle(fontSize: 32),
        ),
        title: Text(
          country.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        subtitle: Text(
          country.phoneCode,
          style: TextStyle(
            fontSize: 14,
            color: isEnabled ? AppTheme.textSecondary : AppTheme.textTertiary,
          ),
        ),
        trailing: isEnabled
            ? const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
        onTap: isEnabled
            ? () => _selectCountry(country)
            : () => _showComingSoonDialog(country),
      ),
    );
  }
}
