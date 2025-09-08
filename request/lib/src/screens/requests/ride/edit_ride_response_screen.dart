import 'package:flutter/material.dart';
import '../../../models/request_model.dart';
import '../../../models/vehicle_type_model.dart';
import '../../../services/enhanced_request_service.dart';
import '../../../services/enhanced_user_service.dart';
import '../../../widgets/image_upload_widget.dart';
import '../../../widgets/accurate_location_picker_widget.dart';
import '../../../utils/currency_helper.dart';
import '../../../theme/glass_theme.dart';
import '../../../widgets/glass_page.dart';

class EditRideResponseScreen extends StatefulWidget {
  final ResponseModel response;
  final RequestModel? originalRequest;

  const EditRideResponseScreen({
    super.key,
    required this.response,
    this.originalRequest,
  });

  @override
  State<EditRideResponseScreen> createState() => _EditRideResponseScreenState();
}

class _EditRideResponseScreenState extends State<EditRideResponseScreen> {
  final _formKey = GlobalKey<FormState>();
  final EnhancedRequestService _requestService = EnhancedRequestService();
  final EnhancedUserService _userService = EnhancedUserService();

  // Form Controllers
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _vehicleDetailsController = TextEditingController();
  final _drivingExperienceController = TextEditingController();

  String _vehicleType = '';
  bool _smokingAllowed = false;
  bool _petsAllowed = true;
  DateTime? _departureTime;
  int _availableSeats = 3;
  List<String> _imageUrls = [];

  bool _isLoading = false;

  // Dynamic vehicle types from database
  List<VehicleTypeModel> _vehicleTypes = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    _initializeFromResponse();
  }

  Future<void> _loadVehicleTypes() async {
    try {
      // TODO: Implement proper vehicle type loading when VehicleService is updated
      setState(() {
        _vehicleTypes = []; // Placeholder until service is properly implemented
      });
    } catch (e) {
      print('Error loading vehicle types: $e');
    }
  }

  void _initializeFromResponse() {
    _descriptionController.text = widget.response.message;
    _priceController.text = widget.response.price?.toString() ?? '';
    _locationController.text = ''; // Response doesn't have location field
    _imageUrls = List<String>.from(widget.response.images);

    // Use additionalInfo instead of metadata
    final additionalInfo = widget.response.additionalInfo;
    _vehicleDetailsController.text = additionalInfo['vehicleDetails'] ?? '';
    _drivingExperienceController.text =
        additionalInfo['drivingExperience'] ?? '';
    _vehicleType = additionalInfo['vehicleType'] ??
        (_vehicleTypes.isNotEmpty ? _vehicleTypes.first.name : '');
    _availableSeats = additionalInfo['availableSeats'] ?? 3;
    _smokingAllowed = additionalInfo['smokingAllowed'] ?? false;
    _petsAllowed = additionalInfo['petsAllowed'] ?? true;

    if (additionalInfo['departureTime'] != null) {
      _departureTime = additionalInfo['departureTime'] is DateTime
          ? additionalInfo['departureTime']
          : DateTime.tryParse(additionalInfo['departureTime'].toString());
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _vehicleDetailsController.dispose();
    _drivingExperienceController.dispose();
    super.dispose();
  }

  Future<void> _selectDepartureTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _departureTime ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _departureTime != null
            ? TimeOfDay.fromDateTime(_departureTime!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _departureTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _updateResponse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select departure time')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      await _requestService.updateResponseNamed(
        responseId: widget.response.id,
        requestId:
            widget.response.requestId, // Need to ensure this field exists
        message: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text),
        // Note: Additional fields not available in updateResponseNamed
        // TODO: Handle additional vehicle info separately if needed
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride offer updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating offer: $e'),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Edit Ride Offer',
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _updateResponse,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save', style: TextStyle(fontSize: 16)),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.originalRequest != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: GlassTheme.glassContainerSubtle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original Request',
                      style: GlassTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(widget.originalRequest!.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (widget.originalRequest!.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(widget.originalRequest!.description),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle('Your Ride Offer'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe your ride offer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _drivingExperienceController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: CurrencyHelper.instance.getPriceLabel(),
                      hintText: '0.00',
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your price';
                      }
                      final price = double.tryParse(value.trim());
                      if (price == null || price <= 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _vehicleType,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                    ),
                    items: _vehicleTypes.map((vehicle) {
                      return DropdownMenuItem(
                        value: vehicle.name,
                        child: Text(
                            '${vehicle.name} (${vehicle.passengerCapacity} passengers)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _vehicleType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleDetailsController,
              decoration: InputDecoration(
                labelText: 'Vehicle Details',
                hintText: 'Make, model, year, color, license plate...',
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide vehicle details';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Trip Details'),
            const SizedBox(height: 12),
            Container(
              decoration: GlassTheme.glassContainerSubtle,
              child: ListTile(
                title: Text(_departureTime == null
                    ? 'Select Departure Time'
                    : 'Departure: ${_departureTime!.day}/${_departureTime!.month} at ${_departureTime!.hour}:${_departureTime!.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.access_time),
                onTap: _selectDepartureTime,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GlassTheme.glassContainerSubtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Seats: $_availableSeats',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Slider(
                    value: _availableSeats.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    onChanged: (value) {
                      setState(() {
                        _availableSeats = value.toInt();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Ride Preferences'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GlassTheme.glassContainerSubtle,
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Smoking Allowed'),
                    subtitle: const Text('Passengers can smoke in the vehicle'),
                    value: _smokingAllowed,
                    onChanged: (value) {
                      setState(() {
                        _smokingAllowed = value!;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Pets Allowed'),
                    subtitle: const Text('Passengers can bring pets'),
                    value: _petsAllowed,
                    onChanged: (value) {
                      setState(() {
                        _petsAllowed = value!;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Vehicle & Driver Images'),
            const SizedBox(height: 12),
            ImageUploadWidget(
              initialImages: _imageUrls,
              maxImages: 4,
              uploadPath: 'responses/ride',
              label: 'Upload vehicle & driver photos (up to 4)',
              onImagesChanged: (images) {
                setState(() {
                  _imageUrls = images;
                });
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Your Location'),
            const SizedBox(height: 12),
            AccurateLocationPickerWidget(
              controller: _locationController,
              labelText: 'Your Current Location',
              hintText: 'Where are you located?',
              isRequired: true,
              onLocationSelected: (address, lat, lng) {
                print('Driver location: $address at $lat, $lng');
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateResponse,
                style: GlassTheme.primaryButton,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Update Ride Offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
