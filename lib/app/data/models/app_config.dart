class AppConfig {
  final String siteName;
  final String tagline;
  final String? logoUrl;
  final String? faviconUrl;
  final String? contactEmail;
  final String? contactPhone;

  const AppConfig({
    this.siteName = 'AvanaHR',
    this.tagline = 'Advancing People, Empowering Growth',
    this.logoUrl,
    this.faviconUrl,
    this.contactEmail,
    this.contactPhone,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'] is Map ? json['contact'] as Map : const {};
    return AppConfig(
      siteName: (json['site_name'] ?? 'AvanaHR').toString(),
      tagline: (json['tagline'] ?? 'Advancing People, Empowering Growth').toString(),
      logoUrl: json['logo_url'],
      faviconUrl: json['favicon_url'],
      contactEmail: contact['email'],
      contactPhone: contact['phone'],
    );
  }
}
