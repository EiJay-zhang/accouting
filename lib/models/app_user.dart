class AppUser {
  final int id;
  final String username;
  final String displayName;
  final String createdAt;
  final bool isAdmin;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.createdAt,
    this.isAdmin = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      displayName: json['display_name'] as String? ?? json['username'] as String,
      createdAt: json['created_at'] as String? ?? '',
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'created_at': createdAt,
      'is_admin': isAdmin,
    };
  }

  AppUser copyWith({String? displayName, bool? isAdmin}) {
    return AppUser(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
