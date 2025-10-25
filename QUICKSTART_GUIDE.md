# Quick Start Guide - Complete Passenger App

## Prerequisites
- Python 3.8+ with Flask installed
- Flutter 3.x installed
- Android device or emulator
- ADB tools installed

## Step 1: Backend Setup (5 minutes)

```bash
# 1. Navigate to project root
cd C:\Users\H.Dreamer\Documents\Adobe\RIDE

# 2. Install dependencies (if needed)
pip install -r requirements.txt

# 3. Run database migration (IMPORTANT - Only do this once)
python migrate_ride_fields_simple.py

# 4. Start the Flask server
python run.py
# or double-click START_SERVER.bat

# Server will start on http://localhost:5000
```

**Expected output:**
```
🔄 Adding new fields to Ride table...
✅ Successfully added new fields to Ride table
🔄 Creating EmergencyAlert table...
✅ Successfully created EmergencyAlert table
✅ Migration completed successfully!

* Running on http://0.0.0.0:5000
```

## Step 2: Flutter App Setup (5 minutes)

```bash
# 1. Navigate to Flutter app directory
cd passenger_app

# 2. Clean and get dependencies
flutter clean
flutter pub get

# 3. Connect Android device via USB or start emulator
# Make sure USB debugging is enabled

# 4. Set up ADB reverse (for localhost connection)
adb reverse tcp:5000 tcp:5000

# 5. Run the app
flutter run
```

**Expected output:**
```
Launching lib/main.dart on <device> in debug mode...
✓ Built build\app\outputs\flutter-apk\app-debug.apk
Installing...
Syncing files to device...
```

## Step 3: Test the App (5 minutes)

### First Time Setup:
1. **Sign Up** (if you don't have an account)
   - Tap "Create Account"
   - Enter username, email, phone number, password
   - Confirm password
   - Tap "Create Account"
   - Check your email for verification code
   - Enter the 6-digit code
   - Tap "Verify Code"
   - Account created! You'll be redirected to login

2. **Log In**
   - Enter phone number (without +251 prefix)
   - Enter password
   - Tap "Login"
   - You'll see the main screen with bottom navigation

### Explore the App:
1. **Home Tab (Ride Request)**
   - Map shows your current location
   - Tap "Find Me" to center map
   - Tap on map to set pickup (green marker)
   - Tap again to set destination (red marker)
   - Select vehicle type (Bajaj/Car)
   - Select payment method (Cash/Telebirr)
   - Add optional note
   - View fare estimate
   - Tap "Request Ride" to book

2. **History Tab**
   - View all past rides
   - Filter by status (All/Completed/Cancelled)
   - Tap any ride to see full details
   - Pull down to refresh

3. **Profile Tab**
   - View your profile information
   - Manage saved places
   - Access settings
   - Logout

## Common Issues & Solutions

### Issue: "Connection refused" or "Network error"
**Solution:**
```bash
# Make sure Flask server is running
# Run this in project root:
python run.py

# Make sure adb reverse is active:
adb devices
adb reverse tcp:5000 tcp:5000
```

### Issue: "Email not sent" during signup
**Solution:**
- Check that Flask server shows email configuration
- Verify environment variables are set:
  - MAIL_USERNAME=selamawiride@gmail.com
  - MAIL_PASSWORD=<app password>
- Check terminal output for email sending logs

### Issue: White screen on Flutter app
**Solution:**
```bash
# Clean and rebuild
cd passenger_app
flutter clean
flutter pub get
flutter run
```

### Issue: "Database locked" or migration errors
**Solution:**
```bash
# Stop Flask server first
# Then run migration:
python migrate_ride_fields_simple.py

# Restart Flask server
python run.py
```

## Testing Checklist

- [ ] Backend server starts successfully
- [ ] Database migration completes without errors
- [ ] Flutter app builds and installs
- [ ] Login screen appears
- [ ] Can create new account
- [ ] Receive verification email
- [ ] Can verify email and create account
- [ ] Can log in with credentials
- [ ] Main screen shows with bottom navigation
- [ ] Can switch between Home/History/Profile tabs
- [ ] Map displays current location
- [ ] Can tap map to set pickup/destination
- [ ] Fare estimate calculates correctly
- [ ] Profile shows user information
- [ ] Saved places section displays
- [ ] Can logout successfully

## Next Steps

Once basic functionality is working:
1. Test complete ride flow (request → waiting → assigned → completed)
2. Test saved places (add, delete)
3. Test rating system after ride completion
4. Test SOS functionality
5. Explore ride history filtering

## Quick Reference

### Backend Endpoints
```
POST   /api/fare-estimate
POST   /api/ride-request
GET    /api/ride-status/{ride_id}
POST   /api/cancel-ride
POST   /api/rate-ride
GET    /api/saved-places
POST   /api/saved-places
DELETE /api/saved-places/{id}
POST   /api/emergency-sos
GET    /api/ride-history
GET    /api/ride-details/{ride_id}
```

### Key Files
- Backend API: `app/api/passenger_api.py`
- Main Screen: `passenger_app/lib/features/main/presentation/screens/main_screen.dart`
- Ride History: `passenger_app/lib/features/ride/presentation/screens/ride_history_screen.dart`
- Profile: `passenger_app/lib/features/profile/presentation/screens/profile_screen.dart`
- Repository: `passenger_app/lib/features/ride/data/ride_repository.dart`

### Default Test Credentials
If you already have a test account:
- Phone: (your registered phone number without +251)
- Password: (your password)

## Support

For detailed information, see:
- `COMPLETE_PASSENGER_APP_SUMMARY.md` - Full implementation details
- `IMPLEMENTATION_PROGRESS.md` - What's been completed
- `README.md` - Project overview

---

**Estimated Setup Time:** 15 minutes  
**Difficulty Level:** Beginner-friendly  
**Last Updated:** October 25, 2025



