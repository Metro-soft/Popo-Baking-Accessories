import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final Map<String, String> settings;

  const ReminderCard({
    super.key,
    required this.customer,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    // Branding Colors
    const primaryColor = Color(0xFFA01B2D);
    const secondaryColor = Color(0xFFFAF9F6); // Off-white

    final format = NumberFormat("#,##0.00");
    final debt = double.tryParse(customer['current_debt'].toString()) ?? 0.0;
    final date = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    final companyName = settings['company_name'] ?? 'Popo Baking Accessories';
    final companyPhone = settings['company_phone'] ?? '';
    final logoUrl = settings['company_logo'];

    return Container(
      width: 400, // Fixed width for consistent image generation
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                if (logoUrl != null && logoUrl.isNotEmpty)
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    backgroundImage: NetworkImage(logoUrl),
                  )
                else
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(Icons.store, color: primaryColor, size: 30),
                  ),
                const SizedBox(height: 12),
                Text(
                  companyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Payment Reminder',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Text(
                  'Outstanding Balance',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'KES ${format.format(debt)}',
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),
                _buildInfoRow('Customer', customer['name']),
                const SizedBox(height: 12),
                _buildInfoRow('Date', date),
                if (companyPhone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Contact Us', companyPhone),
                ],
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const Text(
              'Thank you for your business!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
