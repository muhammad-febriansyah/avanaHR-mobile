import '../../core/config/env.dart';
import 'profile.dart';

/// One Menu Cepat shortcut, as the web Hak Akses screen defines it.
///
/// The tiles used to be a hard-coded list in [HomeTab]; hiding one from a role
/// meant shipping a new build. They now arrive with `/auth/me`, already
/// filtered for this account and in the order the admin arranged.
class MenuTile {
  final String key;
  final String label;

  /// Iconsax name, e.g. `sun_1`. Resolved against a lookup in the home tab, so
  /// an icon this build does not know simply falls back rather than crashing.
  final String icon;

  /// Tile colour as `#RRGGBB`.
  final String color;

  /// GetX route the tile opens, e.g. `/leave`.
  final String route;

  MenuTile({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });

  factory MenuTile.fromJson(Map<String, dynamic> json) => MenuTile(
    key: json['key']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
    color: json['color']?.toString() ?? '#2F54C9',
    route: json['route']?.toString() ?? '',
  );
}

class AppUser {
  final int id;
  final int? tenantId;
  final String name;
  final String email;
  final List<String> roles;
  final String? avatarUrl;
  final Profile? employee;

  /// Menu Cepat for this account. Empty when the server did not send one —
  /// an older backend — in which case the home tab keeps its built-in list.
  final List<MenuTile> menu;

  /// The bottom navigation bar for this account, already filtered by tenant
  /// feature and role. Empty on an older backend, where [MainView] falls back
  /// to the five tabs this build ships with.
  final List<MenuTile> tabs;

  /// The signed-in user's tenant branding, for white-labelling the app.
  /// [tenantName] is the legal name ("PT Avanah Digital Teknologi") and
  /// [tenantBrandName] the short brand ("avanahR") shown above it.
  final String? tenantName;
  final String? tenantBrandName;
  final String? tenantLogoUrl;

  /// The tenant's accent colour (hex) from the web "Tampilan & Tema" theme,
  /// used as the app's brand/primary colour.
  final String? tenantAccentHex;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.menu = const [],
    this.tabs = const [],
    this.avatarUrl,
    this.employee,
    this.tenantName,
    this.tenantBrandName,
    this.tenantLogoUrl,
    this.tenantAccentHex,
    this.tenantId,
  });

  /// Manager Self-Service access is driven by the employee record's
  /// `is_manager` flag (the API returns `roles: ["employee"]` for everyone,
  /// so role names can't be used here).
  bool get isManager => employee?.isManager ?? false;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'];

    return AppUser(
      id: json['id'],
      tenantId: tenant is Map ? (tenant['id'] as num?)?.toInt() : null,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      menu:
          (json['menu'] as List?)
              ?.map((e) => MenuTile.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      tabs:
          (json['tabs'] as List?)
              ?.map((e) => MenuTile.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      avatarUrl: json['avatar_url'],
      employee: json['employee'] != null
          ? Profile.fromJson(Map<String, dynamic>.from(json['employee']))
          : null,
      tenantName: tenant is Map
          ? (tenant['company_name'] ?? tenant['name'])?.toString()
          : null,
      tenantBrandName: tenant is Map ? tenant['name']?.toString() : null,
      tenantLogoUrl: tenant is Map
          ? Env.resolveMedia(tenant['logo_url']?.toString())
          : null,
      tenantAccentHex: tenant is Map && tenant['theme'] is Map
          ? tenant['theme']['sidebar_accent']?.toString()
          : null,
    );
  }
}
