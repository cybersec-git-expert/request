import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

class GlassBottomNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final int? badgeCount;

  const GlassBottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badgeCount,
  });
}

/// A glass-styled bottom navigation bar with a center notch for a floating
/// action button, matching the provided design reference.
class GlassBottomNavBar extends StatelessWidget {
  final List<GlassBottomNavItem> leftItems;
  final List<GlassBottomNavItem> rightItems;
  // Optional single list mode: renders a uniform row with all items evenly spaced
  final List<GlassBottomNavItem>? items;
  final double height;
  final EdgeInsetsGeometry margin;
  // Center action (e.g., a big + button) shown when using left/right mode
  final IconData? centerIcon;
  final VoidCallback? onCenterTap;
  final Color? centerBackgroundColor;
  final Color? centerIconColor;
  final double centerSize;

  const GlassBottomNavBar({
    super.key,
    this.leftItems = const [],
    this.rightItems = const [],
    this.items,
    this.height = 64,
    this.margin = const EdgeInsets.fromLTRB(0, 0, 0, 0),
    this.centerIcon,
    this.onCenterTap,
    this.centerBackgroundColor,
    this.centerIconColor,
    this.centerSize = 52,
  });

  @override
  Widget build(BuildContext context) {
    final useUniformItems = items != null && items!.isNotEmpty;
    return SafeArea(
      top: false,
      bottom: true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            margin: margin,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: useUniformItems
                  ? BorderRadius.circular(24)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: useUniformItems
                  ? BorderRadius.circular(24)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              child: BottomAppBar(
                color: Colors.transparent,
                elevation: 0,
                shape: null,
                notchMargin: 0,
                child: SizedBox(
                  height: height,
                  child: useUniformItems
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (int i = 0; i < items!.length; i++)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: i == 0 || i == items!.length - 1
                                        ? 12
                                        : 10),
                                child: _NavButton(
                                  item: items![i],
                                  hideSelectedIcon: false,
                                ),
                              ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _NavItems(
                                items: leftItems, hideSelectedIcon: false),
                            SizedBox(
                                width: centerIcon != null ? centerSize : 0),
                            _NavItems(
                                items: rightItems,
                                alignEnd: true,
                                hideSelectedIcon: false),
                          ],
                        ),
                ),
              ),
            ),
          ),
          if (!useUniformItems && centerIcon != null)
            Positioned(
              bottom: height - (centerSize / 2) - 4,
              child: _CenterActionButton(
                size: centerSize - 6,
                backgroundColor:
                    centerBackgroundColor ?? Colors.black.withOpacity(0.85),
                iconColor: centerIconColor ?? Colors.white,
                icon: centerIcon!,
                onTap: onCenterTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItems extends StatelessWidget {
  final List<GlassBottomNavItem> items;
  final bool alignEnd;
  final bool hideSelectedIcon;
  const _NavItems({
    required this.items,
    this.alignEnd = false,
    this.hideSelectedIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(
                left: alignEnd || i > 0 ? 12 : 8,
                right: alignEnd && i == items.length - 1 ? 12 : 0,
              ),
              child: _NavButton(
                item: items[i],
                hideSelectedIcon: hideSelectedIcon,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassBottomNavItem item;
  final bool hideSelectedIcon;
  const _NavButton({required this.item, this.hideSelectedIcon = false});

  @override
  Widget build(BuildContext context) {
    final color = item.selected
        ? GlassTheme.colors.textPrimary
        : GlassTheme.colors.textSecondary;
    final icon = Icon(item.icon, size: 26, color: color);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item.onTap,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // In legacy left/right mode we hide the selected icon (center circle shows it).
                  // In uniform mode we always show it.
                  if (hideSelectedIcon)
                    Opacity(opacity: item.selected ? 0.0 : 1.0, child: icon)
                  else
                    icon,
                  if (item.badgeCount != null && item.badgeCount! > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: GlassTheme.colors.primaryRose,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  color: color,
                  fontWeight: item.selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A center button styled to sit in the bottom bar's notch and stand out.
class GlassCenterFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  const GlassCenterFab({
    super.key,
    required this.icon,
    required this.onTap,
    this.selected = true,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = GlassTheme.colors.textPrimary.withOpacity(0.08);
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ringColor,
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          // Inner circle button
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 54,
                height: 54,
                child: Icon(
                  icon,
                  size: 26,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  final VoidCallback? onTap;
  const _CenterActionButton({
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: size * 0.44),
        ),
      ),
    );
  }
}

/// Quick usage:
///
/// Scaffold(
///   floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
///   floatingActionButton: GlassCenterFab(icon: Icons.bookmark_border, onTap: () {}),
///   bottomNavigationBar: GlassBottomNavBar(
///     leftItems: [
///       GlassBottomNavItem(icon: Icons.person_outline, label: 'Profile', onTap: () {}),
///     ],
///     rightItems: [
///       GlassBottomNavItem(icon: Icons.add, label: 'Add', onTap: () {}),
///     ],
///   ),
///   body: ...,
/// )
