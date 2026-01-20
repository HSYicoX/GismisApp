import 'auth_tokens.dart';
import 'user.dart';

/// AuthError enum representing possible authentication errors.
enum AuthError {
  invalidCredentials('invalid_credentials'),
  emailTaken('email_taken'),
  usernameTaken('username_taken'),
  networkError('network_error'),
  unknown('unknown');

  final String value;
  const AuthError(this.value);

  static AuthError fromString(String value) {
    return AuthError.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AuthError.unknown,
    );
  }

  /// Get a user-friendly error message.
  String get message {
    switch (this) {
      case AuthError.invalidCredentials:
        return 'Invalid email or password';
      case AuthError.emailTaken:
        return 'Email is already registered';
      case AuthError.usernameTaken:
        return 'Username is already taken';
      case AuthError.networkError:
        return 'Network error. Please try again.';
      case AuthError.unknown:
        return 'An unexpected error occurred';
    }
  }
}

/// Sealed class representing authentication result.
sealed class AuthResult {
  const AuthResult();

  factory AuthResult.success(AuthTokens tokens, User user) = AuthSuccess;
  factory AuthResult.failure(AuthError error) = AuthFailure;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('error')) {
      return AuthFailure(AuthError.fromString(json['error'] as String));
    }
    return AuthSuccess(
      AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
      User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson();

  /// Check if the result is successful.
  bool get isSuccess => this is AuthSuccess;

  /// Check if the result is a failure.
  bool get isFailure => this is AuthFailure;

  /// Get the tokens if successful, null otherwise.
  AuthTokens? get tokensOrNull =>
      this is AuthSuccess ? (this as AuthSuccess).tokens : null;

  /// Get the user if successful, null otherwise.
  User? get userOrNull =>
      this is AuthSuccess ? (this as AuthSuccess).user : null;

  /// Get the error if failed, null otherwise.
  AuthError? get errorOrNull =>
      this is AuthFailure ? (this as AuthFailure).error : null;
}

/// Successful authentication result.
class AuthSuccess extends AuthResult {
  const AuthSuccess(this.tokens, this.user);
  final AuthTokens tokens;
  final User user;

  @override
  Map<String, dynamic> toJson() {
    return {'tokens': tokens.toJson(), 'user': user.toJson()};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AuthSuccess) return false;
    return tokens == other.tokens && user == other.user;
  }

  @override
  int get hashCode => Object.hash(tokens, user);
}

/// Failed authentication result.
class AuthFailure extends AuthResult {
  const AuthFailure(this.error);
  final AuthError error;

  @override
  Map<String, dynamic> toJson() {
    return {'error': error.value};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AuthFailure) return false;
    return error == other.error;
  }

  @override
  int get hashCode => error.hashCode;
}
