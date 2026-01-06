import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../services/receipt_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool useThermal;
  final double? currentBalance;

  const PdfPreviewScreen({
    super.key,
    required this.transaction,
    required this.useThermal,
    this.currentBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(useThermal ? 'Thermal Receipt Preview' : 'Invoice Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () => _printReceipt(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () => _downloadReceipt(context),
          ),
        ],
      ),
      body: PdfPreview(
        maxPageWidth: useThermal ? 300 : 700,
        build: (format) => _generatePdf(format),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false, // User selected format already
        canDebug: false,
        actions: const [], // Hide default toolbar actions
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      final doc = await _generateDoc();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Invoice_${transaction['id']}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    }
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    try {
      final doc = await _generateDoc();
      final bytes = await doc.save();
      String? outputPath;

      if (Platform.isWindows) {
        final fileName = 'Invoice_${transaction['id']}.pdf';
        // PowerShell script to open Save File Dialog
        final psScript =
            '''
Add-Type -AssemblyName System.Windows.Forms
\$SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
\$SaveFileDialog.Filter = "PDF Files (*.pdf)|*.pdf"
\$SaveFileDialog.FileName = "$fileName"
\$SaveFileDialog.Title = "Save Invoice PDF"
if (\$SaveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$SaveFileDialog.FileName
}
''';
        final result = await Process.run('powershell', ['-Command', psScript]);
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) {
          outputPath = path;
        }
      } else {
        // Fallback for non-Windows: Auto-save to Documents
        final outputDir = await getApplicationDocumentsDirectory();
        outputPath = '${outputDir.path}/Invoice_${transaction['id']}.pdf';
      }

      if (outputPath == null || outputPath.isEmpty) {
        // User canceled or failed to pick path
        return;
      }

      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', file.path]);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved to $outputPath')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  Future<pw.Document> _generateDoc() async {
    final items = (transaction['items'] as List)
        .map(
          (i) => {
            'name': i['product_name'],
            'quantity': double.tryParse(i['quantity'].toString()) ?? 0,
            'total': double.tryParse(i['subtotal'].toString()) ?? 0,
            'unit_price':
                double.tryParse(i['unit_price']?.toString() ?? '0') ?? 0,
          },
        )
        .toList();

    final totalAmount =
        double.tryParse(transaction['total_amount'].toString()) ?? 0;
    final discount =
        double.tryParse(transaction['discount_amount']?.toString() ?? '0') ?? 0;
    final amountPaid =
        double.tryParse(transaction['total_paid']?.toString() ?? '0') ?? 0;

    String paymentMode = 'N/A';
    if (transaction['payments'] != null &&
        (transaction['payments'] as List).isNotEmpty) {
      paymentMode = (transaction['payments'] as List)
          .map((p) => p['method'].toString())
          .toSet()
          .join(', ');
    } else if (amountPaid >= totalAmount) {
      paymentMode = 'Cash';
    } else if (amountPaid == 0) {
      paymentMode = 'Unpaid';
    }

    return useThermal
        ? await ReceiptService.generateThermalPdf(
            id: transaction['id'].toString(),
            date: DateTime.parse(transaction['created_at']),
            customerName: transaction['customer_name'] ?? 'Walk-in',
            items: items,
            subtotal: totalAmount + discount,
            discount: discount,
            totalPayable: totalAmount,
            amountPaid: amountPaid,
            change: 0,
            paymentMode: paymentMode,
            depositChange: false,
            cashierName: 'Admin',
            isReprint: true,
            currentBalance: currentBalance,
          )
        : await ReceiptService.generateA4Pdf(
            id: transaction['id'].toString(),
            date: DateTime.parse(transaction['created_at']),
            customerName: transaction['customer_name'] ?? 'Walk-in',
            customerPhone: transaction['customer_phone'] ?? '',
            items: items,
            subtotal: totalAmount + discount,
            discount: discount,
            totalPayable: totalAmount,
            amountPaid: amountPaid,
            change: 0,
            paymentMode: paymentMode,
            cashierName: 'Admin',
            isReprint: true,
            currentBalance: currentBalance,
          );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = await _generateDoc();
    return doc.save();
  }
}
