import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum OverlayMode { none, dispatch, edit }

class DispatchDetailPane extends StatefulWidget {
  final Map<String, dynamic> order;
  final Color Function(String) getStatusColor;
  final Function(int, String, {Map<String, dynamic>? details}) onUpdateStatus;

  const DispatchDetailPane({
    super.key,
    required this.order,
    required this.getStatusColor,
    required this.onUpdateStatus,
  });

  @override
  State<DispatchDetailPane> createState() => _DispatchDetailPaneState();
}

class _DispatchDetailPaneState extends State<DispatchDetailPane> {
  late List<dynamic> _items;
  late List<bool> _checked;
  bool _packingConfirmed = false;
  OverlayMode _overlayMode = OverlayMode.none;

  // Form Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
  String _method = 'motorbike';

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  @override
  void didUpdateWidget(DispatchDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order['id'] != widget.order['id']) {
      _initializeState();
      _overlayMode = OverlayMode.none; // Reset overlay on order change
    }
  }

  void _initializeState() {
    _items = widget.order['items_list'] as List<dynamic>? ?? [];
    _checked = List<bool>.filled(_items.length, false);

    final status = widget.order['dispatch_status'] ?? 'pending';
    if (status == 'released' || status == 'delivered') {
      _packingConfirmed = true;
      _checked.fillRange(0, _checked.length, true);
    }
  }

  void _openDispatchForm() {
    setState(() {
      _overlayMode = OverlayMode.dispatch;
      _method = 'motorbike';
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _plateCtrl.clear();
      _commentsCtrl.clear();
    });
  }

  void _openEditForm() {
    final details = widget.order['delivery_details'] ?? {};
    setState(() {
      _overlayMode = OverlayMode.edit;
      _method = details['method'] ?? 'motorbike';
      _nameCtrl.text = details['driver_name'] ?? '';
      _phoneCtrl.text = details['phone'] ?? '';
      _plateCtrl.text = details['plate'] ?? '';
      _commentsCtrl.text = details['comments'] ?? '';
    });
  }

  Future<void> _submitForm() async {
    final isDispatch = _overlayMode == OverlayMode.dispatch;

    widget.onUpdateStatus(
      widget.order['id'],
      'released',
      details: {
        'method': _method,
        'driver_name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'plate': _plateCtrl.text,
        'comments': _commentsCtrl.text,
        'dispatched_at':
            widget.order['delivery_details']?['dispatched_at'] ??
            DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    setState(() {
      _overlayMode = OverlayMode.none;
    });

    if (isDispatch) {
      // Send WhatsApp
      try {
        final custPhone = widget.order['customer_phone']?.toString() ?? '';
        if (custPhone.isEmpty) return;

        // Format Phone (Assume KE 254 if starts with 0)
        String phone = custPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.startsWith('0')) {
          phone = '254${phone.substring(1)}';
        }

        final message = StringBuffer();
        message.writeln('Hello ${widget.order['customer_name']},');
        message.writeln(
          'Your Order #${widget.order['id']} has been dispatched via ${_method.toUpperCase().replaceAll('_', ' ')}.',
        );
        message.writeln('');
        message.writeln('📦 Dispatch Details:');
        message.writeln('👤 Rider/Driver: ${_nameCtrl.text}');
        message.writeln('📞 Phone: ${_phoneCtrl.text}');
        if (_plateCtrl.text.isNotEmpty) {
          message.writeln('🚗 Plate/Ref: ${_plateCtrl.text}');
        }
        if (_commentsCtrl.text.isNotEmpty) {
          message.writeln('📝 Note: ${_commentsCtrl.text}');
        }
        message.writeln('');
        message.writeln(
          'Thank you for shopping with Popo Baking Accessories! 🎂',
        );

        final url = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message.toString())}',
        );

        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch WhatsApp: $url');
        }
      } catch (e) {
        debugPrint('Error sending WhatsApp: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // BASE LAYER (Normal Details)
        _buildBaseContent(),

        // OVERLAY LAYER (Form)
        if (_overlayMode != OverlayMode.none)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(
                alpha: 0.95,
              ), // Semi-transparent overlay
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFA01B2D,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _overlayMode == OverlayMode.dispatch
                                  ? Icons.local_shipping
                                  : Icons.edit,
                              color: const Color(0xFFA01B2D),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _overlayMode == OverlayMode.dispatch
                                ? 'Dispatch Order #${widget.order['id']}'
                                : 'Edit Delivery Details',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Warning in Dialog
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        items: const [
                          DropdownMenuItem(
                            value: 'motorbike',
                            child: Text('Motorbike / Boda'),
                          ),
                          DropdownMenuItem(
                            value: 'public_transport',
                            child: Text('Public Transport'),
                          ),
                          DropdownMenuItem(
                            value: 'courier',
                            child: Text('Courier Service'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _method = v!),
                        decoration: InputDecoration(
                          labelText: 'Delivery Method',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: _method == 'courier'
                              ? 'Company Name'
                              : 'Rider / Driver Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: _method == 'courier'
                                    ? 'Helpline / Phone'
                                    : 'Phone',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),
                          if (_method == 'public_transport') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _plateCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Plate / Ref',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentsCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Comments / Notes',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _overlayMode = OverlayMode.none),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA01B2D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('CONFIRM'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBaseContent() {
    final status = widget.order['dispatch_status'] ?? 'pending';
    final isPending = status == 'pending';
    final isProcessing = status == 'processing';
    final isReleased = status == 'released';
    final isDelivered = status == 'delivered';
    final canCheck = isPending || isProcessing;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${widget.order['id']}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.order['customer_name']} • ${widget.order['customer_phone'] ?? 'No Phone'}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLocationBadge('From', 'Popo Baking', Colors.grey),
                      Container(
                        width: 30,
                        height: 1,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      _buildLocationBadge(
                        'To',
                        '${widget.order['customer_region'] ?? ''} - ${widget.order['customer_address'] ?? 'No Address'}'
                            .replaceAll(RegExp(r'^ - '), ''),
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Packing Checklist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (canCheck && _items.isNotEmpty)
                          Text(
                            '${_checked.where((c) => c).length}/${_items.length} Checked',
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _items.isEmpty
                          ? Text(
                              widget.order['items_summary']?.replaceAll(
                                    ', ',
                                    '\n',
                                  ) ??
                                  'No items',
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            )
                          : ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (c, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return CheckboxListTile(
                                  title: Text(
                                    item['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      decoration: _checked[index]
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: _checked[index]
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                  subtitle: Text('Qty: ${item['quantity']}'),
                                  value: _checked[index],
                                  onChanged: canCheck && !_packingConfirmed
                                      ? (val) {
                                          setState(() {
                                            _checked[index] = val ?? false;
                                          });
                                        }
                                      : null,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                );
                              },
                            ),
                    ),

                    if (isReleased &&
                        widget.order['delivery_details'] != null) ...[
                      const Divider(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.delivery_dining,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Out for Delivery',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${widget.order['delivery_details']['driver_name']} (${widget.order['delivery_details']['plate']})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Via ${widget.order['delivery_details']['method']?.toUpperCase() ?? 'UNKNOWN'} • ${widget.order['delivery_details']['phone']}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: _openEditForm,
                              tooltip: 'Edit Details',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canCheck && !_packingConfirmed)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('CONFIRM PACKING'),
                  onPressed: _checked.every((c) => c)
                      ? () {
                          setState(() => _packingConfirmed = true);
                          if (isPending) {
                            widget.onUpdateStatus(
                              widget.order['id'],
                              'processing',
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),

              if (_packingConfirmed && !isReleased && !isDelivered)
                ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('DISPATCH ORDER'),
                  onPressed: _openDispatchForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA01B2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),

              if (isReleased)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('MARK DELIVERED'),
                  onPressed: () =>
                      widget.onUpdateStatus(widget.order['id'], 'delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBadge(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: color[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color[900],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
