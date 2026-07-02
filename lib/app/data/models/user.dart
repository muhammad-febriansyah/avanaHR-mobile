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

  bool get isManager => roles.contains('manager') || roles.contains('hr-admin');

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
