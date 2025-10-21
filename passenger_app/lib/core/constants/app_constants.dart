class AppConstants {
  // Storage keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String lastLocationKey = 'last_location';
  static const String savedPlacesKey = 'saved_places';
  
  // API response keys
  static const String successKey = 'success';
  static const String errorKey = 'error';
  static const String messageKey = 'message';
  static const String dataKey = 'data';
  
  // Ride statuses
  static const String rideStatusRequested = 'Requested';
  static const String rideStatusAssigned = 'Assigned';
  static const String rideStatusOnTrip = 'On Trip';
  static const String rideStatusCompleted = 'Completed';
  static const String rideStatusCancelled = 'Cancelled';
  
  // Vehicle types
  static const String vehicleTypeBajaj = 'Bajaj';
  static const String vehicleTypeCar = 'Car';
  
  // Payment methods
  static const String paymentCash = 'Cash';
  static const String paymentMobileMoney = 'Mobile Money';
  static const String paymentCard = 'Card';
  
  // Map settings
  static const double minZoom = 8.0;
  static const double maxZoom = 18.0;
  static const double defaultZoom = 12.0;
  
  // Location settings
  static const double locationAccuracyThreshold = 10.0; // meters
  static const Duration locationUpdateInterval = Duration(seconds: 5);
  
  // Polling intervals
  static const Duration rideStatusPollInterval = Duration(seconds: 3);
  static const Duration driverLocationPollInterval = Duration(seconds: 5);
  
  // UI constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double buttonHeight = 48.0;
}

