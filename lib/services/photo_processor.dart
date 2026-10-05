import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Turns the picture picked on the information sheet into the two shapes the
/// app stores on the student row.
///
/// A student keeps two copies of their picture:
///
/// * the **compact** picture (`students.photo_base64`), drawn by every list,
///   header, form and avatar. It is re-encoded to [compactWidth] pixels here,
///   which is what keeps the registry lists small: they read this column and
///   nothing else, so opening a page costs a few kilobytes per student instead
///   of the megabytes the original photo weighs.
/// * the **original** picture (`students.photo_full_base64`), kept exactly as
///   the picker produced it and read only when the picture itself is wanted
///   (the backup file, and the optimise action). Nothing on screen needs it,
///   which is why the lists never load it.
///
/// The compact copy is encoded as PNG because the Flutter engine can encode
/// that without a third-party package. It is a deliberate trade: a PNG is
/// larger than the JPEG a photo editor would write, but it is still several
/// times smaller than the original and needs no extra dependency to produce.
class PhotoProcessor {
  const PhotoProcessor._();

  /// Width the compact picture is scaled to. A 56 px avatar box stays sharp on
  /// a 3x screen at this size, and the encoded text lands around 30-60 KB,
  /// which is what makes a registry of hundreds of students cheap to list.
  static const int compactWidth = 160;

  /// The compact copy of [bytes] as a PNG, or null when the engine could not
  /// decode them.
  ///
  /// Never throws: a picture the decoder rejects simply has no compact copy,
  /// and the caller keeps the original bytes instead of losing the photo.
  static Future<Uint8List?> compact(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    ui.Codec? codec;
    ui.Image? image;
    try {
      // The engine scales while decoding, so a full-size phone photo is never
      // materialised at full resolution just to be shrunk afterwards.
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: compactWidth,
        allowUpscaling: false,
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  /// The compact copy of [bytes] as the text stored in `students.photo_base64`.
  ///
  /// When the engine cannot decode [bytes] the original ones are encoded
  /// instead: a bigger stored picture is always better than a lost one.
  static Future<String> compactBase64(Uint8List bytes) async {
    if (bytes.isEmpty) return '';
    final small = await compact(bytes);
    return base64Encode(small ?? bytes);
  }
}
