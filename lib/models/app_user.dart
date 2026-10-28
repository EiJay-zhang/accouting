class AppUser {
  final int id;
  final String username;
  final String displayName;
  final String createdAt;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      displayName: json['display_name'] as String? ?? json['username'] as String,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'created_at': createdAt,
    };
  }

  AppUser copyWith({String? displayName}) {
    return AppUser(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
    );
  }
}
