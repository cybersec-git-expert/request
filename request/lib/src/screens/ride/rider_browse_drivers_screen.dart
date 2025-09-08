import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/glass_theme.dart';

class RiderBrowseDriversScreen extends StatefulWidget {
  const RiderBrowseDriversScreen({super.key});

  @override
  State<RiderBrowseDriversScreen> createState() =>
      _RiderBrowseDriversScreenState();
}

class _RiderBrowseDriversScreenState extends State<RiderBrowseDriversScreen> {
  final _api = ApiClient.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _drivers = [];
  String? _vehicleFilter;
  String? _cityFilter;
  final TextEditingController _vehicleCtl = TextEditingController();
  final TextEditingController _cityCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vehicleCtl.text = _vehicleFilter ?? '';
    _cityCtl.text = _cityFilter ?? '';
    _load();
  }

  @override
  void dispose() {
    _vehicleCtl.dispose();
    _cityCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = {
        'country': 'LK',
        if (_vehicleFilter != null && _vehicleFilter!.isNotEmpty)
          'vehicleType': _vehicleFilter!,
        if (_cityFilter != null && _cityFilter!.isNotEmpty)
          'city': _cityFilter!,
        'limit': '50',
      };
      final res = await _api.get<dynamic>(
        '/api/driver-verifications/public',
        queryParameters: params,
      );
      final raw = res.data;
      List<Map<String, dynamic>> list = [];
      if (raw is List) {
        list = List<Map<String, dynamic>>.from(raw);
      } else if (raw is Map<String, dynamic>) {
        final dataField = raw['data'];
        if (dataField is List) {
          list = List<Map<String, dynamic>>.from(dataField);
        } else if (dataField is Map<String, dynamic>) {
          final items = dataField['items'];
          if (items is List) {
            list = List<Map<String, dynamic>>.from(items);
          }
        } else if (raw['items'] is List) {
          list = List<Map<String, dynamic>>.from(raw['items'] as List);
        }
      }
      if (mounted) setState(() => _drivers = list);
    } catch (_) {
      if (mounted) setState(() => _drivers = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Available Drivers'),
        backgroundColor: Colors.transparent,
        foregroundColor: GlassTheme.colors.textPrimary,
        elevation: 0,
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _chipInput(
                        hint: 'Vehicle type (e.g., Car, Bike)',
                        controller: _vehicleCtl,
                        onChanged: (v) => setState(
                            () => _vehicleFilter = v.isEmpty ? null : v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _chipInput(
                        hint: 'City (e.g., Kandy)',
                        controller: _cityCtl,
                        onChanged: (v) =>
                            setState(() => _cityFilter = v.isEmpty ? null : v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _load,
                      style: GlassTheme.primaryButton,
                      child: const Text('Find'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _drivers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.directions_car,
                                    size: 56,
                                    color: GlassTheme.colors.textTertiary),
                                const SizedBox(height: 12),
                                Text('No drivers found',
                                    style: TextStyle(
                                        color:
                                            GlassTheme.colors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                            itemCount: _drivers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) => _driverCard(_drivers[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipInput(
      {required String hint,
      required TextEditingController controller,
      required ValueChanged<String> onChanged}) {
    return Container(
      decoration: GlassTheme.glassContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
        ),
        style: TextStyle(color: GlassTheme.colors.textPrimary),
        controller: controller,
        onSubmitted: onChanged,
        onChanged: onChanged,
      ),
    );
  }

  Widget _driverCard(Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Driver';
    final city = d['city']?.toString() ?? '';
    final vType = d['vehicleType']?.toString() ?? '';
    final vModel = d['vehicleModel']?.toString() ?? '';
    final vYear = d['vehicleYear']?.toString() ?? '';
    final driverImageRaw = d['driverImageUrl'];
    final driverImage =
        driverImageRaw != null && driverImageRaw.toString().isNotEmpty
            ? driverImageRaw.toString()
            : null;
    final img = (driverImage != null && driverImage.isNotEmpty)
        ? driverImage
        : (d['vehicleImageUrls'] is List &&
                (d['vehicleImageUrls'] as List).isNotEmpty
            ? (d['vehicleImageUrls'] as List).first.toString()
            : null);

    return Container(
      decoration: GlassTheme.glassContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ClipOval(
              child: Container(
                color: Colors.black.withOpacity(0.06),
                child: img == null
                    ? Icon(Icons.person, color: GlassTheme.colors.textTertiary)
                    : Image.network(
                        img,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        cacheWidth: 112,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) => Icon(Icons.person,
                            color: GlassTheme.colors.textTertiary),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.colors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    [
                      vType,
                      vModel,
                      if (vYear.isNotEmpty) vYear,
                    ].where((e) => e.toString().isNotEmpty).join(' • '),
                    style: TextStyle(color: GlassTheme.colors.textSecondary)),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: GlassTheme.colors.textTertiary),
                      const SizedBox(width: 4),
                      Flexible(
                          child: Text(city,
                              style: TextStyle(
                                  color: GlassTheme.colors.textSecondary))),
                    ],
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // Later: start chat or send ride request to this driver
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact coming soon')),
              );
            },
            style: GlassTheme.primaryButton,
            child: const Text('Contact'),
          )
        ],
      ),
    );
  }
}
