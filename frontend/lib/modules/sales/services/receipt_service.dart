import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/sales_provider.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/settings_service.dart';

class ReceiptService {
  /// Generates and prints a thermal receipt for the given [draft].
  static Future<void> printReceipt({
    required InvoiceDraft draft,
    required double amountTendered,
    required double change,
    required String cashierName,
    bool useThermal = true,
    double? currentBalance,
    Map<String, String>? settings,
  }) async {
    final pdf = useThermal
        ? await generateThermalPdf(
            id: draft.id,
            date: DateTime.now(),
            customerName: draft.customer?['name'],
            items: draft.items
                .map(
                  (i) => {
                    'name': i.product.name,
                    'quantity': i.quantity,
                    'total': i.total,
                    'unit_price': i.unitPrice,
                  },
                )
                .toList(),
            subtotal: draft.subtotal,
            discount: draft.calculateDiscount,
            totalPayable: draft.totalPayable,
            amountPaid: amountTendered,
            change: change,
            paymentMode: draft.paymentMode,
            depositChange: draft.depositChange,
            cashierName: cashierName,
            currentBalance: currentBalance,
            settings: settings,
          )
        : await generateA4Pdf(
            id: draft.id,
            date: DateTime.now(),
            customerName: draft.customer?['name'],
            customerPhone: draft.customer?['phone'],
            items: draft.items
                .map(
                  (i) => {
                    'name': i.product.name,
                    'quantity': i.quantity,
                    'total': i.total,
                    'unit_price': i.unitPrice,
                  },
                )
                .toList(),
            subtotal: draft.subtotal,
            discount: draft.calculateDiscount,
            totalPayable: draft.totalPayable,
            amountPaid: amountTendered,
            change: change,
            cashierName: cashierName,
            paymentMode: draft.paymentMode,
            currentBalance: currentBalance,
            settings: settings,
          );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${draft.id}',
    );
  }

  static Future<void> printTransaction(
    Map<String, dynamic> transaction, {
    bool useThermal = true,
    double? currentBalance,
    Map<String, String>? settings,
  }) async {
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

    final pdf = useThermal
        ? await generateThermalPdf(
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
            settings: settings,
          )
        : await generateA4Pdf(
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
            settings: settings,
          );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${transaction['id']}',
    );
  }

  static Future<void> shareTransaction(
    Map<String, dynamic> transaction, {
    double? currentBalance,
    Map<String, String>? settings,
  }) async {
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

    final doc = await generateA4Pdf(
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
      settings: settings,
    );

    if (Platform.isWindows) {
      final outputDir = await getApplicationDocumentsDirectory();
      final file = File('${outputDir.path}/Invoice_${transaction['id']}.pdf');
      await file.writeAsBytes(await doc.save());

      await Process.run('explorer.exe', ['/select,', file.path]);

      final name = transaction['customer_name'] ?? 'Customer';
      final message = Uri.encodeComponent(
        'Hello $name, here is your invoice #${transaction['id']} from ${settings?['company_name'] ?? 'Popo Baking Accessories'}. Total: KES ${totalAmount.toStringAsFixed(2)}.',
      );
      final whatsappUrl = Uri.parse(
        'https://web.whatsapp.com/send?text=$message',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      }
    } else {
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Invoice_${transaction['id']}.pdf',
      );
    }
  }

  static Future<pw.Document> generateThermalPdf({
    required String id,
    required DateTime date,
    required String? customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double totalPayable,
    required double amountPaid,
    required double change,
    required String paymentMode,
    required bool depositChange,
    required String cashierName,
    bool isReprint = false,
    double? currentBalance, // Added
    Map<String, String>? settings,
  }) async {
    // Fetch settings if not provided
    if (settings == null) {
      try {
        settings = await SettingsService().fetchSettings();
      } catch (e) {
        debugPrint('ReceiptService: Failed to load settings: $e');
      }
    }
    final doc = pw.Document();

    // Parse Paper Size
    final paperSizeStr = settings?['thermal_paper_size'] ?? '80mm';
    final pageFormat = paperSizeStr == '58mm'
        ? PdfPageFormat.roll57
        : PdfPageFormat.roll80;

    // Parse Header Option

    // Parse Extra Lines
    // final extraLinesStr = settings?['thermal_extra_lines'] ?? '0';

    // Parse Font
    final fontName = settings?['receipt_font'] ?? 'Helvetica';
    pw.Font font;
    pw.Font fontBold;

    switch (fontName) {
      case 'Times':
        font = pw.Font.times();
        fontBold = pw.Font.timesBold();
        break;
      case 'Courier':
        font = pw.Font.courier();
        fontBold = pw.Font.courierBold();
        break;
      default:
        font = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
    }

    final companyName = settings?['company_name'] ?? 'POPO BAKING ACCESSORIES';
    final address = settings?['company_address'] ?? 'Thika, Kenya';
    final phone = settings?['company_phone'] ?? '+254 7XX XXX XXX';

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  companyName.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  address,
                  style: pw.TextStyle(font: font, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Tel: $phone',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${date.toString().substring(0, 16)}',
                    style: pw.TextStyle(font: font, fontSize: 9),
                  ),
                  pw.Text(
                    '#${id.toUpperCase()}',
                    style: pw.TextStyle(font: fontBold, fontSize: 9),
                  ),
                ],
              ),
              if (isReprint)
                pw.Center(
                  child: pw.Text(
                    '(COPY)',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
                ),

              pw.Text(
                'Cashier: $cashierName',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              if (customerName != null)
                pw.Text(
                  'Customer: $customerName',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              pw.Divider(),
              // Items
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(0.5),
                  2: const pw.FlexColumnWidth(1),
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
                  ...items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            item['name'],
                            maxLines: 2,
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            item['quantity'].toString(),
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            item['total'].toStringAsFixed(2),
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
              _buildRow('Subtotal', subtotal, font),
              if (discount > 0) _buildRow('Discount', -discount, font),
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
                      'KES ${totalPayable.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              if (!isReprint) ...[
                _buildRow('Paid ($paymentMode)', amountPaid, font),
                _buildRow(
                  depositChange ? 'Deposited to Wallet' : 'Change',
                  change,
                  fontBold,
                ),
              ],

              // Balance Detail (Only if debt exists AND enabled in settings)
              if (currentBalance != null &&
                  currentBalance > 0.01 &&
                  (settings?['show_balance_on_receipt'] != 'false')) ...[
                pw.SizedBox(height: 5),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                _buildRow(
                  'Previous Balance',
                  currentBalance - (totalPayable - amountPaid),
                  font,
                ),
                _buildRow('Current Balance', currentBalance, fontBold),
              ],

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  settings?['receipt_footer_message'] ??
                      'Thank you for shopping with us!',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static Future<pw.Document> generateA4Pdf({
    required String id,
    required DateTime date,
    required String? customerName,
    required String? customerPhone,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double totalPayable,
    required double amountPaid,
    required double change,
    required String paymentMode,
    required String cashierName,
    bool isReprint = false,
    double? currentBalance, // Added
    Map<String, String>? settings,
  }) async {
    // Fetch settings if not provided
    if (settings == null) {
      try {
        settings = await SettingsService().fetchSettings();
      } catch (e) {
        debugPrint('ReceiptService: Failed to load settings: $e');
      }
    }

    final doc = pw.Document();

    // Parse Font
    final fontName = settings?['receipt_font'] ?? 'Helvetica';
    pw.Font font;
    pw.Font fontBold;

    switch (fontName) {
      case 'Times':
        font = pw.Font.times();
        fontBold = pw.Font.timesBold();
        break;
      case 'Courier':
        font = pw.Font.courier();
        fontBold = pw.Font.courierBold();
        break;
      default:
        font = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
    }

    // Parse Color
    PdfColor primaryColor = PdfColors.red800;
    if (settings?['company_color'] != null) {
      try {
        String hex = settings!['company_color']!.replaceAll('#', '');
        if (hex.length == 6) {
          primaryColor = PdfColor.fromInt(int.parse('0xFF$hex'));
        }
      } catch (e) {
        debugPrint('ReceiptService: Failed to parse color: $e');
      }
    }

    final companyName = settings?['company_name'] ?? 'POPO BAKING ACCESSORIES';
    final address = settings?['company_address'] ?? 'Thika, Kenya';
    final phone = settings?['company_phone'] ?? '+254 7XX XXX XXX';
    final email = settings?['company_email'] ?? 'info@popobaking.com';
    final paymentDetails =
        settings?['payment_details'] ??
        'Bank: M-Pesa / Equity Bank\nPaybill: XXXXXX';
    final terms =
        settings?['terms_and_conditions'] ??
        'Goods once sold are not returnable after 2 days.';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 24,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        address,
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Tel: $phone',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Email: $email',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 32,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Invoice #: $id',
                        style: pw.TextStyle(font: fontBold, fontSize: 12),
                      ),
                      pw.Text(
                        'Date: ${date.toString().substring(0, 10)}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      if (isReprint)
                        pw.Text(
                          'COPY',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: PdfColors.red,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // BILL TO
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: primaryColor, width: 4),
                      ),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bill To:',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          customerName ?? 'Walk-in Customer',
                          style: pw.TextStyle(font: fontBold, fontSize: 14),
                        ),
                        if (customerPhone != null && customerPhone.isNotEmpty)
                          pw.Text(
                            'Tel: $customerPhone',
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // TABLE
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5), // #
                  1: const pw.FlexColumnWidth(3), // Item
                  2: const pw.FlexColumnWidth(1), // Qty
                  3: const pw.FlexColumnWidth(1.5), // Unit Price
                  4: const pw.FlexColumnWidth(1.5), // Total
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      _buildCell('No.', fontBold, color: PdfColors.white),
                      _buildCell(
                        'Item Description',
                        fontBold,
                        color: PdfColors.white,
                      ),
                      _buildCell(
                        'Qty',
                        fontBold,
                        color: PdfColors.white,
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        'Price',
                        fontBold,
                        color: PdfColors.white,
                        align: pw.TextAlign.right,
                      ),
                      _buildCell(
                        'Total',
                        fontBold,
                        color: PdfColors.white,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final i = entry.key + 1;
                    final item = entry.value;
                    final color = i % 2 == 0
                        ? PdfColors.grey100
                        : PdfColors.white;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: color),
                      children: [
                        _buildCell(i.toString(), font),
                        _buildCell(item['name'], font),
                        _buildCell(
                          item['quantity'].toString(),
                          font,
                          align: pw.TextAlign.center,
                        ),
                        _buildCell(
                          item['unit_price'] != null
                              ? double.parse(
                                  item['unit_price'].toString(),
                                ).toStringAsFixed(2)
                              : '-',
                          font,
                          align: pw.TextAlign.right,
                        ),
                        _buildCell(
                          item['total'].toStringAsFixed(2),
                          font,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // FOOTER / TOTALS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Payment Details:',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                        ),
                        pw.Text(
                          paymentDetails,
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Terms & Conditions:',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                        ),
                        pw.Text(
                          terms,
                          style: pw.TextStyle(font: font, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 40),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      children: [
                        _buildRow('Subtotal', subtotal, font),
                        if (discount > 0)
                          _buildRow('Discount', -discount, font),
                        pw.Divider(),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5),
                          color: primaryColor,
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 5),
                                child: pw.Text(
                                  'TOTAL',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 14,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(right: 5),
                                child: pw.Text(
                                  'KES ${totalPayable.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 14,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        _buildRow('Amount Paid', amountPaid, font),
                        _buildRow(
                          'Balance Due',
                          totalPayable - amountPaid > 0
                              ? totalPayable - amountPaid
                              : 0,
                          fontBold,
                        ),
                        // Customer Balance (A4)
                        if (currentBalance != null &&
                            currentBalance > 0.01 &&
                            (settings?['show_balance_on_receipt'] !=
                                'false')) ...[
                          pw.SizedBox(height: 5),
                          pw.Divider(),
                          _buildRow(
                            'Previous Balance',
                            currentBalance - (totalPayable - amountPaid),
                            font,
                          ),
                          _buildRow(
                            'Current Balance',
                            currentBalance,
                            fontBold,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              // Footer Message
              pw.Center(
                child: pw.Text(
                  settings?['receipt_footer_message'] ??
                      'Thank you for shopping with us!',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: primaryColor, thickness: 2),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _buildCell(
    String text,
    pw.Font font, {
    PdfColor color = PdfColors.black,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 10, color: color),
        textAlign: align,
      ),
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
