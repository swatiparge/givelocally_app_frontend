import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Verify Pickup Code Screen
/// WF-22: Donor enters 4-digit code to complete pickup
class VerifyPickupCodeScreen extends StatefulWidget {
  final String donationId;
  final String receiverName;

  const VerifyPickupCodeScreen({
    super.key,
    required this.donationId,
    required this.receiverName,
  });

  @override
  State<VerifyPickupCodeScreen> createState() => _VerifyPickupCodeScreenState();
}

class _VerifyPickupCodeScreenState extends State<VerifyPickupCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      }
    }
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();

    if (code.length != 4) {
      setState(() {
        _errorMessage = 'Please enter all 4 digits';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('verifyPickupCode');

      final result = await callable.call({
        'donationId': widget.donationId,
        'pickupCode': code,
      });

      if (result.data['success'] == true) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/verification-success',
            arguments: {'donationId': widget.donationId},
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Verification failed';
        _isVerifying = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred';
        _isVerifying = false;
      });
    }
  }

  void _handleError(String errorType) {
    if (errorType == 'invalid-argument') {
      setState(() {
        _errorMessage = 'Invalid pickup code. Please try again.';
      });
    } else if (errorType == 'failed-precondition') {
      Navigator.pushReplacementNamed(context, '/verification-expired');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Pickup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Enter Pickup Code',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask ${widget.receiverName} for their pickup code',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 60,
                  height: 80,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: _errorMessage != null
                          ? Colors.red[50]
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _errorMessage != null
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                    ),
                    onChanged: (value) => _onCodeChanged(index, value),
                  ),
                );
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _isVerifying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'VERIFY & COMPLETE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
