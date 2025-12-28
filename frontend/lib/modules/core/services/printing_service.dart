import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../inventory/models/product_model.dart';

class PrintingService {
  Future<void> printProductLabel(Product product) async {
    final doc = pw.Document();

    // Define a standard label size (e.g., 50mm x 30mm)
    // 1mm = 2.835 points (approx)
    const PdfPageFormat labelFormat = PdfPageFormat(
      50 * PdfPageFormat.mm,
      30 * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: labelFormat,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Product Name (Truncated/Fit)
              pw.Text(
                product.name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),

              // Barcode
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: product.sku,
                width: 40 * PdfPageFormat.mm,
                height: 10 * PdfPageFormat.mm,
                drawText: true,
                textStyle: pw.TextStyle(fontSize: 6),
              ),
              pw.SizedBox(height: 2),

              // Price
              pw.Text(
                'KES ${product.baseSellingPrice.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Label_${product.sku}',
    );
  }
}
