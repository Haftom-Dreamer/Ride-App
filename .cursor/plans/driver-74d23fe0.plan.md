<!-- 74d23fe0-f6b8-4a06-9b0b-1a216a6c3034 91b07055-715e-4c3b-a835-646fa2903805 -->
# Complete Driver App Implementation Plan

## Overview

Transform the current minimal driver home screen (which only has an availability toggle) into a complete driver application with full navigation, ride offers, active trip management, earnings tracking, chat, and profile management.

## Current State

- Driver home screen only shows availability toggle
- Driver repository has methods for profile, availability, location, earnings
- Backend APIs exist for ride offers, trip status updates, chat, earnings
- No driver navigation structure exists
- Main app routes all authenticated users to passenger screens

## Implementation Tasks

### 1. Driver Navigation Structure

**File:** `passenger_app/lib/features/driver/presentation/screens/driver_main_screen.dart` (new)

- Create a bottom navigation bar similar to passenger app
- Tabs: Home, Earnings, Profile
- Check user role from auth state and route accordingly
- Handle driver-specific navigation

**Files to modify:**

- `passenger_app/lib/main.dart`: Update `AuthWrapper` to route to `DriverMainScreen` if user is a driver
- `passenger_app/lib/features/auth/presentation/providers/auth_provider.dart`: Ensure user role is stored in auth state

### 2. Enhanced Driver Home Screen

**File:** `passenger_app/lib/features/driver/presentation/screens/driver_home_screen.dart`

**Current:** Only shows availability toggle

**Updates needed:**

- Add header showing driver name, rating, today's earnings summary
- Show active trip card if driver is on trip (with arrive/start/end buttons)
- Display incoming ride offers (realtime via WebSocket/polling)
- Add quick stats: today's rides, today's earnings
- Show availability toggle (existing functionality)
- Add map view showing driver location when online

**Components to add:**

- `ActiveTripCard`: Shows current trip details with action buttons
- `RideOfferCard`: Shows incoming ride offers with accept/decline
- `TodayEarningsWidget`: Quick earnings summary
- `DriverStatsWidget`: Ride count, rating display

### 3. Ride Offers System (Notifications + List View)

**File:** `passenger_app/lib/features/driver/presentation/screens/driver_offer_dialog.dart` (exists, needs enhancement)

**File:** `passenger_app/lib/features/driver/presentation/screens/available_rides_screen.dart` (new)

**File:** `passenger_app/lib/features/driver/presentation/providers/ride_offer_provider.dart` (new)

**Notification System:**

- Listen for urgent ride offers via WebSocket or polling
- Show modal dialog when urgent offer arrives (priority rides, nearby rides)
- Display pickup/destination, distance, fare estimate, passenger rating
- Accept/Decline functionality with expiration countdown
- Sound/vibration notification for incoming offers
- Show "Accept" and "Decline" buttons in dialog

**List View System:**

- New tab/section: "Available Rides" on home screen
- Browse all available rides that need drivers
- Filter by distance, fare, pickup location
- Sort by distance (nearest first), fare (highest first), time requested
- Pull-to-refresh for updated ride list
- Show ride cards with: pickup/destination, distance, estimated fare, passenger rating, time requested
- Tap ride card to view full details and accept/decline
- Real-time updates when rides are accepted by other drivers or cancelled

**Files to modify:**

- `passenger_app/lib/features/driver/data/driver_repository.dart`: Add methods for:
  - `getAvailableRides()` - Fetch list of available rides
  - `acceptRideOffer(int rideId)` - Accept from notification or list
  - `declineRideOffer(int rideId)` - Decline offer
- `passenger_app/lib/features/driver/presentation/screens/driver_home_screen.dart`: Add "Available Rides" section with link to full list view

### 4. Active Trip Management

**File:** `passenger_app/lib/features/driver/presentation/screens/active_trip_screen.dart` (new)

- Show trip details: passenger info, pickup/destination, fare
- Action buttons: "Mark Arrived", "Start Trip", "End Trip"
- Navigation button (deep link to external maps)
- Chat button to communicate with passenger
- Real-time location tracking while on trip

**Components:**

- `TripActionsWidget`: Arrive/Start/End buttons
- `PassengerInfoCard`: Show passenger details
- `TripMapWidget`: Show route and locations

### 5. Earnings Screen Enhancement

**File:** `passenger_app/lib/features/driver/presentation/screens/driver_earnings_screen.dart` (exists)

**Updates:**

- Add date range selector (today, this week, this month, custom)
- Show detailed breakdown: daily, weekly, monthly earnings
- Display trip list with earnings per trip
- Add export functionality
- Show charts/graphs for earnings trends
- Display total rides, average fare, total earnings

### 6. Driver Profile Screen

**File:** `passenger_app/lib/features/driver/presentation/screens/driver_profile_screen.dart` (new)

- Display driver information: name, phone, email, vehicle details
- Show rating and total rides
- Edit profile functionality
- Document management (view uploaded documents)
- Settings: notifications, location sharing preferences
- Logout functionality

### 7. Chat Integration

**File:** `passenger_app/lib/features/driver/presentation/screens/driver_chat_screen.dart` (new)

- Real-time chat during active trip
- Message history
- Send/receive messages via WebSocket
- Show passenger info in header

**Files to modify:**

- `passenger_app/lib/features/driver/data/driver_repository.dart`: Add chat methods
- Integrate with existing WebSocket chat infrastructure

### 8. WebSocket Integration for Real-time Updates

**File:** `passenger_app/lib/features/driver/data/driver_websocket_service.dart` (new)

- Connect to WebSocket server
- Listen for ride offers
- Listen for ride status updates
- Handle chat messages
- Reconnect logic

**Files to modify:**

- Update `driver_home_screen.dart` to use WebSocket service
- Update `driver_offer_dialog.dart` to receive real-time offers

### 9. Navigation Integration

**File:** `passenger_app/lib/features/driver/presentation/widgets/navigation_button.dart` (new)

- Button to open external maps (Google Maps, Waze)
- Deep link with pickup/destination coordinates
- Fallback to URL launcher if maps app not available

### 10. Update Repository Methods

**File:** `passenger_app/lib/features/driver/data/driver_repository.dart`

**Add methods:**

- `acceptRideOffer(int offerId)`
- `declineRideOffer(int offerId)`
- `markArrived(int rideId)`
- `startTrip(int rideId)`
- `endTrip(int rideId)`
- `getActiveRide()`
- `getChatMessages(int rideId)`
- `sendChatMessage(int rideId, String message)`

### 11. State Management

**File:** `passenger_app/lib/features/driver/presentation/providers/driver_provider.dart` (new)

- Manage driver state (availability, active trip, location)
- Provide driver data to all screens
- Handle state updates from WebSocket

### 12. Authentication Role Detection

**Files to modify:**

- `passenger_app/lib/features/auth/presentation/providers/auth_provider.dart`: Store user role (passenger/driver) in auth state
- `passenger_app/lib/main.dart`: Route to appropriate main screen based on role
- `passenger_app/lib/features/auth/presentation/screens/login_screen.dart`: Handle driver login and store role

## Technical Details

### WebSocket Integration

- Use existing Socket.IO client or implement native WebSocket
- Events to listen for: `ride_offer`, `ride_status_update`, `chat_message`
- Events to emit: `accept_offer`, `decline_offer`, `trip_status_update`

### Map Integration

- Use existing `MapWidget` from passenger app if applicable
- Or use `flutter_map` for driver location display
- Integrate with `Geolocator` for location updates

### State Management

- Use Riverpod providers for driver state
- Real-time updates via WebSocket service
- Persist driver availability state

## Files Structure

```
passenger_app/lib/features/driver/
├── data/
│   ├── driver_repository.dart (update)
│   └── driver_websocket_service.dart (new)
├── presentation/
│   ├── providers/
│   │   ├── driver_provider.dart (new)
│   │   └── ride_offer_provider.dart (new)
│   ├── screens/
│   │   ├── driver_main_screen.dart (new)
│   │   ├── driver_home_screen.dart (update)
│   │   ├── driver_earnings_screen.dart (update)
│   │   ├── driver_profile_screen.dart (new)
│   │   ├── active_trip_screen.dart (new)
│   │   ├── driver_chat_screen.dart (new)
│   │   └── driver_offer_dialog.dart (update)
│   └── widgets/
│       ├── active_trip_card.dart (new)
│       ├── ride_offer_card.dart (new)
│       ├── today_earnings_widget.dart (new)
│       ├── driver_stats_widget.dart (new)
│       └── navigation_button.dart (new)
```

## Testing Considerations

- Test driver login and role detection
- Test availability toggle
- Test ride offer acceptance/decline
- Test active trip flow (arrive -> start -> end)
- Test earnings display with different date ranges
- Test chat functionality during active trip
- Test WebSocket reconnection handling
- Test navigation deep linking to external maps

## Priority Order

1. Driver navigation structure and routing
2. Enhanced home screen with active trip and stats
3. Ride offers system
4. Active trip management
5. Earnings screen enhancement
6. Profile screen
7. Chat integration
8. WebSocket real-time updates