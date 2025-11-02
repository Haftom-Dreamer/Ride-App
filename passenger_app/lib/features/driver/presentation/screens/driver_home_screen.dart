import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/driver_repository.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final DriverRepository _repo = DriverRepository();
  bool _online = false;
  Timer? _locationTimer;
  bool _updating = false;
  String? _driverName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _repo.getProfile();
      if (mounted) {
        setState(() {
          _driverName = p['name'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleOnline(bool v) async {
    setState(() => _updating = true);
    try {
      await _repo.setAvailability(v);
      setState(() => _online = v);
      _startOrStopLocation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _startOrStopLocation() {
    _locationTimer?.cancel();
    if (_online) {
      _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pushLocation());
      _pushLocation();
    }
  }

  Future<void> _pushLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _repo.updateLocation(lat: pos.latitude, lon: pos.longitude);
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_driverName != null ? 'Hi, $_driverName' : 'Driver'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  _online ? Icons.toggle_on : Icons.toggle_off,
                  color: _online ? Colors.green : Colors.grey,
                  size: 32,
                ),
                title: const Text('Availability'),
                subtitle: Text(_online ? 'Online' : 'Offline'),
                trailing: Switch(value: _online, onChanged: _updating ? null : _toggleOnline),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When Online, your location is sent every 5s so dispatch can offer trips.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}




