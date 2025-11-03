enum UserRole { passenger, driver }

class User {
  final int id;
  final String username;
  final String email;
  final String phoneNumber;
  final String? passengerUid;
  final String? driverUid;
  final String? profilePicture;
  final DateTime? createdAt;
  final bool isActive;
  final UserRole role;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.phoneNumber,
    this.passengerUid,
    this.driverUid,
    this.profilePicture,
    this.createdAt,
    this.isActive = true,
    this.role = UserRole.passenger,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Determine role based on presence of passenger_uid or driver_uid
    UserRole role = UserRole.passenger;
    if (json['driver_uid'] != null || json['role'] == 'driver') {
      role = UserRole.driver;
    } else if (json['passenger_uid'] != null || json['role'] == 'passenger') {
      role = UserRole.passenger;
    }
    
    return User(
      id: json['id'] as int,
      username: json['username'] as String? ?? json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String,
      passengerUid: json['passenger_uid'] as String?,
      driverUid: json['driver_uid'] as String?,
      profilePicture: json['profile_picture'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      role: role,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'passenger_uid': passengerUid,
      'driver_uid': driverUid,
      'profile_picture': profilePicture,
      'created_at': createdAt?.toIso8601String(),
      'is_active': isActive,
      'role': role == UserRole.driver ? 'driver' : 'passenger',
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? phoneNumber,
    String? passengerUid,
    String? driverUid,
    String? profilePicture,
    DateTime? createdAt,
    bool? isActive,
    UserRole? role,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      passengerUid: passengerUid ?? this.passengerUid,
      driverUid: driverUid ?? this.driverUid,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, phoneNumber: $phoneNumber)';
  }
}
