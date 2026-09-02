import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backend_api_service.dart';
import 'role_gate.dart';

class PairingCodeLoginPage extends StatefulWidget {
  const PairingCodeLoginPage({super.key});

  @override
  State<PairingCodeLoginPage> createState() => _PairingCodeLoginPageState();
}

class _PairingCodeLoginPageState extends State<PairingCodeLoginPage> {
  final TextEditingController _codeController = TextEditingController();
  final BackendApiService _api = BackendApiService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Kode harus 6 digit.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _api.redeemPairingCode(code);
      final email = result['email'] as String;
      final password = result['password'] as String;

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const RoleGate(),
        ),
            (route) => false,
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Perangkat Lansia')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smartphone, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Minta wali generate kode setup dari app-nya, lalu masukkan di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(),
                hintText: '000000',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Hubungkan', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}