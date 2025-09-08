import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/payment_methods_service.dart';
import '../../widgets/payment_method_selector.dart';
import '../../theme/app_theme.dart';
import '../../services/business_verification_service.dart';

class BusinessProfileEditScreen extends StatefulWidget {
  const BusinessProfileEditScreen({Key? key}) : super(key: key);

  @override
  State<BusinessProfileEditScreen> createState() =>
      _BusinessProfileEditScreenState();
}

class _BusinessProfileEditScreenState extends State<BusinessProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  List<String> _selectedPaymentMethods = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;

  String _businessCategory = 'general';
  final List<String> _businessCategories = [
    'general',
    'restaurant',
    'retail',
    'services',
    'healthcare',
    'automotive',
    'technology',
    'education',
    'entertainment',
    'other'
  ];

  String _normalizeCategory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'general';
    final v = raw.trim().toLowerCase();
    // Direct match
    if (_businessCategories.contains(v)) return v;
    // Synonyms mapping
    const Map<String, String> synonyms = {
      'food': 'restaurant',
      'cafe': 'restaurant',
      'coffee': 'restaurant',
      'shop': 'retail',
      'store': 'retail',
      'market': 'retail',
      'service': 'services',
      'tech': 'technology',
      'it': 'technology',
      'auto': 'automotive',
      'car': 'automotive',
      'vehicle': 'automotive',
      'health': 'healthcare',
      'medical': 'healthcare',
      'hospital': 'healthcare',
      'education': 'education',
      'school': 'education',
      'training': 'education',
      'entertain': 'entertainment',
      'media': 'entertainment',
    };
    for (final entry in synonyms.entries) {
      if (v.contains(entry.key)) return entry.value;
    }
    return 'other';
  }

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessProfile() async {
    setState(() => _isInitialLoading = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;
      // Prefill from business_verifications
      final bv = await BusinessVerificationService.getForUser(user.uid);
      if (bv != null) {
        _businessNameController.text = bv.businessName;
        _descriptionController.text = bv.businessDescription;
        _addressController.text = bv.businessAddress;
        _phoneController.text = bv.businessPhone;
        _emailController.text = bv.businessEmail;
        // Normalize category to supported set
        _businessCategory = _normalizeCategory(bv.businessCategory);
      }
      // Load selected payment methods mapping for this business
      final selected =
          await PaymentMethodsService.getSelectedForBusiness(user.uid);
      _selectedPaymentMethods = selected;
    } catch (e) {
      print('Error loading business profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _saveBusinessProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Persist selected country payment methods mapping for this business
      await PaymentMethodsService.setSelectedForBusiness(
          user.uid, _selectedPaymentMethods);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 1200),
        ),
      );
    } catch (e) {
      print('Error saving business profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Business Profile'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveBusinessProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Business Information',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _businessNameController,
                              decoration: const InputDecoration(
                                labelText: 'Business Name *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Business name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _businessCategory,
                              decoration: const InputDecoration(
                                labelText: 'Business Category',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _businessCategories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category.toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _businessCategory = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Business Description',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Business Address',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_on),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contact Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Information',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Business Phone',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Business Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _websiteController,
                              decoration: const InputDecoration(
                                labelText: 'Website (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.web),
                              ),
                              keyboardType: TextInputType.url,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Methods Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.payment,
                                    color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Accepted Payment Methods',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select the payment methods your business accepts. This will be displayed to customers.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 16),
                            PaymentMethodSelector(
                              selectedPaymentMethods: _selectedPaymentMethods,
                              onPaymentMethodsChanged: (methods) {
                                setState(
                                    () => _selectedPaymentMethods = methods);
                              },
                              multiSelect: true,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveBusinessProfile,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                            _isLoading ? 'Saving...' : 'Save Business Profile'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
