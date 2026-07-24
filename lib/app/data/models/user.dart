import '../../core/config/env.dart';
import 'profile.dart';

class AppUser {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final String? avatarUrl;
  final Profile? employee;

  /// The signed-in user's tenant branding, for white-labelling the app.
  final String? tenantName;
  final String? tenantLogoUrl;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.avatarUrl,
    this.employee,
    this.tenantName,
    this.tenantLogoUrl,
  });

  /// Manager Self-Service access is driven by the employee record's
  /// `is_manager` flag (the API returns `roles: ["employee"]` for everyone,
  /// so role names can't be used here).
  bool get isManager => employee?.isManager ?? false;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'];

    return AppUser(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      avatarUrl: json['avatar_url'],
      employee: json['employee'] != null
          ? Profile.fromJson(Map<String, dynamic>.from(json['employee']))
          : null,
      tenantName: tenant is Map
          ? (tenant['company_name'] ?? tenant['name'])?.toString()
          : null,
      tenantLogoUrl: tenant is Map
          ? Env.resolveMedia(tenant['logo_url']?.toString())
          : null,
    );
  }
}
