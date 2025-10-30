import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/saved_places_provider.dart';
import '../../../../shared/domain/models/saved_place.dart';

class SavedPlacesScreen extends ConsumerStatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _isAdding = false;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedPlacesState = ref.watch(savedPlacesProvider);
    final savedPlacesNotifier = ref.read(savedPlacesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Places'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _isAdding = true;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isAdding) _buildAddPlaceForm(savedPlacesNotifier),
          Expanded(
            child: savedPlacesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : savedPlacesState.places.isEmpty
                    ? _buildEmptyState()
                    : _buildPlacesList(
                        savedPlacesState.places, savedPlacesNotifier),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPlaceForm(SavedPlacesNotifier notifier) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Place',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Label
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (e.g., Home, Work)',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Label is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Coordinates
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.my_location),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Latitude is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid latitude';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.my_location),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Longitude is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid longitude';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isAdding = false;
                          _labelController.clear();
                          _addressController.clear();
                          _latitudeController.clear();
                          _longitudeController.clear();
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          notifier.addSavedPlace(
                            label: _labelController.text.trim(),
                            address: _addressController.text.trim(),
                            latitude: double.parse(_latitudeController.text),
                            longitude: double.parse(_longitudeController.text),
                          );

                          setState(() {
                            _isAdding = false;
                            _labelController.clear();
                            _addressController.clear();
                            _latitudeController.clear();
                            _longitudeController.clear();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Place'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Saved Places',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your frequently visited places for quick booking',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isAdding = true;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add First Place'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList(
      List<SavedPlace> places, SavedPlacesNotifier notifier) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                _getPlaceIcon(place.label),
                color: Colors.blue.shade700,
              ),
            ),
            title: Text(
              place.label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(place.address),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _showDeleteDialog(place, notifier);
              },
            ),
            onTap: () {
              // TODO: Use this place for ride booking
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected ${place.label} for ride booking'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getPlaceIcon(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('home')) return Icons.home;
    if (lowerLabel.contains('work') || lowerLabel.contains('office')) {
      return Icons.work;
    }
    if (lowerLabel.contains('school') || lowerLabel.contains('university')) {
      return Icons.school;
    }
    if (lowerLabel.contains('hospital') || lowerLabel.contains('clinic')) {
      return Icons.local_hospital;
    }
    if (lowerLabel.contains('gym') || lowerLabel.contains('fitness')) {
      return Icons.fitness_center;
    }
    return Icons.place;
  }

  void _showDeleteDialog(SavedPlace place, SavedPlacesNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Place'),
        content: Text('Are you sure you want to delete "${place.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (place.id != null) {
                notifier.deleteSavedPlace(place.id!);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
