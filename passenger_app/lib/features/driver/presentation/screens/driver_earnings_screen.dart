import 'package:flutter/material.dart';
import '../../data/driver_repository.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final DriverRepository _repo = DriverRepository();
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final earnings = await _repo.getEarnings();
      setState(() => _data = earnings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('No data'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Total: ETB ${_data!['total_earnings']}'),
                      Text('Trips: ${_data!['count']}'),
                      const Divider(height: 24),
                      Expanded(
                        child: ListView.builder(
                          itemCount: (_data!['items'] as List).length,
                          itemBuilder: (context, i) {
                            final item = _data!['items'][i] as Map<String, dynamic>;
                            return ListTile(
                              title: Text('Ride #${item['ride_id']}'),
                              subtitle: Text('Earnings: ETB ${item['driver_earnings']}'),
                              trailing: Text(item['payment_status'] ?? ''),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}


