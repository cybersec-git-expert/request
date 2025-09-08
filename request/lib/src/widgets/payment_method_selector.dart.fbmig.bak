import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/payment_methods_service.dart';
import '../../services/country_service.dart';
import '../../theme/app_theme.dart';

class PaymentMethodSelector extends StatefulWidget {
  final List<String> selectedPaymentMethods;
  final Function(List<String>) onPaymentMethodsChanged;
  final bool multiSelect;
  final String? title;
  
  const PaymentMethodSelector({
    Key? key,
    required this.selectedPaymentMethods,
    required this.onPaymentMethodsChanged,
    this.multiSelect = true,
    this.title,
  }) : super(key: key);

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  List<PaymentMethod> _paymentMethods = [];
  List<PaymentMethod> _filteredMethods = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  
  final List<String> _categories = ['all', 'digital', 'bank', 'card', 'cash', 'crypto'];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    
    try {
      final countryCode = await CountryService.getSelectedCountryCode() ?? 'US';
      final methods = await PaymentMethodsService.getPaymentMethodsForCountry(countryCode);
      
      setState(() {
        _paymentMethods = methods;
        _filteredMethods = methods;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading payment methods: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterMethods() {
    setState(() {
      _filteredMethods = _paymentMethods.where((method) {
        final matchesSearch = _searchQuery.isEmpty ||
            method.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            method.description.toLowerCase().contains(_searchQuery.toLowerCase());
        
        final matchesCategory = _selectedCategory == 'all' ||
            method.category == _selectedCategory;
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _togglePaymentMethod(String methodId) {
    List<String> newSelection = List.from(widget.selectedPaymentMethods);
    
    if (widget.multiSelect) {
      if (newSelection.contains(methodId)) {
        newSelection.remove(methodId);
      } else {
        newSelection.add(methodId);
      }
    } else {
      newSelection = [methodId];
    }
    
    widget.onPaymentMethodsChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.title!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        
        // Search and filter
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search payment methods...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _filterMethods();
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category == 'all' ? 'All' : category.toUpperCase()),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedCategory = category);
                            _filterMethods();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Payment methods grid
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_filteredMethods.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No payment methods found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search or category filter',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: _filteredMethods.length,
            itemBuilder: (context, index) {
              final method = _filteredMethods[index];
              final isSelected = widget.selectedPaymentMethods.contains(method.id);
              
              return GestureDetector(
                onTap: () => _togglePaymentMethod(method.id),
                child: Card(
                  elevation: isSelected ? 4 : 1,
                  color: isSelected ? AppTheme.primaryLight.withOpacity(0.1) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: method.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        method.imageUrl,
                                        height: 40,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.payment,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.payment,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          method.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (method.fees.isNotEmpty)
                          Text(
                            'Fees: ${method.fees}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(method.category).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            method.category.toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _getCategoryColor(method.category),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        
        if (widget.selectedPaymentMethods.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Selected: ${widget.selectedPaymentMethods.length} payment method${widget.selectedPaymentMethods.length != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'digital':
        return Colors.blue;
      case 'bank':
        return Colors.green;
      case 'card':
        return Colors.orange;
      case 'cash':
        return Colors.brown;
      case 'crypto':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
