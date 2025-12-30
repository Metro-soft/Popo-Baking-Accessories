import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:frontend/modules/core/services/settings_service.dart';

class StatementPdfService {
  static final _currencyFormat = NumberFormat("#,##0.00", "en_US");
  static final _dateFormat = DateFormat('MMM dd, yyyy');

  // Brand Colors
  static const PdfColor _primaryColor = PdfColor.fromInt(
    0xFF6A1B9A,
  ); // Deep Purple
  static const PdfColor _accentColor = PdfColor.fromInt(
    0xFFFF6F00,
  ); // Amber/Orange
  static const PdfColor _lightGrey = PdfColor.fromInt(0xFFF5F5F5);

  /// Generates and prints a statement for a Customer or Supplier.
  static Future<void> printStatement({
    required Map<String, dynamic> party,
    required List<dynamic> transactions,
    required String type,
    required bool showDetails,
  }) async {
    final doc = pw.Document();

    // Fetch Settings & Logo
    final settings = await SettingsService().fetchSettings();
    final logoImage = await _resolveLogo(settings['company_logo']);

    // Sort transactions
    transactions.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );

    // Initial Balance
    double openingBalance =
        double.tryParse(party['opening_balance'].toString()) ?? 0;
    double runningBalance = openingBalance;

    // Process transactions
    final processedTransactions = transactions.map((t) {
      final map = Map<String, dynamic>.from(t as Map);
      final amount = double.tryParse(map['amount'].toString()) ?? 0;
      final isPayment = map['type'] == 'payment';

      if (isPayment) {
        runningBalance -= amount;
      } else {
        runningBalance += amount;
      }

      return <String, dynamic>{...map, 'running_balance': runningBalance};
    }).toList();

    // Fonts
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontItalic = await PdfGoogleFonts.openSansItalic();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          italic: fontItalic,
        ),
        build: (pw.Context context) {
          return [
            _buildHeader(settings, logoImage, type),
            pw.SizedBox(height: 20),
            _buildSummary(party, runningBalance),
            pw.SizedBox(height: 24),
            _buildTable(
              processedTransactions,
              type,
              showDetails,
              openingBalance,
            ),
            pw.SizedBox(height: 32),
            _buildFooter(settings),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${party['name']}_Statement.pdf',
    );
  }

  static Future<pw.ImageProvider> _resolveLogo(String? url) async {
    try {
      if (url != null && url.startsWith('http')) {
        return await networkImage(url);
      }
    } catch (e) {
      // Fallback on error
    }
    // Default Asset Logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    return pw.MemoryImage(bytes.buffer.asUint8List());
  }

  static pw.Widget _buildHeader(
    Map<String, String> settings,
    pw.ImageProvider logo,
    String type,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Left: Logo & Company Info
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 60, width: 60, child: pw.Image(logo)),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  settings['company_name'] ?? 'Popo Baking Accessories',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  settings['company_address'] ?? 'Nairobi, Kenya',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  settings['company_phone'] ?? '+254 700 000 000',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                if (settings['company_email'] != null)
                  pw.Text(
                    settings['company_email']!,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ],
        ),

        // Right: Title & Date
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'STATEMENT',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: _accentColor,
              ),
            ),
            pw.Text(
              'Date: ${_dateFormat.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummary(
    Map<String, dynamic> party,
    double totalBalance,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'To:',
                style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                party['name'],
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (party['phone'] != null)
                pw.Text(
                  party['phone'],
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (party['address'] != null)
                pw.Text(
                  party['address'],
                  style: const pw.TextStyle(fontSize: 10),
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Amount Due',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.Text(
                'KES ${_currencyFormat.format(totalBalance)}',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: totalBalance > 0
                      ? PdfColors.red900
                      : PdfColors.green900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(
    List<Map<String, dynamic>> transactions,
    String type,
    bool showDetails,
    double openingBalance,
  ) {
    final isCustomer = type == 'Customer';

    return pw.Table(
      border: null, // Minimal look
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Date
        1: const pw.FlexColumnWidth(4), // Description
        2: const pw.FlexColumnWidth(1.5), // Debit
        3: const pw.FlexColumnWidth(1.5), // Credit
        4: const pw.FlexColumnWidth(2), // Balance
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primaryColor),
          children: [
            _tableHeaderCell('Date'),
            _tableHeaderCell('Description'),
            _tableHeaderCell(isCustomer ? 'Billed' : 'Inv Amount'),
            _tableHeaderCell('Paid'),
            _tableHeaderCell('Balance'),
          ],
        ),
        // Spacer
        pw.TableRow(children: List.generate(5, (i) => pw.SizedBox(height: 8))),

        // Opening Balance
        if (openingBalance != 0)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            children: [
              _tableCell('-'),
              _tableCell('Balance Brought Forward', isBold: true),
              _tableCell('-'),
              _tableCell('-'),
              _tableCell(
                _currencyFormat.format(openingBalance),
                align: pw.TextAlign.right,
                isBold: true,
              ),
            ],
          ),

        // Rows
        ...transactions.asMap().entries.expand((entry) {
          final i = entry.key;
          final t = entry.value;
          final isPayment = t['type'] == 'payment';
          final amount = double.tryParse(t['amount'].toString()) ?? 0;
          final balance = double.parse(t['running_balance'].toString());
          final date = DateTime.parse(t['date']);
          final items = (t['items'] as List<dynamic>?) ?? [];

          final isStriped = i % 2 == 1;
          final rowColor = isStriped ? _lightGrey : null;

          final mainRow = pw.TableRow(
            decoration: pw.BoxDecoration(color: rowColor),
            children: [
              _tableCell(_dateFormat.format(date)),
              _tableCell(
                isPayment
                    ? 'Payment (${t['method'] ?? 'Cash'}) ${t['reference'] ?? ''}'
                    : '${isCustomer ? 'Order' : 'Bill'} #${t['id']}',
                isBold: !isPayment,
                textColor: isPayment ? PdfColors.green700 : null,
              ),
              _tableCell(
                isPayment ? '-' : _currencyFormat.format(amount),
                align: pw.TextAlign.right,
              ),
              _tableCell(
                isPayment ? _currencyFormat.format(amount) : '-',
                align: pw.TextAlign.right,
                textColor: PdfColors.green700,
              ),
              _tableCell(
                _currencyFormat.format(balance),
                align: pw.TextAlign.right,
                isBold: true,
              ),
            ],
          );

          if (!showDetails || isPayment || items.isEmpty) {
            return [mainRow];
          }

          final itemRows = items.map((item) {
            final name = item['name'] ?? 'Item';
            final qty = double.tryParse(item['quantity'].toString()) ?? 0;
            final price = double.tryParse(item['price'].toString()) ?? 0;

            return pw.TableRow(
              decoration: pw.BoxDecoration(color: rowColor),
              children: [
                pw.SizedBox(),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 16, bottom: 4),
                  child: pw.Text(
                    '• $name (x$qty @ ${_currencyFormat.format(price)})',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
                pw.SizedBox(),
                pw.SizedBox(),
                pw.SizedBox(),
              ],
            );
          });

          return [mainRow, ...itemRows];
        }),
      ],
    );
  }

  /// Generates and prints a Single Transaction (Invoice or Bill)
  static Future<void> printTransaction({
    required Map<String, dynamic> data,
    required String type,
  }) async {
    final doc = pw.Document();
    final isInvoice = type == 'Invoice';

    // Fetch Settings
    final settings = await SettingsService().fetchSettings();
    final logoImage = await _resolveLogo(settings['company_logo']);

    final partyName = isInvoice ? data['customer_name'] : data['supplier_name'];
    final partyPhone = data['phone'];
    // date variable removed as unused
    final items = (data['items'] as List<dynamic>?) ?? [];
    final total =
        double.tryParse(
          (isInvoice ? data['total_amount'] : data['total_product_cost'])
              .toString(),
        ) ??
        0;

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            _buildHeader(
              settings,
              logoImage,
              type == 'Invoice' ? 'SALES INVOICE' : 'PURCHASE ORDER',
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            // Sub-header with Order details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isInvoice ? 'Bill To' : 'From',
                      style: pw.TextStyle(
                        color: PdfColors.grey600,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      partyName ?? 'Unknown',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (partyPhone != null)
                      pw.Text(
                        partyPhone,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '#${data['id']}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$type Status: ${data['status']?.toUpperCase() ?? '-'}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3), // Product
                1: const pw.FlexColumnWidth(1), // Qty
                2: const pw.FlexColumnWidth(1.5), // Price
                3: const pw.FlexColumnWidth(1.5), // Total
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _primaryColor),
                  children: [
                    _tableHeaderCell('Item'),
                    _tableHeaderCell('Qty', align: pw.TextAlign.center),
                    _tableHeaderCell(
                      isInvoice ? 'Price' : 'Cost',
                      align: pw.TextAlign.right,
                    ),
                    _tableHeaderCell('Total', align: pw.TextAlign.right),
                  ],
                ),
                ...items.map((item) {
                  final name = item['product_name'] ?? 'Item';
                  final qty =
                      double.tryParse(
                        (isInvoice
                                ? item['quantity']
                                : item['quantity_received'])
                            .toString(),
                      ) ??
                      0;
                  final price =
                      double.tryParse(
                        (isInvoice
                                ? item['unit_price']
                                : item['supplier_unit_price'])
                            .toString(),
                      ) ??
                      0;
                  final subtotal = qty * price;

                  return pw.TableRow(
                    children: [
                      _tableCell(name),
                      _tableCell(qty.toString(), align: pw.TextAlign.center),
                      _tableCell(
                        _currencyFormat.format(price),
                        align: pw.TextAlign.right,
                      ),
                      _tableCell(
                        _currencyFormat.format(subtotal),
                        align: pw.TextAlign.right,
                        isBold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Totals
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Amount',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'KES ${_currencyFormat.format(total)}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),
            _buildFooter(settings),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${type}_${data['id']}.pdf',
    );
  }

  static pw.Widget _tableHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.white,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(Map<String, String> settings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you for doing business with us!',
          style: pw.TextStyle(
            fontSize: 10,
            color: _primaryColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (settings['company_address'] != null)
          pw.Text(
            settings['company_address']!,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
      ],
    );
  }
}
