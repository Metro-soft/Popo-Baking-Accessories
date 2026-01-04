import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/sales_provider.dart'; // Ensure correct import path for InvoiceDraft

class ReceiptService {
  /// Generates and prints a thermal receipt for the given [draft].
  /// [amountTendered] and [change] are passed explicitly to ensure what's printed
  /// matches the final transaction state.
  static Future<void> printReceipt({
    required InvoiceDraft draft,
    required double amountTendered,
    required double change,
    required String cashierName, // For "Served By"
  }) async {
    final doc = pw.Document();

    // Define 80mm roll width. Height is infinite (continuous roll).
    // 80mm is approx 226 points (1mm = 2.83pt).
    // We'll use a standard roll width but dynamic height.
    final pageFormat = PdfPageFormat.roll80;

    // Standard thermal receipt font (Helvetica/Arial style)
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. HEADER
              pw.Center(
                child: pw.Text(
                  'POPO BAKING ACCESSORIES',
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Thika, Kenya',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Tel: +254 7XX XXX XXX',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${DateTime.now().toString().substring(0, 16)}',
                    style: pw.TextStyle(font: font, fontSize: 9),
                  ),
                  pw.Text(
                    '#${draft.id.substring(0, 6).toUpperCase()}',
                    style: pw.TextStyle(font: fontBold, fontSize: 9),
                  ),
                ],
              ),
              pw.Text(
                'Cashier: $cashierName',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              if (draft.customer != null)
                pw.Text(
                  'Customer: ${draft.customer!['name']}',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),

              pw.Divider(),

              // 2. ITEMS
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Item
                  1: const pw.FlexColumnWidth(0.5), // Qty
                  2: const pw.FlexColumnWidth(1), // Total
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text(
                        'Item',
                        style: pw.TextStyle(font: fontBold, fontSize: 9),
                      ),
                      pw.Text(
                        'Qty',
                        style: pw.TextStyle(font: fontBold, fontSize: 9),
                      ),
                      pw.Text(
                        'Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: fontBold, fontSize: 9),
                      ),
                    ],
                  ),
                  ...draft.items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            item.product.name,
                            maxLines: 2,
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            item.quantity.toString(),
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            item.total.toStringAsFixed(2),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(),

              // 3. FOOTER TOTALS
              _buildRow('Subtotal', draft.subtotal, font),
              if (draft.discountRate > 0)
                _buildRow(
                  'Discount (${draft.discountRate}%)',
                  -draft.calculateDiscount,
                  font,
                ),
              if (draft.taxRate > 0)
                _buildRow('Tax (${draft.taxRate}%)', draft.calculateTax, font),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(font: fontBold, fontSize: 14),
                    ),
                    pw.Text(
                      'KES ${draft.totalPayable.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 14),
                    ),
                  ],
                ),
              ),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              _buildRow('Paid (${draft.paymentMode})', amountTendered, font),
              _buildRow(
                draft.depositChange ? 'Deposited to Wallet' : 'Change',
                change,
                fontBold,
              ),

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with us!',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 20), // Bottom margin for tear-off
            ],
          );
        },
      ),
    );

    // Print to connected printer (or show preview)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${draft.id}',
    );
  }

  static pw.Widget _buildRow(String label, double value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9)),
          pw.Text(
            value.toStringAsFixed(2),
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
