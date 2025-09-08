import 'package:flutter/material.dart';
import '../services/enhanced_user_service.dart';
import '../services/country_service.dart';
import '../theme/app_theme.dart';
import '../theme/glass_theme.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_upload_service.dart';
import '../widgets/simple_phone_field.dart';
import 'dart:io';
import '../services/api_client.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final EnhancedUserService _userService = EnhancedUserService();
  final FileUploadService _fileUploadService = FileUploadService();

  // Business Information Controllers
  final _businessNameController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _taxIdController = TextEditingController();

  // Dynamic Business Type and Item Subcategories (from backend)
  List<dynamic> _businessTypes = [];
  String? _selectedBusinessTypeGlobalId; // use global_business_type_id for POST
  List<dynamic> _itemSubcategoriesByCategory = [];
  Map<String, dynamic> _subcategoriesByBusinessType = {};
  List<dynamic> _currentSubcategoriesByCategory = [];
  final Set<String> _selectedSubcategoryIds = <String>{};
  final Map<String, String> _subcategoryNameById = <String, String>{};
  bool _showSubcategoryPicker =
      false; // show subcategory selector when selected type has groups
  bool _loadingFormData = false;
  String? _formDataError;

  // Business Documents
  File? _businessLicenseFile;
  File? _taxCertificateFile;
  File? _insuranceDocumentFile;
  File? _businessLogoFile;

  String? _businessLicenseUrl;
  String? _taxCertificateUrl;
  String? _insuranceDocumentUrl;
  // Removed unused _businessLogoUrl

  bool _isSubmitting = false;

  // Onboarding context (from Membership)
  String? _selectedRoleFromOnboarding; // delivery | professional | business
  String?
      _selectedProfessionalArea; // tour | event | construction | education | hiring

  bool _didReadArgs =
      false; // ensure we only read once in didChangeDependencies

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    _loadFormData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;
    _didReadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final role = args['selectedRole']?.toString();
      final area = args['professionalArea']?.toString();
      setState(() {
        _selectedRoleFromOnboarding = role;
        _selectedProfessionalArea = area;
      });
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          _businessEmailController.text = currentUser.email;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessEmailController.dispose();
    _businessPhoneController.dispose();
    _businessAddressController.dispose();
    _businessDescriptionController.dispose();
    _licenseNumberController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() {
      _loadingFormData = true;
      _formDataError = null;
    });

    try {
      // Ensure country is loaded
      await CountryService.instance.loadPersistedCountry();
      final countryCode = CountryService.instance.countryCode ?? 'LK';

      final resp = await ApiClient.instance.get<dynamic>(
        '/api/business-registration/form-data',
        queryParameters: {'country_code': countryCode},
      );

      if (resp.success && resp.data is Map<String, dynamic>) {
        final map = resp.data as Map<String, dynamic>;
        final data = map['data'] ?? map; // handle both wrapped and raw
        setState(() {
          _businessTypes = (data['businessTypes'] as List?) ?? [];
          _itemSubcategoriesByCategory =
              (data['itemSubcategoriesByCategory'] as List?) ?? [];
          _subcategoriesByBusinessType =
              (data['subcategoriesByBusinessType'] as Map?)
                      ?.map((k, v) => MapEntry(k.toString(), v)) ??
                  {};
          _subcategoryNameById.clear();
          for (final cat in _itemSubcategoriesByCategory) {
            final subs = (cat['subcategories'] as List?) ?? [];
            for (final s in subs) {
              final id = s['id']?.toString();
              final name = s['name']?.toString() ?? '';
              if (id != null) _subcategoryNameById[id] = name;
            }
          }
        });
      } else {
        setState(() {
          _formDataError = resp.error ?? 'Failed to load form data';
        });
      }
    } catch (e) {
      setState(() {
        _formDataError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFormData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Business Registration'),
        backgroundColor: Colors.transparent,
        foregroundColor: GlassTheme.colors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildBusinessInformationSection(),
              const SizedBox(height: 24),
              _buildBusinessDocumentsSection(),
              const SizedBox(height: 24),
              _buildBusinessLogoSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildHeader() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business,
                    color: GlassTheme.colors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Text('Business Registration', style: GlassTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your business registration to start offering services on our platform.',
            style: GlassTheme.bodyMedium,
          ),
          if (_selectedRoleFromOnboarding != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _contextBadge('Role: ${_selectedRoleFromOnboarding!}'),
                if (_selectedProfessionalArea != null)
                  _contextBadge('Area: ${_selectedProfessionalArea!}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _contextBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GlassTheme.colors.textSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_rounded,
              size: 14, color: GlassTheme.colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: GlassTheme.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInformationSection() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business_center,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Business Information', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _businessNameController,
            label: 'Business Name *',
            hint: 'Enter your business name',
            prefixIcon: Icons.business,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Business name is required' : null,
          ),
          _buildTextField(
            controller: _businessEmailController,
            label: 'Business Email *',
            hint: 'Enter business email',
            prefixIcon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Business email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SimplePhoneField(
            controller: _businessPhoneController,
            label: 'Business Phone *',
            hint: 'Enter business phone number',
            validator: (value) =>
                value?.isEmpty ?? true ? 'Business phone is required' : null,
          ),
          _buildTextField(
            controller: _businessAddressController,
            label: 'Business Address *',
            hint: 'Enter complete business address',
            prefixIcon: Icons.location_on,
            maxLines: 3,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Business address is required' : null,
          ),
          _buildTextField(
            controller: _businessDescriptionController,
            label: 'Business Description *',
            hint: 'Describe your business and services',
            prefixIcon: Icons.description,
            maxLines: 4,
            validator: (value) => value?.isEmpty ?? true
                ? 'Business description is required'
                : null,
          ),
          _buildBusinessTypeDropdown(),
          const SizedBox(height: 8),
          if (_showSubcategoryPicker) _buildItemSubcategoriesField(),
          _buildTextField(
            controller: _licenseNumberController,
            label: 'Business License Number',
            hint: 'Enter business license number (optional)',
            prefixIcon: Icons.assignment,
          ),
          _buildTextField(
            controller: _taxIdController,
            label: 'Tax ID / VAT Number',
            hint: 'Enter tax ID or VAT number (optional)',
            prefixIcon: Icons.receipt,
          ),
        ],
      ),
    );
  }

  Widget _buildItemSubcategoriesField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferred Subcategories (multi-select)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingFormData)
            const LinearProgressIndicator(minHeight: 2)
          else if (_formDataError != null)
            Text(
              _formDataError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            )
          else if (_currentSubcategoriesByCategory.isEmpty)
            const Text(
              'No subcategories available for your selection.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else
            GestureDetector(
              onTap: _openSubcategoryPicker,
              child: Container(
                decoration: GlassTheme.glassContainerSubtle,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.list_alt,
                      color: GlassTheme.colors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedSubcategorySummary(),
                        style: GlassTheme.bodyMedium,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _selectedSubcategorySummary() {
    if (_selectedSubcategoryIds.isEmpty) return 'Select subcategories';
    final names = _selectedSubcategoryIds
        .map((id) => _subcategoryNameById[id] ?? 'Sub')
        .take(3)
        .toList();
    final extra = _selectedSubcategoryIds.length - names.length;
    if (extra > 0) {
      return '${names.join(', ')} + $extra more';
    }
    return names.join(', ');
  }

  void _openSubcategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final initial = Set<String>.from(_selectedSubcategoryIds);
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<dynamic> filteredCats = _currentSubcategoriesByCategory
                .map((cat) {
                  final List subs = (cat['subcategories'] as List?) ?? [];
                  final filteredSubs = query.isEmpty
                      ? subs
                      : subs
                          .where(
                            (s) => (s['name']?.toString().toLowerCase() ?? '')
                                .contains(query.toLowerCase()),
                          )
                          .toList();
                  return {
                    'category_name': cat['category_name'],
                    'subcategories': filteredSubs,
                  };
                })
                .where((cat) => (cat['subcategories'] as List).isNotEmpty)
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'Select Subcategories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search subcategories',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(initial.clear),
                          child: const Text('Clear all'),
                        ),
                        const Spacer(),
                        Text('${initial.length} selected'),
                      ],
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCats.length,
                        itemBuilder: (context, index) {
                          final cat = filteredCats[index];
                          final String name =
                              cat['category_name']?.toString() ?? 'Category';
                          final List subs =
                              (cat['subcategories'] as List?) ?? [];
                          return Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: subs.map<Widget>((s) {
                                final id = s['id'].toString();
                                final checked = initial.contains(id);
                                return CheckboxListTile(
                                  value: checked,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        initial.add(id);
                                      } else {
                                        initial.remove(id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    s['name']?.toString() ?? 'Subcategory',
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  dense: true,
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedSubcategoryIds
                              ..clear()
                              ..addAll(initial);
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Apply Selection'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBusinessDocumentsSection() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Business Documents', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          _buildDocumentUpload(
            title: 'Business License (optional)',
            description: 'Upload your business license if available.',
            file: _businessLicenseFile,
            url: _businessLicenseUrl,
            onTap: () => _pickDocument('business_license'),
            isRequired: false,
          ),
          _buildDocumentUpload(
            title: 'Tax Certificate (optional)',
            description: 'Provide a tax/VAT certificate if available.',
            file: _taxCertificateFile,
            url: _taxCertificateUrl,
            onTap: () => _pickDocument('tax_certificate'),
            isRequired: false,
          ),
          _buildDocumentUpload(
            title: 'Insurance Document (optional)',
            description: 'Upload insurance proof if applicable.',
            file: _insuranceDocumentFile,
            url: _insuranceDocumentUrl,
            onTap: () => _pickDocument('insurance'),
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessLogoSection() {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.image,
                    color: GlassTheme.colors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Business Logo', style: GlassTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          _buildLogoUpload(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines ?? 1,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                prefixIcon,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Type *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingFormData)
            const LinearProgressIndicator(minHeight: 2)
          else if (_formDataError != null)
            Text(
              _formDataError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedBusinessTypeGlobalId,
              hint: const Text('Select business type'),
              validator: (value) =>
                  value == null ? 'Business type is required' : null,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.category,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _businessTypes.map((bt) {
                final id =
                    (bt['global_business_type_id'] ?? bt['id']).toString();
                final name = bt['name']?.toString() ?? 'Unknown';
                return DropdownMenuItem<String>(value: id, child: Text(name));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBusinessTypeGlobalId = value;
                  // Compute groups for this business type
                  final groups = (_subcategoriesByBusinessType[value]?['groups']
                          as List?) ??
                      [];
                  _currentSubcategoriesByCategory = groups;
                  _showSubcategoryPicker = groups.isNotEmpty;
                  // refresh name map for summary
                  _subcategoryNameById.clear();
                  for (final cat in _currentSubcategoriesByCategory) {
                    final subs = (cat['subcategories'] as List?) ?? [];
                    for (final s in subs) {
                      final id = s['id']?.toString();
                      final name = s['name']?.toString() ?? '';
                      if (id != null) _subcategoryNameById[id] = name;
                    }
                  }
                  if (!_showSubcategoryPicker) _selectedSubcategoryIds.clear();
                });
              },
            ),
        ],
      ),
    );
  }

  // Removed legacy product-type detector; now we rely on server-provided group mapping

  Widget _buildDocumentUpload({
    required String title,
    required String description,
    required File? file,
    required String? url,
    required VoidCallback onTap,
    required bool isRequired,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          if (file != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File selected: ${file.path.split('/').last}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(
                file != null ? Icons.refresh : Icons.camera_alt,
                size: 16,
              ),
              label: Text(file != null ? 'Change File' : 'Choose File'),
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (_businessLogoFile != null) ...[
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_businessLogoFile!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.business, size: 40, color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            const Text(
              'No logo selected',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickDocument('business_logo'),
              icon: Icon(
                _businessLogoFile != null ? Icons.refresh : Icons.camera_alt,
                size: 16,
              ),
              label: Text(
                _businessLogoFile != null ? 'Change Logo' : 'Choose Logo',
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitBusinessRegistration,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.business_center),
        label: Text(
          _isSubmitting ? 'Submitting...' : 'Submit for Verification',
        ),
        style: GlassTheme.primaryButton,
      ),
    );
  }

  Future<void> _pickDocument(String documentType) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          switch (documentType) {
            case 'business_license':
              _businessLicenseFile = File(pickedFile.path);
              break;
            case 'tax_certificate':
              _taxCertificateFile = File(pickedFile.path);
              break;
            case 'insurance':
              _insuranceDocumentFile = File(pickedFile.path);
              break;
            case 'business_logo':
              _businessLogoFile = File(pickedFile.path);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitBusinessRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBusinessTypeGlobalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a business type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) throw Exception('User not authenticated');

      // Get user's country information - try to load if not available
      await CountryService.instance.loadPersistedCountry();

      String? countryCode = CountryService.instance.countryCode;
      String countryName = CountryService.instance.countryName; // non-nullable

      if (countryCode == null || countryName.isEmpty) {
        // Try to get default country if none is set
        try {
          final countries = await CountryService.instance.getAllCountries();
          final defaultCountry = countries.firstWhere(
            (c) => c.isEnabled,
            orElse: () => countries.first,
          );
          await CountryService.instance.setCountryFromObject(defaultCountry);
          print(
            '✅ Set default country: ${defaultCountry.name} (${defaultCountry.code})',
          );

          // Get the values again after setting
          countryCode = CountryService.instance.countryCode;
          countryName = CountryService.instance.countryName;
        } catch (e) {
          print('❌ Failed to set default country: $e');
          throw Exception(
            'Country information not available. Please restart the app and select your country.',
          );
        }
      }

      // Upload documents if selected
      String? businessLicenseUrl;
      String? taxCertificateUrl;
      String? insuranceDocumentUrl;
      String? businessLogoUrl;

      if (_businessLicenseFile != null) {
        businessLicenseUrl = await _fileUploadService.uploadBusinessDocument(
          currentUser.uid,
          _businessLicenseFile!,
          'business_license',
        );
      }

      if (_taxCertificateFile != null) {
        taxCertificateUrl = await _fileUploadService.uploadBusinessDocument(
          currentUser.uid,
          _taxCertificateFile!,
          'tax_certificate',
        );
      }

      if (_insuranceDocumentFile != null) {
        insuranceDocumentUrl = await _fileUploadService.uploadBusinessDocument(
          currentUser.uid,
          _insuranceDocumentFile!,
          'insurance_document',
        );
      }

      if (_businessLogoFile != null) {
        businessLogoUrl = await _fileUploadService.uploadBusinessDocument(
          currentUser.uid,
          _businessLogoFile!,
          'business_logo',
        );
      }

      // Prepare business registration data
      final businessData = {
        'userId': currentUser.uid,
        'country': countryCode, // Add country code (e.g., "LK")
        'countryName': countryName, // Add country name (e.g., "Sri Lanka")
        'businessName': _businessNameController.text.trim(),
        'businessEmail': _businessEmailController.text.trim(),
        'businessPhone': _businessPhoneController.text.trim(),
        'businessAddress': _businessAddressController.text.trim(),
        'businessDescription': _businessDescriptionController.text.trim(),
        // Use new server-backed fields
        'businessTypeId': _selectedBusinessTypeGlobalId,
        'categories':
            _showSubcategoryPicker ? _selectedSubcategoryIds.toList() : null,
        'licenseNumber': _licenseNumberController.text.trim(),
        'taxId': _taxIdController.text.trim().isEmpty
            ? null
            : _taxIdController.text.trim(),
        'status': 'pending',
        'isVerified': false,
        'submittedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        // Onboarding context (from Membership flow)
        'onboarding': {
          if (_selectedRoleFromOnboarding != null)
            'selectedRole': _selectedRoleFromOnboarding,
          if (_selectedProfessionalArea != null)
            'professionalArea': _selectedProfessionalArea,
        },
        // Document URLs
        'businessLicenseUrl': businessLicenseUrl,
        'taxCertificateUrl': taxCertificateUrl,
        'insuranceDocumentUrl': insuranceDocumentUrl,
        'businessLogoUrl': businessLogoUrl,
        // Document status tracking
        'businessLicenseStatus': businessLicenseUrl != null ? 'pending' : null,
        'taxCertificateStatus': taxCertificateUrl != null ? 'pending' : null,
        'insuranceDocumentStatus':
            insuranceDocumentUrl != null ? 'pending' : null,
        'businessLogoStatus': businessLogoUrl != null ? 'pending' : null,
        // Document verification nested structure
        'documentVerification': {
          if (businessLicenseUrl != null)
            'businessLicense': {
              'status': 'pending',
              'submittedAt': DateTime.now(),
            },
          if (taxCertificateUrl != null)
            'taxCertificate': {
              'status': 'pending',
              'submittedAt': DateTime.now(),
            },
          if (insuranceDocumentUrl != null)
            'insurance': {'status': 'pending', 'submittedAt': DateTime.now()},
          if (businessLogoUrl != null)
            'businessLogo': {'status': 'pending', 'uploadedAt': DateTime.now()},
        },
      };

      // Submit to Firestore
      await _userService.submitBusinessVerification(businessData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Business registration submitted successfully! We\'ll review your information and get back to you within 2-5 business days.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Navigate back to main dashboard
        Navigator.pushReplacementNamed(context, '/main-dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting registration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
