import '../../core/config/env.dart';

/// A mobile intro slide served by the web `/onboarding-slides` endpoint.
/// [imageUrl] may point to an SVG (vector) or a raster image.
class OnboardingSlide {
  final String title;
  final String subtitle;
  final String? imageUrl;

  const OnboardingSlide({
    required this.title,
    this.subtitle = '',
    this.imageUrl,
  });

  bool get isSvg => (imageUrl ?? '').toLowerCase().endsWith('.svg');

  factory OnboardingSlide.fromJson(Map<String, dynamic> json) {
    return OnboardingSlide(
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      imageUrl: Env.resolveMedia(json['image_url'] as String?),
    );
  }
}
