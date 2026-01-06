import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import ImagePicker
import 'package:frontend/modules/core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();

  // Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  final _paymentDetailsController = TextEditingController();
  final _termsController = TextEditingController();

  // Structured Payment & Terms Controllers
  final _tillController = TextEditingController();
  final _paybillBizController = TextEditingController();
  final _paybillAccController = TextEditingController();

  // Branding Controllers
  final _colorController = TextEditingController();

  // Thermal Config Controllers
  final _extraLinesController = TextEditingController();
  final _copiesController = TextEditingController();

  // Sales Config Controllers
  final _taxRateController = TextEditingController(); // [NEW]
  final _newRegionController = TextEditingController(); // [NEW]
  final _newRegionPriceController = TextEditingController(); // [NEW]

  // Settings State
  String _paymentType = 'Custom'; // Custom, Buy Goods, Pay Bill
  String _fontType = 'Helvetica'; // Helvetica, Times, Courier
  String _defaultTaxType = 'Exclusive'; // [NEW]

  // Thermal State
  String _paperSize = '80mm'; // 58mm, 80mm
  bool _autoCut = false;
  bool _openDrawer = false;
  bool _printThermalHeader = true;

  bool _showBalance = true;
  bool _autoPrint = false;
  int _selectedIndex = 0;

  // Message Templates
  final _statementTemplateController = TextEditingController();
  final _reminderTemplateController = TextEditingController();
  final _countryCodeController = TextEditingController();

  // Logistics State
  List<Map<String, dynamic>> _deliveryRegions = [];

  String? _currentLogoUrl;
  XFile? _pickedLogo; // Store picked image

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.fetchSettings();
      _nameController.text = settings['company_name'] ?? '';
      _addressController.text = settings['company_address'] ?? '';
      _phoneController.text = settings['company_phone'] ?? '';
      _emailController.text = settings['company_email'] ?? '';
      _currentLogoUrl = settings['company_logo'];

      _receiptFooterController.text =
          settings['receipt_footer_message'] ??
          'Thank you for shopping with us!';
      _paymentDetailsController.text = settings['payment_details'] ?? '';
      _termsController.text =
          settings['terms_and_conditions'] ??
          'Goods once sold are not returnable after 2 days.';
      _showBalance = settings['show_balance_on_receipt'] != 'false';
      _autoPrint = settings['auto_print_receipt'] == 'true';

      // Load Payment Config
      _paymentType = settings['payment_type'] ?? 'Custom';
      _tillController.text = settings['mpesa_till'] ?? '';
      _paybillBizController.text = settings['mpesa_paybill_biz'] ?? '';
      _paybillAccController.text = settings['mpesa_paybill_acc'] ?? '';

      // Load Branding Config
      _colorController.text = settings['company_color'] ?? '#C62828';
      _fontType = settings['receipt_font'] ?? 'Helvetica';

      // Load Thermal Config
      _paperSize = settings['thermal_paper_size'] ?? '80mm';
      _autoCut = settings['thermal_auto_cut'] == 'true';
      _openDrawer = settings['thermal_open_drawer'] == 'true';
      _printThermalHeader =
          settings['thermal_print_header'] != 'false'; // Default TRUE
      _extraLinesController.text = settings['thermal_extra_lines'] ?? '0';
      _copiesController.text = settings['thermal_copies'] ?? '1';

      _statementTemplateController.text =
          settings['statement_message_template'] ??
          'Hello {name}, your current outstanding balance is {balance}. Please review your statement.';
      _reminderTemplateController.text =
          settings['reminder_message_template'] ??
          'Hello {name}, this is a friendly reminder that you have an outstanding balance of {balance}.';
      _reminderTemplateController.text =
          settings['reminder_message_template'] ??
          'Hello {name}, this is a friendly reminder that you have an outstanding balance of {balance}.';
      _countryCodeController.text = settings['default_country_code'] ?? '254';

      // Load Sales Config [NEW]
      _taxRateController.text = settings['tax_rate'] ?? '0';
      _defaultTaxType = settings['default_tax_type'] ?? 'Exclusive';

      // Load Logistics Config
      if (settings['delivery_regions'] != null) {
        try {
          List<dynamic> decoded = jsonDecode(
            settings['delivery_regions'] as String,
          );
          _deliveryRegions = decoded
              .map((e) {
                if (e is String) {
                  return {'name': e, 'price': '0'};
                } else if (e is Map) {
                  return {'name': e['name'], 'price': e['price'].toString()};
                }
                return {'name': e.toString(), 'price': '0'};
              })
              .toList()
              .cast<Map<String, dynamic>>();
        } catch (e) {
          _deliveryRegions = [];
        }
      } else {
        // Default regions if none set
        _deliveryRegions = [
          {'name': 'Mbita', 'price': '100'},
          {'name': 'Homa Bay', 'price': '150'},
          {'name': 'Rongo', 'price': '200'},
          {'name': 'Kisii', 'price': '250'},
        ];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _pickedLogo = image);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String logoUrl = _currentLogoUrl ?? '';

      // Upload Logo if new one picked
      if (_pickedLogo != null) {
        logoUrl = await _settingsService.uploadLogo(_pickedLogo!);
      }

      // Generate Formatted Payment String
      String formattedPayment = _paymentDetailsController.text;
      if (_paymentType == 'Buy Goods') {
        formattedPayment =
            'LIPA NA M-PESA\nBuy Goods Till: ${_tillController.text}';
      } else if (_paymentType == 'Pay Bill') {
        formattedPayment =
            'LIPA NA M-PESA\nPaybill: ${_paybillBizController.text}\nAccount: ${_paybillAccController.text}';
      }

      final settings = {
        'company_name': _nameController.text,
        'company_address': _addressController.text,
        'company_phone': _phoneController.text,
        'company_email': _emailController.text,
        'company_logo': logoUrl,
        'receipt_footer_message': _receiptFooterController.text,

        // Save structured data + formatted string
        'payment_type': _paymentType,
        'mpesa_till': _tillController.text,
        'mpesa_paybill_biz': _paybillBizController.text,
        'mpesa_paybill_acc': _paybillAccController.text,
        'payment_details': formattedPayment,

        'company_color': _colorController.text,
        'receipt_font': _fontType,

        // Save Thermal Config
        'thermal_paper_size': _paperSize,
        'thermal_auto_cut': _autoCut.toString(),
        'thermal_open_drawer': _openDrawer.toString(),
        'thermal_print_header': _printThermalHeader.toString(),
        'thermal_extra_lines': _extraLinesController.text,
        'thermal_copies': _copiesController.text,

        'terms_and_conditions': _termsController.text,
        'show_balance_on_receipt': _showBalance.toString(),
        'auto_print_receipt': _autoPrint.toString(),
        'statement_message_template': _statementTemplateController.text,
        'reminder_message_template': _reminderTemplateController.text,
        'default_country_code': _countryCodeController.text,

        // Save Sales Config [NEW]
        'tax_rate': _taxRateController.text,
        'total_tax_type': _defaultTaxType,

        // Save Logistics Config
        'delivery_regions': jsonEncode(_deliveryRegions),
      };

      await _settingsService.updateSettings(
        settings,
      ); // Assume this method exists or you create it

      // Update state
      setState(() {
        _currentLogoUrl = logoUrl;
        _pickedLogo = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Company Settings'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadSettings,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                _buildNavTile(0, 'Company Profile', Icons.business),
                _buildNavTile(1, 'Receipts & Printing', Icons.receipt_long),
                _buildNavTile(2, 'Taxes', Icons.percent),
                _buildNavTile(3, 'Logistics', Icons.local_shipping), // [NEW]
                _buildNavTile(4, 'Templates', Icons.message_outlined),
              ],
            ),
          ),

          // Right Content Area
          Expanded(
            child: Container(
              color: Colors.grey[50], // Background for content
              child: Form(key: _formKey, child: _buildSelectedSection()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveSettings,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
        backgroundColor: const Color(0xFFA01B2D),
      ),
    );
  }

  Widget _buildNavTile(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFAF1F2) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFFA01B2D) : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFFA01B2D) : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
        selected: isSelected,
      ),
    );
  }

  Widget _buildSelectedSection() {
    switch (_selectedIndex) {
      case 0:
        return _buildCompanyTab();
      case 1:
        return _buildReceiptsTab();
      case 2:
        return _buildTaxesTab();
      case 3:
        return _buildLogisticsTab(); // [NEW]
      case 4:
        return _buildTemplatesTab();
      default:
        return _buildCompanyTab();
    }
  }

  Widget _buildCompanyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, size: 48, color: Colors.blue),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Company Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'This information allows you to customize your company details.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nameController,
            label: 'Company Name',
            icon: Icons.store,
            validator: (v) => v!.isEmpty ? 'Company name is required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            label: 'Address / Location',
            icon: Icons.location_on,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _countryCodeController,
            label: 'Default Country Code (e.g. 254)',
            icon: Icons.flag,
            hint: '254',
          ),
          const SizedBox(height: 32),
          const Text(
            'Branding',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                  image: _pickedLogo != null
                      ? DecorationImage(
                          image: FileImage(File(_pickedLogo!.path)),
                          fit: BoxFit.cover,
                        )
                      : (_currentLogoUrl != null && _currentLogoUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(_currentLogoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child:
                    (_pickedLogo == null &&
                        (_currentLogoUrl == null || _currentLogoUrl!.isEmpty))
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Upload Logo',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_pickedLogo != null)
            const Center(
              child: Text(
                'Click Save to upload',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildReceiptsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 48, color: Colors.orange),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Receipt Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configure Standard A4 and Thermal Printer options.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              labelColor: Colors.orange[800],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
              tabs: [
                Tab(text: 'REGULAR PRINTER'),
                Tab(text: 'THERMAL PRINTER'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildRegularPrinterTab(),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildThermalPrinterTab(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.percent, size: 48, color: Colors.purple),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tax Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Set your default tax rates and behavior for new sales.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Default Tax Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _taxRateController,
                  label: 'Default Tax Rate (%)',
                  icon: Icons.account_balance,
                  hint: 'e.g 16',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _defaultTaxType,
                  decoration: const InputDecoration(
                    labelText: 'Default Tax Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.settings),
                  ),
                  items: ['Inclusive', 'Exclusive']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _defaultTaxType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[100]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.message_outlined,
                  size: 48,
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Communication Templates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Customize automated messages sent to customers.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Message Templates',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use {name} for customer name and {balance} for debt amount.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _statementTemplateController,
            label: 'Statement Message (WhatsApp)',
            icon: Icons.message,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _reminderTemplateController,
            label: 'Reminder Message (Image Caption)',
            icon: Icons.image,
            maxLines: 3,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLogisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, size: 48, color: Colors.teal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Logistics & Delivery',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage pickup stations and delivery regions for your branches.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Pickup Stations / Regions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add regions available for customer delivery. These will appear in autocomplete.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _newRegionController,
                  decoration: const InputDecoration(
                    labelText: 'Region / Station Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.add_location),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _newRegionPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Price (KES)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (value) => _addRegion(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addRegion,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _deliveryRegions.map((region) {
              return Chip(
                label: Text('${region['name']} - KES ${region['price']}'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeRegion(region),
                backgroundColor: Colors.teal.shade50,
                labelStyle: TextStyle(color: Colors.teal.shade900),
                deleteIconColor: Colors.teal.shade900,
              );
            }).toList(),
          ),
          if (_deliveryRegions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No regions added yet.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _addRegion() {
    final name = _newRegionController.text.trim();
    final price = _newRegionPriceController.text.trim();

    if (name.isNotEmpty && !_deliveryRegions.any((r) => r['name'] == name)) {
      setState(() {
        _deliveryRegions.add({
          'name': name,
          'price': price.isEmpty ? '0' : price,
        });
        _newRegionController.clear();
        _newRegionPriceController.clear();
      });
    }
  }

  void _removeRegion(Map<String, dynamic> region) {
    setState(() {
      _deliveryRegions.removeWhere((r) => r['name'] == region['name']);
    });
  }

  Widget _buildRegularPrinterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Branding & Style',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Brand Color (Hex)',
                  hintText: '#C62828',
                  prefixIcon: Icon(Icons.color_lens),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() {}),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _parseColor(_colorController.text),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _fontType,
          decoration: const InputDecoration(
            labelText: 'Receipt Font',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.font_download),
          ),
          items: [
            'Helvetica',
            'Times',
            'Courier',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _fontType = v!),
        ),
        const SizedBox(height: 32),
        const Text(
          'Payment & Footer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _receiptFooterController,
          label: 'Receipt Footer Message',
          icon: Icons.short_text,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        // Structured Payment Input
        DropdownButtonFormField<String>(
          initialValue: _paymentType,
          decoration: const InputDecoration(
            labelText: 'Payment Method Type',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.payment),
          ),
          items: [
            'Custom',
            'Buy Goods',
            'Pay Bill',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _paymentType = v!),
        ),
        const SizedBox(height: 16),
        if (_paymentType == 'Custom')
          _buildTextField(
            controller: _paymentDetailsController,
            label: 'Payment Details (e.g. Bank/M-Pesa)',
            icon: Icons.edit_note,
            maxLines: 3,
          ),
        if (_paymentType == 'Buy Goods')
          _buildTextField(
            controller: _tillController,
            label: 'Till Number',
            icon: Icons.store,
            hint: 'e.g 123456',
          ),
        if (_paymentType == 'Pay Bill')
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _paybillBizController,
                  label: 'Business No',
                  icon: Icons.confirmation_number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _paybillAccController,
                  label: 'Account No',
                  icon: Icons.account_balance_wallet,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _termsController,
          label: 'Terms & Conditions',
          icon: Icons.description,
          maxLines: 3,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildThermalPrinterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paper & Layout',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _paperSize,
          decoration: const InputDecoration(
            labelText: 'Paper Size',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.print),
          ),
          items: [
            '58mm',
            '80mm',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _paperSize = v!),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _extraLinesController,
          label: 'Extra lines at the end (Feed)',
          icon: Icons.space_bar,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _copiesController,
          label: 'Number of copies',
          icon: Icons.copy,
        ),
        const SizedBox(height: 32),
        const Text(
          'Hardware Control',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: const Text('Auto Cut Paper'),
          subtitle: const Text(
            'Cut paper after printing (Supported hardware only)',
          ),
          value: _autoCut,
          onChanged: (v) => setState(() => _autoCut = v),
        ),
        SwitchListTile(
          title: const Text('Open Cash Drawer'),
          subtitle: const Text(
            'Open drawer after printing (Supported hardware only)',
          ),
          value: _openDrawer,
          onChanged: (v) => setState(() => _openDrawer = v),
        ),
        const SizedBox(height: 32),
        const Text(
          'Content',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: const Text('Print Company Header'),
          subtitle: const Text('Show logo and address at top'),
          value: _printThermalHeader,
          onChanged: (v) => setState(() => _printThermalHeader = v),
        ),
        SwitchListTile(
          title: const Text('Show Balance on Receipt'),
          subtitle: const Text('Display customer debt on receipt'),
          value: _showBalance,
          onChanged: (v) => setState(() => _showBalance = v),
        ),
        SwitchListTile(
          title: const Text('Auto-Print Receipt'),
          subtitle: const Text('Automatically print receipt after sale'),
          value: _autoPrint,
          onChanged: (v) => setState(() => _autoPrint = v),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      }
    } catch (e) {
      // ignore
    }
    return const Color(0xFFC62828);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _receiptFooterController.dispose();
    _paymentDetailsController.dispose();
    _termsController.dispose();
    _statementTemplateController.dispose();
    _reminderTemplateController.dispose();
    _countryCodeController.dispose();
    _newRegionController.dispose(); // [NEW]
    _newRegionPriceController.dispose();
    super.dispose();
  }
}
