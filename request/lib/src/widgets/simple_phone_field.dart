import 'package:flutter/material.dart';
import '../services/country_service.dart';

class SimplePhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool isRequired;

  const SimplePhoneField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.onChanged,
    this.isRequired = true,
  }) : super(key: key);

  @override
  State<SimplePhoneField> createState() => _SimplePhoneFieldState();
}

class _SimplePhoneFieldState extends State<SimplePhoneField> {
  String _countryCode = '+94'; // Default to Sri Lanka

  @override
  void initState() {
    super.initState();
    _loadCountryCode();
  }

  Future<void> _loadCountryCode() async {
    try {
      final countryService = CountryService.instance;
      await countryService.loadPersistedCountry();

      setState(() {
        _countryCode = countryService.getCurrentPhoneCode();
      });
    } catch (e) {
      print('Error loading country code: $e');
      // Keep default +94
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? 'Enter phone number',
        prefixIcon: const Icon(Icons.phone),
        prefixText: '$_countryCode ',
        border: const OutlineInputBorder(),
        helperText: 'Country code is automatically detected',
      ),
      keyboardType: TextInputType.phone,
      validator:
          widget.validator ?? (widget.isRequired ? _defaultValidator : null),
      onChanged: widget.onChanged,
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // Basic phone validation - at least 7 digits
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.length < 7) {
      return 'Please enter a valid phone number (minimum 7 digits)';
    }

    return null;
  }
}
