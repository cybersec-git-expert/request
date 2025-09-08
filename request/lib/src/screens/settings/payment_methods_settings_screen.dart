import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/payment_methods_service.dart';
import '../../services/rest_support_services.dart';
import '../../theme/glass_theme.dart';

class PaymentMethodsSettingsScreen extends StatefulWidget {
  const PaymentMethodsSettingsScreen({super.key});

  @override
  State<PaymentMethodsSettingsScreen> createState() =>
      _PaymentMethodsSettingsScreenState();
}

class _PaymentMethodsSettingsScreenState
    extends State<PaymentMethodsSettingsScreen> {
  List<String> _selected = [];
  List<String> _initialSelected = [];
  List<PaymentMethod> _allMethods = [];
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final user = AuthService.instance.currentUser;
      // Load country methods for current country (always)
      final countryCode = CountryService.instance.getCurrentCountryCode();
      _allMethods =
          await PaymentMethodsService.getPaymentMethodsForCountry(countryCode);

      // Load selected only if user available
      if (user != null) {
        _selected =
            await PaymentMethodsService.getSelectedForBusiness(user.uid);
        _initialSelected = List.from(_selected);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Widget to display payment method image with S3 signed URL support
  Widget _buildPaymentMethodImage(PaymentMethod method, {double size = 40}) {
    return FutureBuilder<String?>(
      future: method.getImageUrl(),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;
        final hasImage = imageUrl != null && imageUrl.isNotEmpty;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: hasImage
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print(
                          'Failed to load payment image: $imageUrl, Error: $error');
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.payment,
                            size: size * 0.5, color: Colors.grey),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.payment,
                        size: size * 0.5, color: Colors.grey),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;
      final ok = await PaymentMethodsService.setSelectedForBusiness(
          user.uid, _selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Saved payment methods' : 'Failed to save'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) {
        _initialSelected = List.from(_selected);
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _dirty {
    if (_selected.length != _initialSelected.length) return true;
    final a = Set.of(_selected);
    final b = Set.of(_initialSelected);
    return a.difference(b).isNotEmpty;
  }

  void _remove(String id) {
    setState(() {
      _selected.remove(id);
    });
  }

  Future<void> _openAddSheet() async {
    if (_allMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No payment methods available for your country.')),
      );
      return;
    }
    final notSelected =
        _allMethods.where((m) => !_selected.contains(m.id)).toList();
    if (notSelected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All available methods are already added.')),
      );
      return;
    }
    final added = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final localSelected = <String>{};
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return StatefulBuilder(builder: (context, setLocal) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  const Text('Add Payment Methods',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: notSelected.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = notSelected[index];
                        final isPicked = localSelected.contains(m.id);
                        return ListTile(
                          leading: _buildPaymentMethodImage(m, size: 40),
                          title: Text(m.name),
                          subtitle: m.category.isNotEmpty
                              ? Text(m.category.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey))
                              : null,
                          trailing: Checkbox(
                            value: isPicked,
                            onChanged: (v) {
                              if (v == true) {
                                localSelected.add(m.id);
                              } else {
                                localSelected.remove(m.id);
                              }
                              setLocal(() {});
                            },
                          ),
                          onTap: () {
                            if (isPicked) {
                              localSelected.remove(m.id);
                            } else {
                              localSelected.add(m.id);
                            }
                            setLocal(() {});
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: localSelected.isEmpty
                                ? null
                                : () => Navigator.pop(
                                    context, localSelected.toList()),
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              );
            });
          },
        );
      },
    );
    if (added != null && added.isNotEmpty) {
      setState(() {
        _selected.addAll(added.where((id) => !_selected.contains(id)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMethods =
        _allMethods.where((m) => _selected.contains(m.id)).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: GlassTheme.colors.textPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: GlassTheme.colors.textSecondary),
            tooltip: 'Add',
            onPressed: _loading ? null : _openAddSheet,
          ),
        ],
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add your payment methods',
                        style: TextStyle(
                          fontSize: 14,
                          color: GlassTheme.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedMethods.isEmpty) ...[
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.credit_card_off,
                                    size: 56,
                                    color: GlassTheme.colors.textTertiary),
                                const SizedBox(height: 8),
                                Text(
                                  'No payment methods added',
                                  style: TextStyle(
                                      color: GlassTheme.colors.textSecondary),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _openAddSheet,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        GlassTheme.colors.primaryBlue,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: selectedMethods.map((m) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _buildPaymentMethodImage(m, size: 40),
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: InkWell(
                                    onTap: () => _remove(m.id),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: GlassTheme.colors.primaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                )
                              ],
                            );
                          }).toList(),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _dirty && !_saving ? _save : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              backgroundColor: GlassTheme.colors.primaryBlue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  Colors.grey.withOpacity(0.3),
                              disabledForegroundColor:
                                  Colors.white.withOpacity(0.7),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white)),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
