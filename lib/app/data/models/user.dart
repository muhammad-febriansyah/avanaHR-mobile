import 'profile.dart';

class AppUser {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final String? avatarUrl;
  final Profile? employee;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.avatarUrl,
    this.employee,
  });

  /// Manager Self-Service access is driven by the employee record's
  /// `is_manager` flag (the API returns `roles: ["employee"]` for everyone,
  /// so role names can't be used here).
  bool get isManager => employee?.isManager ?? false;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'],
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
    avatarUrl: json['avatar_url'],
    employee: json['employee'] != null
        ? Profile.fromJson(Map<String, dynamic>.from(json['employee']))
        : null,
  );
}
