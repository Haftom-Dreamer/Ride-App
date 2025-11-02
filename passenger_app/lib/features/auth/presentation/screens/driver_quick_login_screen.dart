import 'package:flutter/material.dart';
import '../../../../shared/data/api_client.dart';
import '../../../driver/presentation/screens/driver_home_screen.dart';

class DriverQuickLoginScreen extends StatefulWidget {
  const DriverQuickLoginScreen({super.key});

  @override
  State<DriverQuickLoginScreen> createState() => _DriverQuickLoginScreenState();
}

class _DriverQuickLoginScreenState extends State<DriverQuickLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final id = int.parse(_idController.text.trim());
      await ApiClient().setUserId(id);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              TextFormField(
                controller: _idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Driver ID',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter driver id';
                  if (int.tryParse(v.trim()) == null) return 'Invalid id';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _continue,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


