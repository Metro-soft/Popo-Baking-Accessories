import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PayslipGenerator {
  Future<void> generateAndPrint(
    Map<String, dynamic> item,
    String month, {
    bool isPreview = false,
  }) async {
    final pdf = pw.Document();

    // Load Fonts (using standard for now, can load custom later)
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    // Load Logo (Placeholder for now, or check assets)
    // final logo = await imageFromAssetBundle('assets/images/logo.png');

    final name = item['employee_name'] ?? 'Unknown';
    final role = item['employee_role'] ?? 'Staff';
    final id = 'EMP-${item['employee_id']}';
    final base = _fmt(item['base_salary']);
    final bonus = _fmt(item['bonuses']);
    final ded = _fmt(item['deductions']);
    final net = _fmt(item['net_pay']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Popo',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      pw.Text(
                        'Baking Accessories',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'PAYSLIP',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey400,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // --- EMPLOYEE CARD ---
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Employee Details',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$role • $id',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Period: $month',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),

              // --- EARNINGS & DEDUCTIONS ---
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // EARNINGS
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'EARNINGS',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey500,
                          ),
                        ),
                        pw.Divider(color: PdfColors.grey300),
                        _buildRow('Basic Salary', base),
                        _buildRow('Bonuses', bonus),
                        pw.SizedBox(height: 10),
                        pw.Divider(color: PdfColors.grey300),
                        _buildRow(
                          'Total Earnings',
                          _fmt(
                            (item['base_salary'] ?? 0) + (item['bonuses'] ?? 0),
                          ),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 30),
                  // DEDUCTIONS
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DEDUCTIONS',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey500,
                          ),
                        ),
                        pw.Divider(color: PdfColors.grey300),
                        _buildRow('Deductions', ded),
                        // Add more if we had detailed taxes
                        pw.SizedBox(height: 10),
                        pw.Divider(color: PdfColors.grey300),
                        _buildRow('Total Deductions', ded, isBold: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // --- NET PAY PILL ---
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                  borderRadius: pw.BorderRadius.circular(50),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'NET PAY',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.Text(
                      'KES $net',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Generated by Popo App',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400),
                ),
              ),
            ],
          );
        },
      ),
    );

    final safeName = name.replaceAll(RegExp(r'[^\w\s]+'), '');
    final fileName = 'Payslip_${safeName.replaceAll(' ', '_')}.pdf';
    final bytes = await pdf.save();

    if (Platform.isWindows) {
      // Windows: Explicit "Save As" Dialog
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Payslip',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
        // Optional: Open the file after saving
        // await Process.run('explorer', [outputFile]);
      }
    } else {
      // Mobile: Share/Print
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  pw.Widget _buildRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
          ),
          pw.Text(
            value,
            style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '0.00';
    return NumberFormat(
      '#,##0.00',
    ).format(double.tryParse(val.toString()) ?? 0);
  }
}
