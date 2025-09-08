import 'package:flutter/material.dart';

class ComingSoonWidget extends StatelessWidget {
  final String title;
  final String description;
  final IconData? icon;
  final bool showBackButton;
  final VoidCallback? onBack;

  const ComingSoonWidget({
    Key? key,
    required this.title,
    required this.description,
    this.icon,
    this.showBackButton = true,
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBackButton
          ? AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Icons.construction,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Feature title
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Info container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This feature is not available in your region yet. We\'re working hard to bring it to you soon!',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple coming soon card widget for use in lists or grids
class ComingSoonCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData? icon;
  final VoidCallback? onTap;

  const ComingSoonCard({
    Key? key,
    required this.title,
    required this.description,
    this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon ?? Icons.construction,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A disabled button with coming soon message
class ComingSoonButton extends StatelessWidget {
  final String text;
  final String comingSoonMessage;
  final IconData? icon;

  const ComingSoonButton({
    Key? key,
    required this.text,
    required this.comingSoonMessage,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: comingSoonMessage,
      child: ElevatedButton.icon(
        onPressed: null, // Disabled
        icon: Icon(icon ?? Icons.construction),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.grey[600],
        ),
      ),
    );
  }
}

/// A list tile with coming soon indicator
class ComingSoonListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? leadingIcon;
  final VoidCallback? onTap;

  const ComingSoonListTile({
    Key? key,
    required this.title,
    required this.subtitle,
    this.leadingIcon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        leadingIcon ?? Icons.construction,
        color: Colors.grey[400],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[500],
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Coming Soon',
          style: TextStyle(
            color: Colors.orange[800],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title is coming soon to your region!'),
                backgroundColor: Colors.orange,
              ),
            );
          },
    );
  }
}
