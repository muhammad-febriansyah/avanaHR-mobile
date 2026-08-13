import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Post-processes an attendance selfie: un-mirrors the front-camera shot and
/// burns a watermark (company logo + employee, timestamp, coordinates) onto the
/// bottom — the way a typical field-attendance photo looks. Fails soft: returns
/// the original path when anything goes wrong so clock-in never breaks.
class SelfieStamp {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Maximum logo height inside the watermark bar, preserving aspect ratio.
  static const _logoMaxHeight = 52;

  /// Returns the path to a new stamped JPEG, or [path] unchanged on failure.
  static Future<String> apply({
    required String path,
    String? company,
    String? subtitle,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? at,
    bool mirror = true,
    String? logoUrl,
  }) async {
    try {
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) {
        return path;
      }

      var image = img.bakeOrientation(decoded);
      if (mirror) {
        image = img.flipHorizontal(image);
      }

      img.Image? logo;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        logo = await _downloadLogo(logoUrl);
      }

      // The logo stands in for the company name, so keep the text line only
      // when no logo could be loaded.
      final lines = <String>[
        if (logo == null && company != null && company.trim().isNotEmpty)
          company.trim(),
        if (subtitle != null && subtitle.trim().isNotEmpty) subtitle.trim(),
        _formatTime(at ?? DateTime.now()),
        if (address != null && address.trim().isNotEmpty) address.trim(),
        if (latitude != null && longitude != null)
          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      ];
      _drawWatermark(image, lines, logo: logo);

      final out = '${path}_stamped.jpg';
      await File(out).writeAsBytes(img.encodeJpg(image, quality: 88));

      return out;
    } catch (e, st) {
      debugPrint('[SelfieStamp] failed, using original: $e\n$st');

      return path;
    }
  }

  static Future<img.Image?> _downloadLogo(String url) async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) return null;

        final bytes = await response.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );

        return img.decodeImage(Uint8List.fromList(bytes));
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[SelfieStamp] logo download failed: $e');
      return null;
    }
  }

  static void _drawWatermark(img.Image image, List<String> lines, {img.Image? logo}) {
    if (lines.isEmpty && logo == null) {
      return;
    }

    final font = image.width >= 520 ? img.arial24 : img.arial14;
    final lineHeight = font.lineHeight + 4;
    final padding = (image.width * 0.03).round().clamp(10, 28);
    final lineCount = lines.length;

    // The logo sits on its own row above the text, where the company name
    // would otherwise be.
    var logoW = 0;
    var logoH = 0;
    if (logo != null) {
      logoH = _logoMaxHeight;
      logoW = (logoH * logo.width / logo.height).round();
      final maxW = (image.width * 0.45).round();
      if (logoW > maxW) {
        logoW = maxW;
        logoH = (logoW * logo.height / logo.width).round();
      }
    }

    final logoBlock = logo != null ? logoH + (lineCount > 0 ? padding ~/ 2 : 0) : 0;
    final blockHeight =
        logoBlock + (lineCount > 0 ? lineCount * lineHeight : 0) + padding * 2;
    final top = image.height - blockHeight;

    img.fillRect(
      image,
      x1: 0,
      y1: top,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(0, 0, 0, 140),
    );

    final xCursor = padding;
    var yCursor = top + padding;

    if (logo != null) {
      img.compositeImage(
        image,
        img.copyResize(logo, width: logoW, height: logoH),
        dstX: xCursor,
        dstY: yCursor,
      );
      yCursor += logoBlock;
    }

    if (lineCount > 0) {
      var y = yCursor;
      for (final line in lines) {
        img.drawString(
          image,
          line,
          font: font,
          x: xCursor + 1,
          y: y + 1,
          color: img.ColorRgba8(0, 0, 0, 200),
        );
        img.drawString(
          image,
          line,
          font: font,
          x: xCursor,
          y: y,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        y += lineHeight;
      }
    }
  }

  static String _formatTime(DateTime dt) {
    final d = dt.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');

    return '${d.day} ${_months[d.month - 1]} ${d.year} · $hh:$mm';
  }
}
