import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/settings_service.dart';

class CustomerFormPanel extends StatefulWidget {
  final Map<String, dynamic>? customer;
  final Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const CustomerFormPanel({
    super.key,
    this.customer,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<CustomerFormPanel> createState() => _CustomerFormPanelState();
}

class _CustomerFormPanelState extends State<CustomerFormPanel> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _emailController;
  late TextEditingController _regionController; // [NEW]
  late TextEditingController _addressController;
  late TextEditingController _limitController;
  late TextEditingController _openingBalanceController;

  final SettingsService _settingsService = SettingsService();
  String _defaultCountryCode = '254';

  List<String> _regions = [
    'Mbita',
    'Homa Bay',
    'Rongo',
    'Ndhiwa',
    'Rodi Kopany',
    'Sindo',
    'Oyugis',
    'Awendo',
    'Migori',
    'Kisii',
  ]; // [UPDATED] - Default fallback

  Future<void> _fetchSettings() async {
    try {
      final settings = await _settingsService.fetchSettings();
      if (mounted) {
        setState(() {
          _defaultCountryCode = settings['default_country_code'] ?? '254';

          if (settings['delivery_regions'] != null) {
            try {
              List<dynamic> decoded = jsonDecode(
                settings['delivery_regions'] as String,
              );
              _regions = decoded.map((e) {
                if (e is Map) return e['name'].toString();
                return e.toString();
              }).toList();
            } catch (e) {
              // Fallback if parsing fails, keep defaults
              debugPrint('Error parsing regions: $e');
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching settings in form: $e');
    }
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      return _defaultCountryCode + cleaned.substring(1);
    } else if (!cleaned.startsWith(_defaultCountryCode)) {
      if (cleaned.length == 9) {
        return _defaultCountryCode + cleaned;
      }
    }
    return cleaned;
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
    _nameController = TextEditingController(
      text: widget.customer?['name'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.customer?['phone'] ?? '',
    );
    _altPhoneController = TextEditingController(
      text: widget.customer?['alt_phone'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.customer?['email'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.customer?['address'] ?? '',
    );
    _regionController = TextEditingController(
      text: widget.customer?['region'] ?? '',
    ); // [NEW]
    _limitController = TextEditingController(
      text: widget.customer?['credit_limit']?.toString() ?? '0',
    );
    _openingBalanceController = TextEditingController(
      text: widget.customer?['opening_balance']?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _regionController.dispose(); // [NEW]
    _limitController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      String phone = _phoneController.text.trim();
      String altPhone = _altPhoneController.text.trim();
      phone = _formatPhoneNumber(phone);
      if (altPhone.isNotEmpty) altPhone = _formatPhoneNumber(altPhone);

      final data = {
        'name': _nameController.text.trim(),
        'phone': phone,
        'alt_phone': altPhone,
        'email': _emailController.text.trim(),
        'address': _addressController.text
            .trim(), // Kept key as address effectively Landmark
        'region': _regionController.text.trim(), // [NEW]
        'credit_limit': double.tryParse(_limitController.text.trim()) ?? 0.0,
        'opening_balance':
            double.tryParse(_openingBalanceController.text.trim()) ?? 0.0,
      };
      widget.onSave(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Cancel',
                ),
                const SizedBox(width: 16),
                Text(
                  isEditing ? 'Edit Customer' : 'New Customer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone (Primary)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Phone is required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _altPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Alt Phone (Optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_android),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          // Simple regex for basic validation
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Region Field
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue val) {
                            if (val.text == '') {
                              return const Iterable<String>.empty();
                            }
                            return _regions.where(
                              (opt) => opt.toLowerCase().contains(
                                val.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (selection) =>
                              _regionController.text = selection,
                          fieldViewBuilder:
                              (context, controller, focusNode, onUnfocus) {
                                if (_regionController.text.isNotEmpty &&
                                    controller.text.isEmpty) {
                                  controller.text = _regionController.text;
                                }
                                controller.addListener(
                                  () =>
                                      _regionController.text = controller.text,
                                );
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Region / Town',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.map),
                                    helperText: 'e.g. Mbita, Homa Bay, Rongo',
                                  ),
                                  validator: (val) => val == null || val.isEmpty
                                      ? 'Region is required'
                                      : null,
                                );
                              },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Specific Location (formerly Address/Landmark)
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Specific Landmark / Pickup Point',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        helperText: 'e.g. "Ferry Terminal", "Opposite Equity"',
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Landmark is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _limitController,
                      decoration: const InputDecoration(
                        labelText: 'Credit Limit (KES)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _openingBalanceController,
                      decoration: const InputDecoration(
                        labelText: 'Opening Balance (Old Debt)',
                        helperText: 'Amount owed BEFORE using this system',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.history),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Create Customer',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
