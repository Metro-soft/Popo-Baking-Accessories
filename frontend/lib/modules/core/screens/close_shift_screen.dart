import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Correct path from core/screens/ -> core/services/

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isLoading = false;
  // In a real app, we'd fetch the active drawer ID from local storage/state
  // For MVP, we might hardcode or fetch the 'open' drawer for this user.
  // Let's assume we pass it or fetch it.

  Future<void> _submitClose() async {
    final cash = double.tryParse(_cashCtrl.text);
    if (cash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid cash amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // For MVP, hardcoding drawerId=1 or fetching active.
    // Ideally, we'd have a 'checkActiveShift' endpoint.
    // We will assume ID 1 for demonstration if not fetched.
    int drawerId = 1;

    try {
      // Blind Close
      await _apiService.closeShift(drawerId, cash, _notesCtrl.text);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Shift Closed'),
            content: const Text(
              'Reconciliation data has been recorded.\n\nThank you for your hard work!',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Exit Screen
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('End of Shift Reconciliation')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_clock, size: 80, color: Colors.indigo),
                const SizedBox(height: 20),
                const Text(
                  'Blind Close',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please count the physical cash in the drawer and enter the total below. Do not include float if it was already recorded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _cashCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Total Physical Cash (KES)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SUBMIT & CLOSE SHIFT'),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'WARNING: Once submitted, this action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
