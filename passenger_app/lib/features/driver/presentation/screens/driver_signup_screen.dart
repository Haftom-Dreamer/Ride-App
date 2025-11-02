import 'package:flutter/material.dart';
import '../../data/driver_repository.dart';
import '../../../auth/presentation/screens/driver_auth_screen.dart';

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vehicleDetailsController = TextEditingController();
  final _plateController = TextEditingController();
  final _licenseController = TextEditingController();
  final DriverRepository _repo = DriverRepository();
  String _vehicleType = 'Bajaj';
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _vehicleDetailsController.dispose();
    _plateController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await _repo.signupDriver(
        name: _nameController.text.trim(),
        phoneNumber: _formatPhone(_phoneController.text.trim()),
        password: _passwordController.text,
        vehicleType: _vehicleType,
        vehicleDetails: _vehicleDetailsController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        plateNumber: _plateController.text.trim().isEmpty 
            ? null 
            : _plateController.text.trim(),
        licenseInfo: _licenseController.text.trim().isEmpty 
            ? null 
            : _licenseController.text.trim(),
      );
      if (!mounted) return;
      final driverId = res['driver_id'];
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Signup Submitted'),
          content: Text('Your Driver ID is $driverId. An admin will approve your account shortly.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DriverAuthScreen()),
                );
              },
              child: const Text('Continue'),
            )
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPhone(String input) {
    if (input.startsWith('+251')) return input;
    if (input.startsWith('251')) return '+$input';
    if (input.startsWith('0')) return '+251${input.substring(1)}';
    return '+251$input';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Signup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number (e.g., 0912345678)'),
                validator: (v) => v == null || v.trim().length < 9 ? 'Invalid phone' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (Optional)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Invalid email format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Password is required';
                  }
                  if (v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _vehicleType,
                items: const [
                  DropdownMenuItem(value: 'Bajaj', child: Text('Bajaj')),
                  DropdownMenuItem(value: 'Car', child: Text('Car')),
                  DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                ],
                onChanged: (v) => setState(() => _vehicleType = v ?? 'Bajaj'),
                decoration: const InputDecoration(labelText: 'Vehicle Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleDetailsController,
                decoration: const InputDecoration(labelText: 'Vehicle Details (e.g., Toyota Vitz White)'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Plate Number (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: 'License Info (optional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign Up as Driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




