/// User model representing authenticated user information.
class User {
  const User({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatar_url': avatarUrl,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? avatarUrl,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! User) return false;
    return id == other.id &&
        email == other.email &&
        username == other.username &&
        avatarUrl == other.avatarUrl;
  }

  @override
  int get hashCode => Object.hash(id, email, username, avatarUrl);
}
