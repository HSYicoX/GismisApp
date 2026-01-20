import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/domain/auth_providers.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/profile_providers.dart';

/// Profile page displaying user information and app settings.
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 9.5
/// - Display username, avatar, and basic account information
/// - Show login/register options when not authenticated
/// - Allow updating username and avatar
/// - Navigate to app preferences
/// - Logout clears session tokens
/// - Minimal, uncluttered design
/// - Shows offline banner when network is unavailable
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Offline banner
          if (isOffline) const OfflineBanner(),
          Expanded(
            child: authState.when(
              data: (state) {
                if (state == AuthState.authenticated) {
                  return _buildAuthenticatedContent();
                }
                return _buildUnauthenticatedContent();
              },
              loading: _buildLoadingContent,
              error: (_, __) => _buildUnauthenticatedContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        children: [
          // Avatar skeleton
          const SkeletonLoader(
            width: 100,
            height: 100,
            borderRadius: BorderRadius.all(Radius.circular(50)),
          ),
          AppSpacing.verticalMd,
          // Username skeleton
          const SkeletonLoader(width: 150, height: 24),
          AppSpacing.verticalSm,
          // Email skeleton
          const SkeletonLoader(width: 200, height: 16),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedContent() {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        children: [
          AppSpacing.verticalXxl,
          // Guest avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider, width: 2),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
          AppSpacing.verticalLg,
          Text(
            'Welcome to Gismis',
            style: AppTypography.headlineMedium,
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalSm,
          Text(
            'Sign in to track your anime and sync across devices',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalXl,
          // Login button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOlive,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
              ),
              child: Text(
                'Sign In',
                style: AppTypography.titleMedium.copyWith(color: Colors.white),
              ),
            ),
          ),
          AppSpacing.verticalMd,
          // Register button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.register),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentOlive,
                side: const BorderSide(color: AppColors.accentOlive),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: Text(
                'Create Account',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.accentOlive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedContent() {
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileNotifierProvider);

    return profileAsync.when(
      data: (user) {
        final displayUser = user ?? currentUser;
        if (displayUser == null) {
          return _buildUnauthenticatedContent();
        }
        return _buildProfileContent(displayUser);
      },
      loading: _buildLoadingContent,
      error: (error, _) => ErrorView(
        message: 'Failed to load profile',
        onRetry: () => ref.read(profileNotifierProvider.notifier).loadProfile(),
      ),
    );
  }

  Widget _buildProfileContent(User displayUser) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        children: [
          // Profile header
          _buildProfileHeader(displayUser),
          AppSpacing.verticalXl,
          // Menu items
          _buildMenuSection(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.accentOlive.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accentOlive.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: user.avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    user.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(user),
                  ),
                )
              : _buildAvatarPlaceholder(user),
        ),
        AppSpacing.verticalMd,
        // Username
        Text(
          user.username,
          style: AppTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        AppSpacing.verticalXs,
        // Email
        Text(
          user.email,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(User user) {
    final initial = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : '?';
    return Center(
      child: Text(
        initial,
        style: AppTypography.displayLarge.copyWith(
          color: AppColors.accentOlive,
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Favorites
          _buildMenuItem(
            icon: Icons.favorite_outline,
            title: 'My Favorites',
            subtitle: 'View your favorite anime collection',
            onTap: () => context.push(AppRoutes.favorites),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Edit Profile
          _buildMenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update your username and avatar',
            onTap: _showEditProfileDialog,
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Settings
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'App preferences and notifications',
            onTap: _showSettingsDialog,
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Logout
          _buildMenuItem(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            onTap: _handleLogout,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    final iconColor = isDestructive ? AppColors.error : AppColors.accentOlive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            AppSpacing.horizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(color: color),
                  ),
                  AppSpacing.verticalXs,
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final usernameController = TextEditingController(
      text: currentUser.username,
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text('Edit Profile', style: AppTypography.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.accentOlive),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUsername = usernameController.text.trim();
              if (newUsername.isNotEmpty &&
                  newUsername != currentUser.username) {
                await ref
                    .read(profileNotifierProvider.notifier)
                    .updateProfile(username: newUsername);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOlive,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text('Settings', style: AppTypography.headlineSmall),
        content: Text(
          'Settings page coming soon!',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.accentOlive,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text('Sign Out', style: AppTypography.headlineSmall),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      await ref.read(authServiceProvider).logout();
      ref.read(profileNotifierProvider.notifier).clear();
    }
  }
}
