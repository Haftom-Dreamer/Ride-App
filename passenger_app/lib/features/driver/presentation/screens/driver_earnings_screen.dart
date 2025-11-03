import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/driver_repository.dart';

enum EarningsPeriod { today, thisWeek, thisMonth, custom }

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final DriverRepository _repo = DriverRepository();
  bool _loading = true;
  Map<String, dynamic>? _data;
  EarningsPeriod _selectedPeriod = EarningsPeriod.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case EarningsPeriod.today:
        final today = DateTime(now.year, now.month, now.day);
        return DateFormat('yyyy-MM-dd').format(today);
      case EarningsPeriod.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateFormat('yyyy-MM-dd').format(DateTime(weekStart.year, weekStart.month, weekStart.day));
      case EarningsPeriod.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return DateFormat('yyyy-MM-dd').format(monthStart);
      case EarningsPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return '${DateFormat('yyyy-MM-dd').format(_customStartDate!)}_${DateFormat('yyyy-MM-dd').format(_customEndDate!)}';
        }
        return null;
    }
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case EarningsPeriod.today:
        return 'Today';
      case EarningsPeriod.thisWeek:
        return 'This Week';
      case EarningsPeriod.thisMonth:
        return 'This Month';
      case EarningsPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d').format(_customEndDate!)}';
        }
        return 'Custom Range';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dateRange = _getDateRange();
      String? fromDate, toDate;
      
      if (dateRange != null && dateRange.contains('_')) {
        final parts = dateRange.split('_');
        fromDate = parts[0];
        toDate = parts.length > 1 ? parts[1] : null;
      } else if (dateRange != null) {
        fromDate = dateRange;
      }
      
      final earnings = await _repo.getEarnings(from: fromDate, to: toDate);
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

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedPeriod = EarningsPeriod.custom;
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalEarnings = _data != null ? (_data!['total_earnings'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final tripCount = _data != null ? (_data!['count'] as int?) ?? 0 : 0;
    final items = _data != null ? (_data!['items'] as List?) ?? [] : [];
    final averageEarnings = tripCount > 0 ? totalEarnings / tripCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Period',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildPeriodChip(EarningsPeriod.today, 'Today'),
                                _buildPeriodChip(EarningsPeriod.thisWeek, 'This Week'),
                                _buildPeriodChip(EarningsPeriod.thisMonth, 'This Month'),
                                _buildPeriodChip(EarningsPeriod.custom, 'Custom'),
                              ],
                            ),
                            if (_selectedPeriod == EarningsPeriod.custom)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: OutlinedButton.icon(
                                  onPressed: _selectCustomDateRange,
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(_getPeriodLabel()),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    'ETB ${totalEarnings.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total Earnings',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    tripCount.toString(),
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total Rides',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (tripCount > 0)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'ETB ${averageEarnings.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'Average per Ride',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    
                    // Trip List
                    Text(
                      'Trip History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No earnings for this period',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...items.map((item) {
                        final itemMap = item as Map<String, dynamic>;
                        final rideId = itemMap['ride_id'] as int? ?? 0;
                        final earnings = itemMap['driver_earnings'] as num?;
                        final earningsStr = earnings != null ? 'ETB ${earnings.toStringAsFixed(2)}' : 'N/A';
                        final paymentStatus = itemMap['payment_status'] as String? ?? 'Pending';
                        final rideDate = itemMap['ride_date'] as String?;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getPaymentStatusColor(paymentStatus).withOpacity(0.1),
                              child: Icon(
                                Icons.local_taxi,
                                color: _getPaymentStatusColor(paymentStatus),
                              ),
                            ),
                            title: Text(
                              'Ride #$rideId',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Earnings: $earningsStr'),
                                if (rideDate != null)
                                  Text(
                                    rideDate,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                              ],
                            ),
                            trailing: Chip(
                              label: Text(
                                paymentStatus,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: _getPaymentStatusColor(paymentStatus).withOpacity(0.1),
                              side: BorderSide(
                                color: _getPaymentStatusColor(paymentStatus),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodChip(EarningsPeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = period;
            if (period != EarningsPeriod.custom) {
              _customStartDate = null;
              _customEndDate = null;
            }
          });
          _load();
        }
      },
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}


