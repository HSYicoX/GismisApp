import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_animations.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';

/// Main shell widget with bottom navigation bar.
///
/// This widget wraps the main content pages (Home, Schedule, AI, Profile)
/// and provides a consistent bottom navigation experience.
///
/// Requirements: 8.3, 8.4
/// - Magazine-like layouts with generous spacing
/// - Smooth page transitions with gentle easing
class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  /// The child widget to display in the shell.
  final Widget child;

  /// Navigation items configuration.
  static const _navItems = [
    _NavItem(
      path: AppRoutes.home,
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      path: AppRoutes.schedule,
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Schedule',
    ),
    _NavItem(
      path: AppRoutes.ai,
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      label: 'AI',
    ),
    _NavItem(
      path: AppRoutes.profile,
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _ArtisticBottomNav(
        currentPath: GoRouterState.of(context).matchedLocation,
        items: _navItems,
        onItemTapped: (path) => context.go(path),
      ),
    );
  }
}

/// Navigation item data class.
class _NavItem {
  const _NavItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Artistic bottom navigation bar with magazine-like styling.
class _ArtisticBottomNav extends StatelessWidget {
  const _ArtisticBottomNav({
    required this.currentPath,
    required this.items,
    required this.onItemTapped,
  });
  final String currentPath;
  final List<_NavItem> items;
  final ValueChanged<String> onItemTapped;

  int get _currentIndex {
    final index = items.indexWhere((item) => item.path == currentPath);
    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == _currentIndex;

              return _NavItemWidget(
                item: item,
                isSelected: isSelected,
                onTap: () => onItemTapped(item.path),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Individual navigation item widget with animation.
class _NavItemWidget extends StatelessWidget {
  const _NavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: AppAnimations.defaultCurve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentOlive.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppAnimations.fast,
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey(isSelected),
                size: 24,
                color: isSelected
                    ? AppColors.accentOlive
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppAnimations.fast,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.accentOlive
                    : AppColors.textTertiary,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
