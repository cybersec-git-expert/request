// Simple phone verification widget for both driver and business registration forms
import 'package:flutter/material.dart';
import '../services/country_service.dart';

class SimplePhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const SimplePhoneInput({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<String>(
          future: _getCountryCode(),
          builder: (context, snapshot) {
            final countryCode = snapshot.data ?? '+94';
            return TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint ?? 'Enter phone number',
                prefixIcon: const Icon(Icons.phone),
                prefixText: '$countryCode ',
                border: const OutlineInputBorder(),
                helperText: 'Country code is automatically detected',
              ),
              keyboardType: TextInputType.phone,
              validator: validator ?? _defaultValidator,
              onChanged: onChanged,
            );
          },
        ),
      ],
    );
  }

  Future<String> _getCountryCode() async {
    try {
      final countryService = CountryService.instance;
      await countryService.loadPersistedCountry();
      return countryService.getCurrentPhoneCode();
    } catch (e) {
      return '+94'; // Default to Sri Lanka
    }
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
