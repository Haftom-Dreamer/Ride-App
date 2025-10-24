class User {
  final int id;
  final String username;
  final String email;
  final String phoneNumber;
  final String? passengerUid;
  final String? profilePicture;
  final DateTime? createdAt;
  final bool isActive;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.phoneNumber,
    this.passengerUid,
    this.profilePicture,
    this.createdAt,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      phoneNumber: json['phone_number'] as String,
      passengerUid: json['passenger_uid'] as String?,
      profilePicture: json['profile_picture'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'passenger_uid': passengerUid,
      'profile_picture': profilePicture,
      'created_at': createdAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? phoneNumber,
    String? passengerUid,
    String? profilePicture,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      passengerUid: passengerUid ?? this.passengerUid,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
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
