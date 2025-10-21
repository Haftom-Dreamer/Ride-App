# RIDE Passenger App

A Flutter-based ride-hailing passenger app with Gebeta Maps integration.

## Features

- **Authentication**: Login/Signup with email and password
- **Interactive Map**: Real-time location tracking with Gebeta Maps tiles
- **Ride Request**: Select pickup and destination locations
- **Vehicle Selection**: Choose between Bajaj and Car options
- **Real-time Updates**: Track ride status and driver location

## Setup

### Prerequisites

1. **Flutter SDK** (3.24+)
2. **Android SDK** (Command Line Tools)
3. **Java JDK 17** (Temurin recommended)
4. **VS Code/Cursor** with Flutter extension

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd passenger_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure environment variables:
```bash
# Development
flutter run --dart-define="API_BASE_URL=http://127.0.0.1:5000/api" --dart-define="GEBETA_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png"

# Production
flutter run --dart-define="API_BASE_URL=https://your-api-host.com/api" --dart-define="GEBETA_TILE_URL=https://your-gebeta-tiles.com/{z}/{x}/{y}.png" --dart-define="GEBETA_API_KEY=your-api-key"
```

### Running the App

1. **Connect Android device** via USB with USB debugging enabled
2. **Run the app**:
```bash
flutter run
```

3. **Select your device** when prompted

### Building for Release

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (recommended for Play Store)
flutter build appbundle --release
```

## Architecture

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── constants/       # App constants
│   ├── utils/          # Utility functions
│   └── widgets/        # Reusable widgets
├── features/
│   ├── auth/           # Authentication feature
│   │   ├── data/       # Auth repository
│   │   ├── domain/     # Auth models
│   │   └── presentation/ # Auth screens & providers
│   ├── ride/           # Ride feature
│   │   ├── data/       # Ride repository
│   │   ├── domain/     # Ride models
│   │   └── presentation/ # Ride screens & widgets
│   └── profile/        # Profile feature
└── shared/
    ├── data/           # Shared data layer
    ├── domain/         # Shared models
    └── presentation/   # Shared widgets
```

## API Integration

The app integrates with your existing Flask API:

- **Authentication**: `/api/passenger/login`, `/api/passenger/signup`
- **Ride Management**: `/api/ride-request`, `/api/ride-status/{id}`
- **Fare Estimation**: `/api/fare-estimate`
- **Rating**: `/api/rate-ride`

## Maps Integration

- **Tile Provider**: Gebeta Maps (configurable via `GEBETA_TILE_URL`)
- **Geocoding**: Backend integration (server-side geocoding)
- **Routing**: Server-side OSRM integration
- **Location Services**: GPS tracking with permission handling

## State Management

Uses **Riverpod** for state management:
- `AuthProvider`: User authentication state
- `RideProvider`: Ride request and tracking state
- `LocationProvider`: GPS location state

## Development

### Adding New Features

1. Create feature folder: `lib/features/your_feature/`
2. Add data, domain, and presentation layers
3. Create providers for state management
4. Add screens and widgets

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Troubleshooting

### Common Issues

1. **"No devices found"**: Ensure USB debugging is enabled on your Android device
2. **"Gradle build failed"**: Check Android SDK installation and Java version
3. **"API connection failed"**: Verify API_BASE_URL and network connectivity

### Debug Commands

```bash
# Check Flutter installation
flutter doctor

# List connected devices
flutter devices

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Production Deployment

1. **Configure production API endpoints**
2. **Set up Gebeta Maps credentials**
3. **Build release APK/AAB**
4. **Test on multiple devices**
5. **Deploy to Google Play Store**

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

[Add your license information here]