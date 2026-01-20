import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/models/auth_result.dart';
import '../domain/auth_providers.dart';

/// Register page with email/username/password form.
///
/// Requirements: 7.1, 7.5
/// - Register with email, username, and password
/// - Handle duplicate email/username errors
/// - Validation errors displayed inline
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({
    super.key,
    this.onRegisterSuccess,
    this.onNavigateToLogin,
  });

  /// Callback when registration is successful.
  final VoidCallback? onRegisterSuccess;

  /// Callback to navigate to login page.
  final VoidCallback? onNavigateToLogin;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Clear previous error
    setState(() {
      _errorMessage = null;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.register(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        widget.onRegisterSuccess?.call();
      } else {
        // Handle specific errors for duplicate email/username
        final error = result.errorOrNull;
        setState(() {
          _errorMessage = _getErrorMessage(error);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(AuthError? error) {
    if (error == null) {
      return 'Registration failed. Please try again.';
    }
    switch (error) {
      case AuthError.emailTaken:
        return 'This email is already registered. Please use a different email or sign in.';
      case AuthError.usernameTaken:
        return 'This username is already taken. Please choose a different username.';
      case AuthError.networkError:
        return 'Network error. Please check your connection and try again.';
      default:
        return error.message;
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.trim().length > 20) {
      return 'Username must be less than 20 characters';
    }
    // Only allow alphanumeric and underscores
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSpacing.verticalLg,
                // Header
                _buildHeader(),
                AppSpacing.verticalXl,
                // Error message
                if (_errorMessage != null) ...[
                  _buildErrorBanner(),
                  AppSpacing.verticalMd,
                ],
                // Email field
                _buildEmailField(),
                AppSpacing.verticalMd,
                // Username field
                _buildUsernameField(),
                AppSpacing.verticalMd,
                // Password field
                _buildPasswordField(),
                AppSpacing.verticalMd,
                // Confirm password field
                _buildConfirmPasswordField(),
                AppSpacing.verticalLg,
                // Register button
                _buildRegisterButton(),
                AppSpacing.verticalMd,
                // Login link
                _buildLoginLink(),
                AppSpacing.verticalLg,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App logo placeholder
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.accentSky.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: const Icon(
            Icons.person_add_outlined,
            size: 40,
            color: AppColors.accentSky,
          ),
        ),
        AppSpacing.verticalLg,
        Text(
          'Create Account',
          style: AppTypography.displaySmall,
          textAlign: TextAlign.center,
        ),
        AppSpacing.verticalSm,
        Text(
          'Join us to start tracking your favorite anime',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          AppSpacing.horizontalSm,
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Email', style: AppTypography.labelLarge),
        AppSpacing.verticalSm,
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: !_isLoading,
          validator: _validateEmail,
          decoration: _inputDecoration(
            hintText: 'Enter your email',
            prefixIcon: Icons.email_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Username', style: AppTypography.labelLarge),
        AppSpacing.verticalSm,
        TextFormField(
          controller: _usernameController,
          keyboardType: TextInputType.text,
          autocorrect: false,
          enabled: !_isLoading,
          validator: _validateUsername,
          decoration: _inputDecoration(
            hintText: 'Choose a username',
            prefixIcon: Icons.person_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Password', style: AppTypography.labelLarge),
        AppSpacing.verticalSm,
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !_isLoading,
          validator: _validatePassword,
          decoration: _inputDecoration(
            hintText: 'Create a password (min. 8 characters)',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textTertiary,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirm Password', style: AppTypography.labelLarge),
        AppSpacing.verticalSm,
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          enabled: !_isLoading,
          validator: _validateConfirmPassword,
          decoration: _inputDecoration(
            hintText: 'Confirm your password',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: AppColors.textTertiary,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentSky,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accentSky.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Create Account',
                style: AppTypography.titleMedium.copyWith(color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : widget.onNavigateToLogin,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Sign In',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.accentSky,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textTertiary,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.textTertiary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.accentSky, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.error),
    );
  }
}
