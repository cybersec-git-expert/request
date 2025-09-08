import 'package:flutter/material.dart';
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart';
import '../../services/centralized_request_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../utils/currency_helper.dart';

class CreatePriceRequestScreen extends StatefulWidget {
  const CreatePriceRequestScreen({super.key});

  @override
  State<CreatePriceRequestScreen> createState() =>
      _CreatePriceRequestScreenState();
}

class _CreatePriceRequestScreenState extends State<CreatePriceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final CentralizedRequestService _requestService = CentralizedRequestService();
  final EnhancedUserService _userService = EnhancedUserService();

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();

  // Price-specific fields
  String _requestType = 'Product Price';
  String _category = 'Electronics';
  String _condition = 'New';
  int _quantity = 1;
  bool _compareNewAndUsed = true;
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _specificationsController = TextEditingController();
  bool _includeShipping = false;
  bool _lookingForBestDeal = true;

  bool _isLoading = false;

  final List<String> _requestTypes = [
    'Product Price',
    'Service Quote',
    'Rental Rate',
    'Market Price',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _specificationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFAFF),
      appBar: AppBar(
        title: const Text('Create Price Request'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.teal[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price Request',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[600],
                            ),
                          ),
                          const Text(
                            'Get price quotes and compare offers from multiple providers!',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'What do you want priced?',
                  hintText: 'e.g., iPhone 15 Pro, Web Design Service',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter what you want priced';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'Provide more details about what you need priced...',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Price Request Details
              _buildSectionTitle('Request Details'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _requestType,
                decoration: InputDecoration(
                  labelText: 'Request Type',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                ),
                items: _requestTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _requestType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(
                  labelText: 'Brand (Optional)',
                  hintText: 'e.g., Apple, Samsung, Nike',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model/Version (Optional)',
                  hintText: 'e.g., Pro Max, 2024 Edition',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specificationsController,
                decoration: InputDecoration(
                  labelText: 'Specifications (Optional)',
                  hintText: 'Color, size, features, requirements...',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Location
              _buildSectionTitle('Location'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Your Location',
                  hintText: 'For accurate pricing and availability',
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please specify your location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Options
              _buildSectionTitle('Preferences'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Include Shipping Costs'),
                      subtitle:
                          const Text('Get total price including delivery'),
                      value: _includeShipping,
                      onChanged: (value) {
                        setState(() {
                          _includeShipping = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('Looking for Best Deal'),
                      subtitle:
                          const Text('I want the most competitive prices'),
                      value: _lookingForBestDeal,
                      onChanged: (value) {
                        setState(() {
                          _lookingForBestDeal = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        const Color(0xFF9C27B0), // Purple for price requests
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Get Price Quotes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user has verified phone number
      final currentUser = await _userService.getCurrentUserModel();
      if (currentUser == null || !currentUser.isPhoneVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Please verify your phone number to create requests'),
            ),
          );
        }
        return;
      }

      // Create the price-specific data
      final priceData = PriceRequestData(
        itemOrService: _titleController.text.trim(),
        category: _category,
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        condition: _condition,
        specifications: {
          'specifications': _specificationsController.text.trim(),
        },
        quantity: _quantity,
        compareNewAndUsed: _compareNewAndUsed,
      );

      await _requestService.createRequestCompat(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: RequestType.price,
        budget: double.tryParse(_budgetController.text),
        currency: CurrencyHelper.instance.getCurrency(),
        typeSpecificData: priceData.toMap(),
        tags: ['price', _category.toLowerCase().replaceAll(' ', '_')],
        location: LocationInfo(
          latitude: 0.0,
          longitude: 0.0,
          address: _locationController.text.trim(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price request created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
