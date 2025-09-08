import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/comprehensive_notification_service.dart';
import '../services/enhanced_user_service.dart';
import '../theme/app_theme.dart';

class DriverSubscriptionScreen extends StatefulWidget {
  const DriverSubscriptionScreen({super.key});

  @override
  State<DriverSubscriptionScreen> createState() => _DriverSubscriptionScreenState();
}

class _DriverSubscriptionScreenState extends State<DriverSubscriptionScreen> {
  final ComprehensiveNotificationService _notificationService = ComprehensiveNotificationService();
  final EnhancedUserService _userService = EnhancedUserService();

  List<DriverSubscription> _subscriptions = [];
  bool _loading = true;

  final List<String> _availableVehicleTypes = [
    'car',
    'motorcycle',
    'bicycle',
    'truck',
    'van',
    'bus',
    'taxi',
    'auto-rickshaw',
    'scooter',
    'electric-bike',
    'pickup-truck',
    'mini-bus',
  ];

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  void _loadSubscriptions() async {
    final userId = _userService.currentUser?.uid;
    if (userId != null) {
      final subscriptions = await _notificationService.getDriverSubscriptions(userId);
      setState(() {
        _subscriptions = subscriptions;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = _userService.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ride Notifications'),
        ),
        body: const Center(
          child: Text('Please log in to manage ride notifications'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        title: const Text('Ride Notifications'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add subscription',
            onPressed: _showAddSubscriptionDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildSubscriptionsList(),
    );
  }

  Widget _buildSubscriptionsList() {
    if (_subscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ride subscriptions',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subscribe to vehicle types to get notified when new ride requests are posted',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddSubscriptionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Subscription'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subscriptions.length,
      itemBuilder: (context, index) {
        final subscription = _subscriptions[index];
        return _buildSubscriptionCard(subscription);
      },
    );
  }

  Widget _buildSubscriptionCard(DriverSubscription subscription) {
    final isExpired = subscription.expiresAt.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: isExpired ? Colors.grey.withOpacity(0.1) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Vehicle type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isExpired 
                        ? Colors.grey.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getVehicleTypeIcon(subscription.vehicleType),
                    color: isExpired ? Colors.grey : Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Subscription details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatVehicleType(subscription.vehicleType),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isExpired ? Colors.grey : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isExpired 
                            ? 'Expired ${_formatTime(subscription.expiresAt)}'
                            : 'Expires ${_formatTime(subscription.expiresAt)}',
                        style: TextStyle(
                          color: isExpired ? Colors.red[600] : Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired 
                        ? Colors.red.withOpacity(0.1)
                        : subscription.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpired 
                        ? 'Expired'
                        : subscription.isActive 
                            ? 'Active' 
                            : 'Paused',
                    style: TextStyle(
                      color: isExpired 
                          ? Colors.red[600]
                          : subscription.isActive 
                              ? Colors.green[600] 
                              : Colors.orange[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                // More options
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  onSelected: (value) => _handleMenuAction(value, subscription),
                  itemBuilder: (context) => [
                    if (!isExpired && subscription.isActive)
                      const PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(Icons.pause, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Pause'),
                          ],
                        ),
                      ),
                    if (!isExpired && !subscription.isActive)
                      const PopupMenuItem(
                        value: 'resume',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Resume'),
                          ],
                        ),
                      ),
                    if (!isExpired)
                      const PopupMenuItem(
                        value: 'extend',
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Extend'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Location and additional info
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    subscription.location ?? 'All locations',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Created date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Created ${_formatTime(subscription.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getVehicleTypeIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'motorcycle':
      case 'scooter':
        return Icons.two_wheeler;
      case 'bicycle':
      case 'electric-bike':
        return Icons.pedal_bike;
      case 'truck':
      case 'pickup-truck':
        return Icons.local_shipping;
      case 'van':
        return Icons.airport_shuttle;
      case 'bus':
      case 'mini-bus':
        return Icons.directions_bus;
      case 'taxi':
        return Icons.local_taxi;
      case 'auto-rickshaw':
        return Icons.electric_rickshaw;
      default:
        return Icons.directions_car;
    }
  }

  String _formatVehicleType(String vehicleType) {
    return vehicleType.split('-').map((word) => 
      word.substring(0, 1).toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      return 'today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showAddSubscriptionDialog() {
    String? selectedVehicleType;
    String? location;
    int durationDays = 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Ride Subscription'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Vehicle type dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedVehicleType,
                  items: _availableVehicleTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getVehicleTypeIcon(type), size: 20),
                        const SizedBox(width: 8),
                        Text(_formatVehicleType(type)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedVehicleType = value;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Location field
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'e.g., Downtown, City Center',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    location = value.trim().isEmpty ? null : value.trim();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Duration slider
                Text(
                  'Subscription Duration: $durationDays days',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: durationDays.toDouble(),
                  min: 7,
                  max: 365,
                  divisions: 51,
                  label: '$durationDays days',
                  onChanged: (value) {
                    setDialogState(() {
                      durationDays = value.round();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedVehicleType != null
                  ? () => _addSubscription(selectedVehicleType!, location, durationDays)
                  : null,
              child: const Text('Subscribe'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSubscription(String vehicleType, String? location, int durationDays) async {
    final userId = _userService.currentUser?.uid;
    if (userId == null) return;

    Navigator.pop(context); // Close dialog

    try {
      await _notificationService.subscribeToRideNotifications(
        driverId: userId,
        vehicleType: vehicleType,
        serviceAreas: [location ?? 'Unknown'],
        location: location,
        subscriptionDays: durationDays,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscribed to ${_formatVehicleType(vehicleType)} ride notifications'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSubscriptions(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMenuAction(String action, DriverSubscription subscription) async {
    switch (action) {
      case 'pause':
        await _notificationService.updateSubscriptionStatus(subscription.id, false);
        _loadSubscriptions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription paused')),
          );
        }
        break;
        
      case 'resume':
        await _notificationService.updateSubscriptionStatus(subscription.id, true);
        _loadSubscriptions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription resumed')),
          );
        }
        break;
        
      case 'extend':
        _showExtendDialog(subscription);
        break;
        
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Subscription'),
            content: Text('Are you sure you want to delete the ${_formatVehicleType(subscription.vehicleType)} subscription?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        
        if (confirmed == true) {
          await _notificationService.deleteSubscription(subscription.id);
          _loadSubscriptions();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Subscription deleted')),
            );
          }
        }
        break;
    }
  }

  void _showExtendDialog(DriverSubscription subscription) {
    int extensionDays = 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Extend ${_formatVehicleType(subscription.vehicleType)} Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current expiry: ${_formatTime(subscription.expiresAt)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text(
                'Extend by: $extensionDays days',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Slider(
                value: extensionDays.toDouble(),
                min: 7,
                max: 365,
                divisions: 51,
                label: '$extensionDays days',
                onChanged: (value) {
                  setDialogState(() {
                    extensionDays = value.round();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _extendSubscription(subscription, extensionDays),
              child: const Text('Extend'),
            ),
          ],
        ),
      ),
    );
  }

  void _extendSubscription(DriverSubscription subscription, int extensionDays) async {
    Navigator.pop(context); // Close dialog

    try {
      await _notificationService.extendSubscription(subscription.id, extensionDays);
      _loadSubscriptions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription extended by $extensionDays days'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extending subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
