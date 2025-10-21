class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000/api',
  );
  
  static const String gebetaTileUrl = String.fromEnvironment(
    'GEBETA_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  
  static const String gebetaApiKey = String.fromEnvironment(
    'GEBETA_API_KEY',
    defaultValue: '',
  );
  
  static const String appName = 'RIDE Passenger';
  static const String appVersion = '1.0.0';
  
  // API endpoints
  static const String loginEndpoint = '/passenger/login';
  static const String signupEndpoint = '/passenger/signup';
  static const String logoutEndpoint = '/passenger/logout';
  static const String fareEstimateEndpoint = '/fare-estimate';
  static const String rideRequestEndpoint = '/ride-request';
  static const String rideStatusEndpoint = '/ride-status';
  static const String rateRideEndpoint = '/rate-ride';
  
  // Map settings
  static const double defaultLatitude = 9.0192; // Addis Ababa
  static const double defaultLongitude = 38.7525;
  static const double defaultZoom = 12.0;
  
  // Request timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}

