import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/data/api_client.dart';
import '../../../driver/presentation/screens/driver_home_screen.dart';
import '../../../driver/data/driver_repository.dart';

class DriverAuthScreen extends ConsumerStatefulWidget {
  const DriverAuthScreen({super.key});

  @override
  ConsumerState<DriverAuthScreen> createState() => _DriverAuthScreenState();
}

class _DriverAuthScreenState extends ConsumerState<DriverAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DriverRepository _repo = DriverRepository();
  final ImagePicker _picker = ImagePicker();

  // Login form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _loginLoading = false;

  // Signup form
  final _signupFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vehicleDetailsController = TextEditingController();
  final _plateController = TextEditingController();
  final _licenseController = TextEditingController();
  String _vehicleType = 'Bajaj';
  bool _obscureSignupPassword = true;
  bool _signupLoading = false;

  // File uploads
  XFile? _profilePicture;
  XFile? _licenseDocument;
  XFile? _vehicleDocument;
  XFile? _platePhoto;
  XFile? _idDocument;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _vehicleDetailsController.dispose();
    _plateController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, Function(XFile?) onPicked) async {
    try {
      final image = await _picker.pickImage(source: source);
      onPicked(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _loginDriver() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loginLoading = true);
    try {
      final res = await _repo.loginDriver(
        identifier: _loginIdentifierController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      
      await ApiClient().setUserId(res['driver_id']);
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString().replaceAll('AuthException: ', '').replaceAll('NetworkException: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  Future<void> _signupDriver() async {
    if (!_signupFormKey.currentState!.validate()) return;
    setState(() => _signupLoading = true);
    try {
      final res = await _repo.signupDriver(
        name: _nameController.text.trim(),
        phoneNumber: _formatPhone(_phoneController.text.trim()),
        password: _passwordController.text,
        vehicleType: _vehicleType,
        vehicleDetails: _vehicleDetailsController.text.trim(),
        email: _emailController.text.trim(),
        plateNumber: _plateController.text.trim(),
        licenseInfo: _licenseController.text.trim(),
        profilePicture: _profilePicture,
        licenseDocument: _licenseDocument,
        vehicleDocument: _vehicleDocument,
        platePhoto: _platePhoto,
        idDocument: _idDocument,
      );
      if (!mounted) return;
      final driverUid = res['driver_uid'] ?? res['driver_id'].toString();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Signup Submitted'),
          content: Text(
              'Your Driver ID is $driverUid. An admin will review your documents and approve your account shortly.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _tabController.animateTo(0); // Switch to login tab
                _loginIdentifierController.text = driverUid;
              },
              child: const Text('Continue to Login'),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup failed: ${e.toString().replaceAll('NetworkException: ', '').replaceAll('AuthException: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _signupLoading = false);
    }
  }

  String _formatPhone(String input) {
    if (input.startsWith('+251')) return input;
    if (input.startsWith('251')) return '+$input';
    if (input.startsWith('0')) return '+251${input.substring(1)}';
    return '+251$input';
  }

  Widget _buildFileUploadButton(
    String label,
    XFile? file,
    IconData icon,
    Function(XFile?) onFilePicked,
  ) {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, onFilePicked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, onFilePicked);
                },
              ),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file != null ? file.name : label,
                style: TextStyle(
                  color: file != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            if (file != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => onFilePicked(null),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sign In', icon: Icon(Icons.login)),
            Tab(text: 'Sign Up', icon: Icon(Icons.person_add)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Login Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _loginFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Icon(
                    Icons.directions_car,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Driver Sign In',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your Phone or Driver ID and password',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _loginIdentifierController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number or Driver ID',
                      prefixIcon: Icon(Icons.badge),
                      helperText: 'Enter your phone number or Driver ID',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your phone or Driver ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _loginPasswordController,
                    obscureText: _obscureLoginPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureLoginPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureLoginPassword = !_obscureLoginPassword;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loginLoading ? null : _loginDriver,
                    child: _loginLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Signup Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _signupFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Icon(
                    Icons.person_add,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Become a Driver',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in your details and upload required documents',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone),
                      helperText: 'e.g., 0912345678',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 9) {
                        return 'Invalid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscureSignupPassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureSignupPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureSignupPassword = !_obscureSignupPassword;
                          });
                        },
                      ),
                      helperText: 'Minimum 6 characters',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _vehicleType,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type *',
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Bajaj', child: Text('Bajaj')),
                      DropdownMenuItem(value: 'Car', child: Text('Car')),
                      DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                    ],
                    onChanged: (v) =>
                        setState(() => _vehicleType = v ?? 'Bajaj'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleDetailsController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Details *',
                      prefixIcon: Icon(Icons.info),
                      helperText: 'e.g., Toyota Vitz White',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _plateController,
                    decoration: const InputDecoration(
                      labelText: 'Plate Number',
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'License Number',
                      prefixIcon: Icon(Icons.card_membership),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Document Uploads',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildFileUploadButton(
                    'Profile Picture (Optional)',
                    _profilePicture,
                    Icons.person,
                    (file) => setState(() => _profilePicture = file),
                  ),
                  const SizedBox(height: 12),
                  _buildFileUploadButton(
                    'License Document *',
                    _licenseDocument,
                    Icons.card_membership,
                    (file) => setState(() => _licenseDocument = file),
                  ),
                  const SizedBox(height: 12),
                  _buildFileUploadButton(
                    'Vehicle Registration *',
                    _vehicleDocument,
                    Icons.description,
                    (file) => setState(() => _vehicleDocument = file),
                  ),
                  const SizedBox(height: 12),
                  _buildFileUploadButton(
                    'Plate Photo *',
                    _platePhoto,
                    Icons.camera_alt,
                    (file) => setState(() => _platePhoto = file),
                  ),
                  const SizedBox(height: 12),
                  _buildFileUploadButton(
                    'ID Document *',
                    _idDocument,
                    Icons.credit_card,
                    (file) => setState(() => _idDocument = file),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _signupLoading ? null : _signupDriver,
                    child: _signupLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Register as Driver',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
