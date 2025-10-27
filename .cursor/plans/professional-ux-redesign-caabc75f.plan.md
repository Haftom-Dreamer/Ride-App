<!-- caabc75f-8eab-4edb-9ee0-30a82714027b fb8100ef-4c31-493a-b12c-80a0d621e541 -->
# Professional Ride-Sharing App UX Plan

## Design System & Branding

### Color Palette

- **Primary Blue**: #2563EB (brand color - buttons, active states)
- **Dark Blue**: #1E40AF (headers, important text)
- **Light Blue**: #DBEAFE (backgrounds, subtle highlights)
- **White**: #FFFFFF (cards, bottom sheets)
- **Gray Scale**: #F3F4F6, #9CA3AF, #4B5563 (text hierarchy)
- **Success Green**: #10B981 (confirmations)
- **Warning Orange**: #F59E0B (alerts)
- **Error Red**: #EF4444 (errors, cancellations)

### Typography

- **Headers**: Bold, 24-28px
- **Body**: Regular, 16px
- **Labels**: Medium, 14px
- **Caption**: Regular, 12px

## Location Data Setup

### Region Focus: Tigray (Mekelle & Adigrat)

- **Default Map Center**: Mekelle (13.4967° N, 39.4753° E)
- **Zoom Level**: 13-15 for city view
- **Key Locations** (hardcoded for easy access):
- Mekelle: Hawelti, Adi Haki, Quiha, Kedamay Weyane, Ayder
- Adigrat: Downtown, Agazi, Edaga Selam
- **Saved Places Categories**:
- Home
- Work
- Mekelle Airport
- Ayder Hospital
- Mekelle University
- Bus Stations (Mekelle, Adigrat)

## Step-by-Step User Experience Flow

### 1. Home Screen (Initial State)

**Goal**: Get user booking a ride in 2-3 taps

**Layout**:

- **Top Bar** (fixed):
- User avatar (left)
- "Ride" title (center)
- Notification bell (right)
- **Map** (70% screen):
- Fixed green pin in center
- Current location indicator (blue dot)
- "Move map to set pickup" text overlay at top
- **Draggable Bottom Sheet** (30% initial, 90% max):
- Drag handle (gray bar)
- **Quick Actions Section**:
- "Where to?" search bar (tap to expand sheet)
- 2 saved places cards (Home, Work) with icons
- 2 recent trips with small location icons
- Each card shows: icon, name, address snippet, estimated time
- **Bottom Navigation** (fixed):
- Home (active - blue)
- My Trips
- Messages
- Profile

### 2. Destination Search (Sheet Expanded to 90%)

**Triggered**: User taps "Where to?" or pulls sheet up

**Layout**:

- **Header**:
- Back arrow (collapses sheet)
- "Select Destination" title
- **Search Section**:
- FROM field (pre-filled with pickup location, editable)
- TO field (active, keyboard open)
- Swap button between fields
- **Suggestions List**:
- Popular locations in Mekelle/Adigrat
- Recent searches
- Saved places
- Real-time search results as user types
- **Footer**:
- "Set pin on map" button (collapses sheet, lets user tap map)

### 3. Ride Configuration (Sheet at 70%)

**Triggered**: Destination selected

**Layout**:

- **Map View**:
- Route line (blue) between pickup and destination
- Both location pins visible
- ETA and distance overlay at top
- **Bottom Sheet**:
- **Trip Summary Card**:
- Pickup address (truncated)
- Destination address (truncated)
- Distance and time estimate
- **Vehicle Selection** (horizontal scroll):
- Economy (Bajaj) - ETB 30-50
- Standard (Car) - ETB 50-80
- Premium (SUV) - ETB 80-120
- Each card: icon, name, ETA, price, capacity
- **Payment Method**:
- Selected method (Cash/Mobile Money)
- Change button
- **Request Ride Button** (full-width, blue):
- "Request [Vehicle Type] - ETB [Price]"

### 4. Finding Driver (Searching State)

**Layout**:

- **Map**:
- Route line visible
- Pickup and destination pins
- Animated "searching" overlay
- **Bottom Sheet** (40% height, not draggable during search):
- Loading animation
- "Finding nearby drivers..."
- Estimated wait time
- "Cancel Request" button (text, red)

### 5. Driver Assigned (Match Found)

**Layout**:

- **Map**:
- Route line
- Driver's current location (moving car icon)
- Pickup location pin
- Driver ETA line from driver to pickup
- **Bottom Sheet** (50% height):
- **Driver Card**:
- Photo (left)
- Name, rating (4.8★), total trips
- Vehicle: Make, model, plate number
- Color indicator
- **Arrival Info**:
- "Arriving in X min"
- Progress indicator
- **Actions Row**:
- Call driver button (blue)
- Message button (outlined)
- Cancel ride button (text, small)
- **Trip Details** (collapsible):
- Pickup location
- Destination
- Estimated fare

### 6. Driver Arriving / On Trip

**Layout**:

- **Map** (full screen behind sheet):
- Real-time driver location
- Route path
- Your location (blue dot)
- **Bottom Sheet** (35% height, draggable):
- Status banner: "Driver arriving" or "On trip to destination"
- Driver info (compact)
- **Trip Progress**:
- Distance remaining
- Time remaining
- Current street/area
- **Quick Actions**:
- Call (primary)
- Message
- SOS (emergency - red, small)

### 7. Trip Completion

**Layout**:

- **Full Screen Card**:
- Success icon (green checkmark)
- "Trip Completed!"
- **Trip Summary**:
- Map thumbnail with route
- Duration and distance
- Final fare (large, bold)
- **Rate Your Ride**:
- 5-star rating (tap to select)
- Optional comment field
- Tip option (ETB 10, 20, 50, Custom)
- **Actions**:
- "Submit Rating" (blue button)
- "Skip" (text button)
- "Request Another Ride" (outlined button)

### 8. My Trips Screen

**Layout**:

- **Header**: "My Trips"
- **Filter Tabs**: All, Completed, Cancelled
- **Trip List**:
- Date headers (Today, Yesterday, This Week)
- Trip cards showing:
- Date and time
- Route (from → to)
- Fare
- Driver name and photo
- Status badge
- Tap to view trip details

### 9. Profile Screen

**Layout**:

- **User Info Card**:
- Photo (editable)
- Name, phone, email
- Edit button
- **Saved Places**:
- Home, Work, Favorites
- Add new place button
- **Payment Methods**:
- Saved cards/mobile money
- Add new method
- **Settings**:
- Notifications
- Privacy
- Language (Tigrinya, Amharic, English)
- **Support**:
- Help Center
- Contact Support
- Emergency SOS Setup

## Key Interactions & Micro-interactions

### Bottom Sheet Behavior

- **Drag Handle**: Always visible gray bar at top
- **Snap Points**: 30%, 50%, 70%, 90%
- **Velocity-based**: Fast swipe snaps to next state
- **Auto-collapse**: After 5 seconds of inactivity in expanded states
- **During Active Ride**: Limited to 35%-60% range

### Map Interactions

- **Pin Movement**: When sheet at 30%, map is freely pannable
- **Pin Lock**: When sheet >50%, map follows route
- **Zoom Controls**: Always accessible (+ - buttons)
- **Recenter Button**: Always visible (blue, bottom right)

### Search Behavior

- **Autocomplete**: Results appear after 2 characters
- **Debounce**: 300ms delay
- **Prioritization**: Saved > Recent > Popular > All results
- **Empty State**: Show popular destinations

### Button States

- **Primary (Blue)**: Solid fill, white text
- **Secondary**: Blue outline, blue text
- **Disabled**: Gray fill, gray text, 50% opacity
- **Loading**: Spinner replaces text, button disabled

## Accessibility Features

- **High Contrast Mode**: Ensure 4.5:1 contrast ratio
- **Touch Targets**: Minimum 44x44px
- **Text Sizing**: Support system font scaling
- **Screen Reader**: Label all interactive elements
- **Offline Mode**: Cache recent locations and show offline indicator

## Error States & Edge Cases

1. **No Internet**: Show banner, allow offline mode with cached data
2. **No Drivers Available**: Show message, suggest trying later or different location
3. **GPS Issues**: Show fix suggestions, allow manual location entry
4. **Payment Failed**: Retry options, alternative payment methods
5. **Driver Cancelled**: Apology message, auto-search for new driver
6. **Low Battery**: Prompt to enable battery saver, reduce map updates

## Performance Optimizations

- **Lazy Load**: Load trip history on scroll
- **Image Caching**: Cache driver photos and map tiles
- **Map Rendering**: Use appropriate zoom levels, limit marker count
- **Animation**: Use 60fps animations, reduce during low battery
- **API Calls**: Batch requests, use pagination

## Implementation Priority

1. **Phase 1** (Core Experience):

- Home screen with draggable bottom sheet
- Map with fixed pin
- Location search with Tigray data
- Vehicle selection
- Request ride flow

2. **Phase 2** (Essential Features):

- Driver matching and tracking
- In-ride experience
- Trip completion and rating
- Bottom navigation

3. **Phase 3** (Complete Experience):

- My Trips history
- Profile management
- Saved places
- Payment methods

4. **Phase 4** (Polish):

- Micro-interactions
- Animations
- Error handling
- Accessibility features

### To-dos

- [ ] Set up blue brand color scheme and design system constants
- [ ] Create Tigray location data with Mekelle and Adigrat locations
- [ ] Implement home screen with draggable bottom sheet (30-90%)
- [ ] Build destination search with autocomplete and Tigray suggestions
- [ ] Create vehicle selection cards with pricing
- [ ] Implement driver searching state with loading animation
- [ ] Build driver assigned screen with driver info card
- [ ] Create on-trip screen with real-time tracking UI
- [ ] Build trip completion screen with rating and tip
- [ ] Implement bottom navigation bar (Home, Trips, Messages, Profile)
- [ ] Create My Trips screen with trip history
- [ ] Build profile screen with settings and saved places