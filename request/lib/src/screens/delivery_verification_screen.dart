import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/enhanced_user_service.dart';
import '../services/file_upload_service.dart';
import '../models/enhanced_user_model.dart';
import '../widgets/simple_phone_field.dart';

class DeliveryVerificationScreen extends StatefulWidget {
  const DeliveryVerificationScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryVerificationScreen> createState() =>
      _DeliveryVerificationScreenState();
}

class _DeliveryVerificationScreenState
    extends State<DeliveryVerificationScreen> {
  final EnhancedUserService _userService = EnhancedUserService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _serviceAreasController = TextEditingController();
  final _specialInstructionsController = TextEditingController();

  // Service capabilities
  Map<String, bool> _serviceTypes = {
    'restaurant_delivery': false,
    'grocery_delivery': false,
    'package_delivery': false,
    'document_delivery': false,
    'pharmacy_delivery': false,
    'flower_delivery': false,
    'gift_delivery': false,
  };

  Map<String, bool> _vehicleTypes = {
    'bicycle': false,
    'motorcycle': false,
    'car': false,
    'van': false,
    'truck': false,
  };

  Map<String, bool> _specialServices = {
    'same_day_delivery': false,
    'express_delivery': false,
    'scheduled_delivery': false,
    'cold_storage': false,
    'fragile_handling': false,
    'bulk_delivery': false,
  };

  // Time availability
  Map<String, bool> _availabilityDays = {
    'monday': true,
    'tuesday': true,
    'wednesday': true,
    'thursday': true,
    'friday': true,
    'saturday': true,
    'sunday': false,
  };

  Map<String, TimeOfDay> _startTimes = {
    'monday': const TimeOfDay(hour: 8, minute: 0),
    'tuesday': const TimeOfDay(hour: 8, minute: 0),
    'wednesday': const TimeOfDay(hour: 8, minute: 0),
    'thursday': const TimeOfDay(hour: 8, minute: 0),
    'friday': const TimeOfDay(hour: 8, minute: 0),
    'saturday': const TimeOfDay(hour: 9, minute: 0),
    'sunday': const TimeOfDay(hour: 9, minute: 0),
  };

  Map<String, TimeOfDay> _endTimes = {
    'monday': const TimeOfDay(hour: 20, minute: 0),
    'tuesday': const TimeOfDay(hour: 20, minute: 0),
    'wednesday': const TimeOfDay(hour: 20, minute: 0),
    'thursday': const TimeOfDay(hour: 20, minute: 0),
    'friday': const TimeOfDay(hour: 20, minute: 0),
    'saturday': const TimeOfDay(hour: 18, minute: 0),
    'sunday': const TimeOfDay(hour: 18, minute: 0),
  };

  File? _businessLicenseImage;
  File? _insuranceDocumentImage;
  List<File> _vehicleImages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  int _currentStep = 0;
  bool _is24x7Available = false;

  final Map<String, String> _serviceTypeLabels = {
    'restaurant_delivery': 'Restaurant & Food Delivery',
    'grocery_delivery': 'Grocery & Retail Delivery',
    'package_delivery': 'Package & Parcel Delivery',
    'document_delivery': 'Document Delivery',
    'pharmacy_delivery': 'Pharmacy & Medical',
    'flower_delivery': 'Flowers & Gifts',
    'gift_delivery': 'Special Occasion Delivery',
  };

  final Map<String, String> _vehicleTypeLabels = {
    'bicycle': 'Bicycle',
    'motorcycle': 'Motorcycle/Scooter',
    'car': 'Car',
    'van': 'Van',
    'truck': 'Truck',
  };

  final Map<String, String> _specialServiceLabels = {
    'same_day_delivery': 'Same-Day Delivery',
    'express_delivery': 'Express/Rush Delivery',
    'scheduled_delivery': 'Scheduled Delivery',
    'cold_storage': 'Refrigerated Transport',
    'fragile_handling': 'Fragile Item Handling',
    'bulk_delivery': 'Bulk/Large Orders',
  };

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _contactPersonController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _serviceAreasController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Delivery Partner Verification'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepTapped: (step) {
            if (step <= _currentStep || _isValidStep(_currentStep)) {
              setState(() => _currentStep = step);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  if (details.stepIndex < 3)
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: const Text('Continue'),
                    ),
                  if (details.stepIndex == 3)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Submit for Verification'),
                    ),
                  const SizedBox(width: 16),
                  if (details.stepIndex > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Company Information'),
              content: _buildCompanyInfoStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0
                  ? StepState.complete
                  : _currentStep == 0
                      ? StepState.indexed
                      : StepState.disabled,
            ),
            Step(
              title: const Text('Service Capabilities'),
              content: _buildCapabilitiesStep(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1
                  ? StepState.complete
                  : _currentStep == 1
                      ? StepState.indexed
                      : StepState.disabled,
            ),
            Step(
              title: const Text('Availability & Documents'),
              content: _buildAvailabilityDocumentsStep(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2
                  ? StepState.complete
                  : _currentStep == 2
                      ? StepState.indexed
                      : StepState.disabled,
            ),
            Step(
              title: const Text('Review & Submit'),
              content: _buildReviewStep(),
              isActive: _currentStep >= 3,
              state: _currentStep == 3 ? StepState.indexed : StepState.disabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell us about your delivery service',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),

        // Company Name
        TextFormField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Company/Service Name *',
            hintText: 'Enter your delivery service name',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your company name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Company Address
        TextFormField(
          controller: _companyAddressController,
          decoration: const InputDecoration(
            labelText: 'Business Address *',
            hintText: 'Enter your business address',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Contact Person
        TextFormField(
          controller: _contactPersonController,
          decoration: const InputDecoration(
            labelText: 'Contact Person *',
            hintText: 'Enter the primary contact person',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a contact person';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Company Phone
        SimplePhoneField(
          controller: _companyPhoneController,
          label: 'Business Phone *',
          hint: 'Enter your business phone number',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Company Email
        TextFormField(
          controller: _companyEmailController,
          decoration: const InputDecoration(
            labelText: 'Business Email *',
            hintText: 'Enter your business email',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Service Areas
        TextFormField(
          controller: _serviceAreasController,
          decoration: const InputDecoration(
            labelText: 'Primary Service Areas *',
            hintText: 'Enter areas/cities you serve (comma separated)',
            prefixIcon: Icon(Icons.map),
            border: OutlineInputBorder(),
            helperText: 'e.g., Downtown, Suburbs, City Center',
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your service areas';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCapabilitiesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Capabilities & Fleet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),

        // Service Types
        _buildSectionCard(
          'Delivery Services Offered',
          'Select all delivery services you provide',
          _serviceTypes.keys
              .map((key) => CheckboxListTile(
                    title: Text(_serviceTypeLabels[key]!),
                    value: _serviceTypes[key],
                    onChanged: (value) {
                      setState(() => _serviceTypes[key] = value ?? false);
                    },
                  ))
              .toList(),
        ),

        const SizedBox(height: 16),

        // Vehicle Types
        _buildSectionCard(
          'Available Vehicles',
          'Select all vehicle types in your fleet',
          _vehicleTypes.keys
              .map((key) => CheckboxListTile(
                    title: Text(_vehicleTypeLabels[key]!),
                    value: _vehicleTypes[key],
                    onChanged: (value) {
                      setState(() => _vehicleTypes[key] = value ?? false);
                    },
                  ))
              .toList(),
        ),

        const SizedBox(height: 16),

        // Special Services
        _buildSectionCard(
          'Special Services',
          'Additional capabilities you offer',
          _specialServices.keys
              .map((key) => CheckboxListTile(
                    title: Text(_specialServiceLabels[key]!),
                    value: _specialServices[key],
                    onChanged: (value) {
                      setState(() => _specialServices[key] = value ?? false);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAvailabilityDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability & Documentation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),

        // 24/7 Availability
        SwitchListTile(
          title: const Text('Available 24/7'),
          subtitle: const Text('Check if you provide round-the-clock service'),
          value: _is24x7Available,
          onChanged: (value) {
            setState(() => _is24x7Available = value);
          },
        ),

        if (!_is24x7Available) ...[
          const SizedBox(height: 16),
          Text(
            'Service Hours',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ..._availabilityDays.keys
              .map((day) => _buildDayAvailability(day))
              .toList(),
        ],

        const SizedBox(height: 24),

        // Special Instructions
        TextFormField(
          controller: _specialInstructionsController,
          decoration: const InputDecoration(
            labelText: 'Special Instructions (Optional)',
            hintText: 'Any additional information about your services',
            prefixIcon: Icon(Icons.notes),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Business License Upload
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.assignment,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                _businessLicenseImage == null
                    ? 'Upload Business License'
                    : 'Business License Uploaded',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickBusinessLicense,
                icon: const Icon(Icons.upload),
                label: const Text('Choose File'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Insurance Document Upload
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.security,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                _insuranceDocumentImage == null
                    ? 'Upload Insurance Document'
                    : 'Insurance Document Uploaded',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickInsuranceDocument,
                icon: const Icon(Icons.upload),
                label: const Text('Choose File'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Vehicle Images Upload
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.local_shipping,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Upload Vehicle Photos',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_vehicleImages.length} photos selected',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickVehicleImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Photos'),
              ),
            ],
          ),
        ),

        if (_vehicleImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _vehicleImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _vehicleImages[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => _removeVehicleImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayAvailability(String day) {
    final dayName = day.substring(0, 1).toUpperCase() + day.substring(1);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                dayName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Checkbox(
              value: _availabilityDays[day],
              onChanged: (value) {
                setState(() => _availabilityDays[day] = value ?? false);
              },
            ),
            const Text('Available'),
            const Spacer(),
            if (_availabilityDays[day]!) ...[
              GestureDetector(
                onTap: () => _selectAvailabilityTime(day, true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_formatTime(_startTimes[day]!)),
                ),
              ),
              const Text(' - '),
              GestureDetector(
                onTap: () => _selectAvailabilityTime(day, false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_formatTime(_endTimes[day]!)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      String title, String subtitle, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Your Service Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),

        // Company Information Summary
        _buildInfoCard(
          'Company Information',
          [
            'Company: ${_companyNameController.text}',
            'Address: ${_companyAddressController.text}',
            'Contact: ${_contactPersonController.text}',
            'Phone: ${_companyPhoneController.text}',
            'Email: ${_companyEmailController.text}',
            'Service Areas: ${_serviceAreasController.text}',
          ],
        ),

        const SizedBox(height: 16),

        // Services Summary
        _buildInfoCard(
          'Service Capabilities',
          [
            'Services: ${_serviceTypes.entries.where((e) => e.value).map((e) => _serviceTypeLabels[e.key]).join(', ')}',
            'Vehicles: ${_vehicleTypes.entries.where((e) => e.value).map((e) => _vehicleTypeLabels[e.key]).join(', ')}',
            'Special: ${_specialServices.entries.where((e) => e.value).map((e) => _specialServiceLabels[e.key]).join(', ')}',
          ],
        ),

        const SizedBox(height: 16),

        // Availability Summary
        _buildInfoCard(
          'Availability',
          [
            if (_is24x7Available)
              'Available 24/7'
            else
              ..._availabilityDays.entries
                  .where((entry) => entry.value)
                  .map((entry) {
                final day = entry.key.substring(0, 1).toUpperCase() +
                    entry.key.substring(1);
                return '$day: ${_formatTime(_startTimes[entry.key]!)} - ${_formatTime(_endTimes[entry.key]!)}';
              }).toList(),
            if (_specialInstructionsController.text.isNotEmpty)
              'Special Instructions: ${_specialInstructionsController.text}',
          ],
        ),

        const SizedBox(height: 16),

        // Documents Summary
        _buildInfoCard(
          'Documents & Photos',
          [
            'Business License: ${_businessLicenseImage != null ? 'Uploaded' : 'Not provided'}',
            'Insurance Document: ${_insuranceDocumentImage != null ? 'Uploaded' : 'Not provided'}',
            'Vehicle Photos: ${_vehicleImages.length} uploaded',
          ],
        ),

        const SizedBox(height: 24),

        // Verification Notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verification Process',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your delivery service information will be reviewed by our team. This process typically takes 2-5 business days. We may contact you for additional information or clarification.',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Upload Progress
        if (_isUploading)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                const Text('Uploading documents and photos...'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $item',
                  style: const TextStyle(fontSize: 14),
                ),
              )),
        ],
      ),
    );
  }

  bool _isValidStep(int step) {
    switch (step) {
      case 0:
        return _companyNameController.text.trim().isNotEmpty &&
            _companyAddressController.text.trim().isNotEmpty &&
            _contactPersonController.text.trim().isNotEmpty &&
            _companyPhoneController.text.trim().isNotEmpty &&
            _companyEmailController.text.trim().isNotEmpty &&
            _serviceAreasController.text.trim().isNotEmpty &&
            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                .hasMatch(_companyEmailController.text);
      case 1:
        return _serviceTypes.values.any((selected) => selected) &&
            _vehicleTypes.values.any((selected) => selected);
      case 2:
        return true; // Availability and documents are flexible
      case 3:
        return true; // Review step is always valid if reached
      default:
        return false;
    }
  }

  Future<void> _selectAvailabilityTime(String day, bool isStartTime) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTimes[day]! : _endTimes[day]!,
    );

    if (time != null) {
      setState(() {
        if (isStartTime) {
          _startTimes[day] = time;
        } else {
          _endTimes[day] = time;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickBusinessLicense() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() => _businessLicenseImage = File(image.path));
    }
  }

  Future<void> _pickInsuranceDocument() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() => _insuranceDocumentImage = File(image.path));
    }
  }

  Future<void> _pickVehicleImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        _vehicleImages.addAll(images.map((image) => File(image.path)));
      });
    }
  }

  void _removeVehicleImage(int index) {
    setState(() {
      _vehicleImages.removeAt(index);
    });
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate() || !_isValidStep(3)) return;

    setState(() => _isLoading = true);
    setState(() => _isUploading = true);

    try {
      final currentUser = _userService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Upload business license
      String? businessLicenseUrl;
      if (_businessLicenseImage != null) {
        businessLicenseUrl = await FileUploadService.uploadImage(
          imageFile: _businessLicenseImage!,
          path: 'users/${currentUser.uid}/delivery',
          fileName: 'license.jpg',
        );
      }

      // Upload insurance document
      String? insuranceDocumentUrl;
      if (_insuranceDocumentImage != null) {
        insuranceDocumentUrl = await FileUploadService.uploadImage(
          imageFile: _insuranceDocumentImage!,
          path: 'users/${currentUser.uid}/delivery',
          fileName: 'insurance.jpg',
        );
      }

      // Upload vehicle images
      List<String> vehicleImageUrls = [];
      for (int i = 0; i < _vehicleImages.length; i++) {
        final url = await FileUploadService.uploadImage(
          imageFile: _vehicleImages[i],
          path: 'users/${currentUser.uid}/delivery',
          fileName: 'vehicle_$i.jpg',
        );
        if (url != null) {
          vehicleImageUrls.add(url);
        }
      }

      // Create availability schedule
      final availabilityHours = <String, TimeSlot>{};
      for (final day in _availabilityDays.keys) {
        if (_availabilityDays[day]!) {
          availabilityHours[day] = TimeSlot(
            startTime: _formatTime(_startTimes[day]!),
            endTime: _formatTime(_endTimes[day]!),
            isClosed: false,
          );
        } else {
          availabilityHours[day] = TimeSlot(
            startTime: '08:00',
            endTime: '18:00',
            isClosed: true,
          );
        }
      }

      // Create delivery capabilities
      final capabilities = DeliveryCapabilities(
        maxWeight: 50.0, // Default 50kg capacity
        maxVolume: 2.0, // Default 2 cubic meters
        fragileItems: _specialServices['fragile_handling'] ?? false,
        refrigerated: _specialServices['cold_storage'] ?? false,
        express: _specialServices['express_delivery'] ?? false,
        maxDistance: 100, // Default 100km radius
      );

      // Create delivery data with extended fields in a map format for storage
      final deliveryData = {
        'businessName': _companyNameController.text.trim(),
        'businessAddress': _companyAddressController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'companyPhone': _companyPhoneController.text.trim(),
        'companyEmail': _companyEmailController.text.trim(),
        'serviceAreas': _serviceAreasController.text
            .split(',')
            .map((area) => area.trim())
            .where((area) => area.isNotEmpty)
            .toList(),
        'vehicleTypes': _vehicleTypes.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
        'serviceTypes': _serviceTypes.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
        'specialServices': _specialServices.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
        'capabilities': capabilities.toMap(),
        'businessLicenseUrl': businessLicenseUrl,
        'insuranceDocumentUrl': insuranceDocumentUrl,
        'vehicleImages': vehicleImageUrls,
        'specialInstructions':
            _specialInstructionsController.text.trim().isEmpty
                ? null
                : _specialInstructionsController.text.trim(),
        'availabilityHours': BusinessHours(
          weeklyHours: availabilityHours,
          is24x7: _is24x7Available,
        ).toMap(),
        'rating': 0.0,
        'totalDeliveries': 0,
        'isAvailable': true,
      };

      // Update user role data
      await _userService.updateRoleDataNamed(
        userId: currentUser.uid,
        role: UserRole.delivery,
        data: deliveryData,
      );

      // Submit for verification
      await _userService.submitRoleForVerificationNamed(
        userId: currentUser.uid,
        role: UserRole.delivery,
      );

      // Show success and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Delivery partner verification submitted successfully! We\'ll review your information and get back to you within 2-5 business days.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        Navigator.pushReplacementNamed(context, '/main-dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        setState(() => _isUploading = false);
      }
    }
  }
}
