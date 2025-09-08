import 'package:flutter/material.dart';
import '../services/feature_gate_service.dart';
import '../services/user_registration_service.dart';
import '../theme/app_theme.dart';
import '../theme/glass_theme.dart';

class RoleRegistrationScreen extends StatefulWidget {
  final String selectedRole; // driver | business | delivery | professional
  final String? professionalArea; // optional context for professionals

  const RoleRegistrationScreen({
    super.key,
    required this.selectedRole,
    this.professionalArea,
  });

  @override
  State<RoleRegistrationScreen> createState() => _RoleRegistrationScreenState();
}

class _RoleRegistrationScreenState extends State<RoleRegistrationScreen> {
  bool _loading = true;
  bool _driverEnabled = true;
  // Registration state
  bool _isDriverApproved = false;
  bool _hasPendingDriver = false;
  bool _isBusinessApproved = false;
  bool _hasPendingBusiness = false;

  bool get _isDriverRole => widget.selectedRole == 'driver';
  bool get _isBusinessLikeRole =>
      widget.selectedRole == 'business' ||
      widget.selectedRole == 'delivery' ||
      widget.selectedRole == 'professional';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      // Feature gate for driver
      if (_isDriverRole) {
        _driverEnabled =
            await FeatureGateService.instance.isDriverRegistrationEnabled();
      }
      // Load existing registration state
      final regs =
          await UserRegistrationService.instance.getUserRegistrations();
      if (regs != null) {
        _isDriverApproved = regs.isApprovedDriver;
        _hasPendingDriver = regs.hasPendingDriverApplication;
        _isBusinessApproved = regs.isApprovedBusiness;
        _hasPendingBusiness = regs.hasPendingBusinessApplication;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _isDriverRole ? 'Driver Registration' : 'Business Registration';
    final subtitle = _isDriverRole
        ? 'Complete your driver registration to accept ride requests.'
        : 'Complete your business registration to start responding professionally.';

    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppTheme.textPrimary,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: GlassTheme.glassContainer,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _isDriverRole
                                ? Icons.directions_car
                                : Icons.business,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    )),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style:
                                      TextStyle(color: AppTheme.textSecondary),
                                ),
                                if (widget.professionalArea != null &&
                                    _isBusinessLikeRole) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Selected area: ${widget.professionalArea}',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary),
                                  )
                                ],
                              ],
                            ),
                          ),
                          _buildStatusChip(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isDriverRole)
                      _buildDriverActions()
                    else
                      _buildBusinessActions(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusChip() {
    String text = 'Not Started';
    Color color = Colors.grey;
    if (_isDriverRole) {
      if (_isDriverApproved) {
        text = 'Approved';
        color = Colors.green;
      } else if (_hasPendingDriver) {
        text = 'Pending';
        color = Colors.orange;
      }
    } else {
      if (_isBusinessApproved) {
        text = 'Approved';
        color = Colors.green;
      } else if (_hasPendingBusiness) {
        text = 'Pending';
        color = Colors.orange;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDriverActions() {
    if (!_driverEnabled) {
      return Container(
        decoration: GlassTheme.glassContainer,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver registration is not available in your country yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    FeatureGateService.instance.showComingSoonModal(
                      context: context,
                      featureName: 'Driver Registration',
                      description:
                          'Driver registration is not available in your country yet. We\'re working to bring ride sharing services to your region soon!',
                      icon: Icons.directions_car,
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Learn more'),
                  style: AppTheme.primaryButtonStyle,
                ),
              ),
            ]),
          ],
        ),
      );
    }

    return Container(
      decoration: GlassTheme.glassContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/driver-registration')
                    .then((_) => _init()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Start Driver Registration'),
            style: AppTheme.primaryButtonStyle,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/driver-verification')
                    .then((_) => _init()),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Manage Driver Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessActions() {
    return Container(
      decoration: GlassTheme.glassContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(
                context, '/business-registration',
                arguments: {
                  'selectedRole': widget.selectedRole,
                  if (widget.professionalArea != null)
                    'professionalArea': widget.professionalArea,
                }).then((_) => _init()),
            icon: const Icon(Icons.add_business, size: 18),
            label: const Text('Start Business Registration'),
            style: AppTheme.primaryButtonStyle,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/business-verification')
                    .then((_) => _init()),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Manage Business Profile'),
          ),
        ],
      ),
    );
  }
}
