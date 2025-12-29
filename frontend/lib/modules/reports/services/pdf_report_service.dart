import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfReportService {
  final currencyFormat = NumberFormat.currency(symbol: 'KES ');

  Future<Uint8List> generateLowStockReport(
    List<dynamic> data,
    String branchName,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader('Low Stock Report', branchName),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Product', 'SKU', 'Stock', 'Reorder Level', 'Status'],
              data: data.map((item) {
                final current =
                    double.tryParse(item['total_quantity'].toString()) ?? 0;
                final reorder =
                    double.tryParse(item['reorder_level'].toString()) ?? 10;
                final status = current <= (reorder * 0.5) ? 'CRITICAL' : 'LOW';

                return [
                  item['name'],
                  item['sku'],
                  item['total_quantity'].toString(),
                  item['reorder_level'].toString(),
                  status,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateAuditReport(
    List<dynamic> data,
    String branchName,
    String dateRange,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader('Audit Logs Report', branchName, subtitle: dateRange),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Date', 'Branch', 'Product', 'Type', 'Qty', 'Reason'],
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(100),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(40),
                5: const pw.FlexColumnWidth(),
              },
              data: data.map((item) {
                return [
                  DateFormat(
                    'MMM d, HH:mm',
                  ).format(DateTime.parse(item['created_at'])),
                  item['branch_name'] ?? '-',
                  item['product_name'] ?? '-',
                  item['type'].toString().toUpperCase(),
                  item['quantity'].toString(),
                  item['reason'] ?? '',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String title, String branchName, {String? subtitle}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Popo Baking Accessories',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(title, style: pw.TextStyle(fontSize: 18)),
        pw.Text('Branch: $branchName'),
        if (subtitle != null) pw.Text('Period: $subtitle'),
        pw.Text(
          'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        ),
        pw.Divider(),
      ],
    );
  }
}
