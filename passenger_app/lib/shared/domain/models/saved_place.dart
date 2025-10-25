class SavedPlace {
  final int? id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;

  const SavedPlace({
    this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id'] as int?,
      label: json['label'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  SavedPlace copyWith({
    int? id,
    String? label,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedPlace && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SavedPlace(id: $id, label: $label, address: $address)';
  }
}


