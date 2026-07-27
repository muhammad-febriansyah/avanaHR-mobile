import 'dart:io';

import 'package:image/image.dart' as img;

/// Shrinks a picked photo before it is uploaded.
///
/// A modern phone camera produces 4–12 MB files that no feed needs: the wall
/// renders them a few hundred pixels wide. Compressing on the device saves the
/// employee's data, keeps uploads inside the server's 5 MB limit, and stops the
/// feed being slow to scroll on a weak connection.
class ImageCompressor {
    /// Longest edge of the stored image. 1600px still looks sharp full-screen
    /// on a phone while cutting a typical camera shot by an order of magnitude.
    static const int _maxEdge = 1600;

    static const int _quality = 82;

    /// Returns the path of a compressed copy, or the original path when the
    /// file cannot be decoded — a failure to shrink must never block a post.
    static Future<String> compress(String path) async {
        try {
            final file = File(path);
            final bytes = await file.readAsBytes();
            final decoded = img.decodeImage(bytes);

            if (decoded == null) {
                return path;
            }

            // bakeOrientation first: a portrait photo carries its rotation in
            // EXIF, and resizing without applying it yields a sideways image.
            var image = img.bakeOrientation(decoded);

            if (image.width > _maxEdge || image.height > _maxEdge) {
                image = image.width >= image.height
                    ? img.copyResize(image, width: _maxEdge)
                    : img.copyResize(image, height: _maxEdge);
            }

            final out = '${path}_compressed.jpg';
            await File(out).writeAsBytes(img.encodeJpg(image, quality: _quality));

            return out;
        } catch (_) {
            return path;
        }
    }
}
