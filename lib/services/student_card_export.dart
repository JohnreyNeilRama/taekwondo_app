import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Turns a student's ID card into something a student can actually receive: a
/// shared picture, an image saved on the device, or a printable A4 sheet.
class StudentCardExport {
  const StudentCardExport._();

  /// Renders the widget wrapped by the `RepaintBoundary` that owns [key] to PNG
  /// bytes. A high [pixelRatio] keeps the QR code crisp when printed.
  static Future<Uint8List> capture(
    GlobalKey key, {
    double pixelRatio = 4,
  }) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('The ID card is not on screen.');
    }
    // In debug builds a boundary that has not painted yet cannot be captured.
    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not render the ID card.');
    return data.buffer.asUint8List();
  }

  /// A file name that is safe on every platform.
  static String safeName(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? 'student' : cleaned;
  }

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Opens the system share sheet with the card as a PNG, so it can go straight
  /// to Messenger, Viber, e-mail or a parent's phone.
  static Future<void> share(Uint8List png, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${safeName(name)}_id_card.png');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'TKD ID card: $name',
      ),
    );
  }

  /// Saves the card as an image. On a phone it goes to the gallery; on desktop
  /// it is written to the Downloads folder. Returns a message to show.
  static Future<String> saveImage(Uint8List png, String name) async {
    if (_isMobile) {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(png, album: 'TKD Records');
      return 'ID card saved to your gallery';
    }
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${safeName(name)}_id_card.png');
    await file.writeAsBytes(png, flush: true);
    return 'Saved to ${file.path}';
  }

  /// An A4 page of ID cards at their real printed size (85.6 x 54 mm), two
  /// columns by four rows, with thin guide lines to cut along.
  ///
  /// The same card is repeated [copies] times, so one sheet gives the student a
  /// spare for the bag, the wallet and the parents.
  static Future<Uint8List> buildSheet(Uint8List png, {int copies = 8}) async {
    final image = pw.MemoryImage(png);
    final cardWidth = 85.6 * PdfPageFormat.mm;
    final cardHeight = 54 * PdfPageFormat.mm;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          children: [
            pw.Text(
              'Cut along the lines',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 10),
            pw.Wrap(
              alignment: pw.WrapAlignment.center,
              children: [
                for (var i = 0; i < copies; i++)
                  pw.Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey500,
                        width: 0.4,
                      ),
                    ),
                    child: pw.Image(image, fit: pw.BoxFit.fill),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Opens the print preview with the ID card sheet. From there the sheet can
  /// also be printed, shared or saved as a PDF.
  static Future<void> printSheet(Uint8List png, String name) async {
    final pdf = await buildSheet(png);
    await Printing.layoutPdf(
      name: '${safeName(name)}_id_cards',
      onLayout: (_) async => pdf,
    );
  }
}
