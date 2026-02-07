import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/transport.dart';

/// Generuje malý PDF štítok pre prepravu
class TransportPdfService {
  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _formatPrice(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  /// Vráti PDF ako bajty pre malý štítok
  static Future<Uint8List> buildLabelPdf({
    required Transport transport,
  }) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    // Malý formát pre štítok (100x150mm alebo podobný)
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              // Hlavička
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'PREPRAVA',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 12),
              
              // Dátum
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Dátum:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _formatDate(transport.createdAt),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              
              // Trasa
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 8,
                          height: 8,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.green,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Expanded(
                          child: pw.Text(
                            transport.origin,
                            style: const pw.TextStyle(fontSize: 9),
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      margin: const pw.EdgeInsets.only(left: 3),
                      width: 2,
                      height: 8,
                      color: PdfColors.grey700,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 8,
                          height: 8,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.red,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Expanded(
                          child: pw.Text(
                            transport.destination,
                            style: const pw.TextStyle(fontSize: 9),
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              
              // Vzdialenosť
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Vzdialenosť:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${transport.distance.toStringAsFixed(2)} km${transport.isRoundTrip ? ' (tam aj späť)' : ''}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              
              // Cena za km
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Cena/km:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_formatPrice(transport.pricePerKm)} €',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              
              // Základná cena
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Základná cena:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_formatPrice(transport.baseCost)} €',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              
              // Náklady na palivo (ak sú)
              if (transport.fuelCost > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Palivo:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${_formatPrice(transport.fuelCost)} €',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
              
              pw.SizedBox(height: 8),
              
              // Celková cena
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.grey700, width: 1),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'CELKOM:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${_formatPrice(transport.totalCost)} €',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Poznámka (ak existuje)
              if (transport.notes != null && transport.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Poznámka:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        transport.notes!,
                        style: const pw.TextStyle(fontSize: 8),
                        maxLines: 3,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
