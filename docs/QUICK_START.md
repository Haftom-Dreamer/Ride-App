# Quick Start Guide - Flask Ride App

## 🚀 Running the Application

### Option 1: Original Structure (Current - Recommended)
```bash
python main.py
```
✅ **Fully tested and working**
✅ All features functional
✅ Production-ready

### Option 2: Start with run.py
```bash
python run.py
```
Currently configured to use the original structure.

## 👤 Creating an Admin User

If you need to create or reset an admin user:

```bash
python create_admin.py
```

Follow the prompts to:
- Create a new admin user
- Reset an existing admin password

**Default credentials:**
- Username: `admin`
- Password: `admin123`

Then login at: `http://127.0.0.1:5000/login`

## 📁 Project Structure

### Current Files (Original)
```
main.py                 # Main application (1,617 lines)
templates/              # HTML templates
static/                 # CSS, JS, images
config.py               # Configuration
create_admin.py         # Admin user creation script
```

### New Blueprint Structure (Future)
```
app/                    # Modular application package
├── __init__.py        # Application factory
├── models/            # Database models
├── auth/              # Authentication
├── api/               # API endpoints
│   ├── rides.py      # Ride management
│   ├── drivers.py    # Driver management
│   └── data.py       # Analytics
├── admin/             # Dashboard
├── passenger/         # Passenger app
└── utils/             # Helper functions
```

## 🎯 Quick Access URLs

Once the app is running:

### Admin/Dispatcher
- **Login**: http://127.0.0.1:5000/login
- **Dashboard**: http://127.0.0.1:5000/dashboard

### Passenger
- **Login**: http://127.0.0.1:5000/passenger/login
- **Signup**: http://127.0.0.1:5000/passenger/signup
- **Request Ride**: http://127.0.0.1:5000/request

### API Endpoints
- **Status**: http://127.0.0.1:5000/api/debug/status
- **All routes**: Check `RESTRUCTURE_SUMMARY.md` for complete API list

## 📝 Common Tasks

### Change Language
Available languages: English (en), Amharic (am), Tigrinya (ti)
- Use the language selector in the dashboard

### Add a Driver
1. Login as admin
2. Go to Dashboard
3. Click "Add Driver"
4. Fill in driver details
5. Upload required documents

### Request a Ride (Passenger)
1. Login or signup as passenger
2. Enter pickup and destination
3. Select vehicle type (Bajaj/Car)
4. Confirm and request

### Monitor Rides (Admin)
- **Pending**: See all ride requests
- **Active**: Track ongoing rides
- **History**: View completed rides

## 🔧 Configuration

### Database
Default: SQLite (`ride_app.db`)

To use PostgreSQL or MySQL:
```python
# In config.py
SQLALCHEMY_DATABASE_URI = 'postgresql://user:pass@localhost/dbname'
```

### File Uploads
Upload folder: `static/uploads/`
Max file size: 5MB
Allowed types: png, jpg, jpeg, gif, pdf, doc, docx

### Rate Limiting
- API: 1000 requests/day, 200 requests/hour
- Login: 5 attempts/minute
- Signup: 3 attempts/hour

## 📚 Documentation

- `RESTRUCTURE_SUMMARY.md` - Complete restructure documentation
- `BLUEPRINT_RESTRUCTURE.md` - Blueprint architecture details
- `README.md` - Original project README

## 🆘 Troubleshooting

### Application won't start
```bash
# Check if Python is installed
python --version

# Check if all dependencies are installed
pip install -r requirements.txt

# Check if port 5000 is available
netstat -an | findstr :5000
```

### Can't login
```bash
# Create/reset admin user
python create_admin.py
```

### Database errors
```bash
# Delete and recreate database
# WARNING: This deletes all data
rm ride_app.db
python main.py  # Will create new database
```

## 🎓 Next Steps

1. **Create Admin User**:
   ```bash
   python create_admin.py
   ```

2. **Start Application**:
   ```bash
   python main.py
   ```

3. **Login to Dashboard**:
   Visit http://127.0.0.1:5000/login

4. **Add Drivers**:
   Use the dashboard to add your first driver

5. **Test Ride Request**:
   - Create a passenger account
   - Request a test ride
   - Assign driver from dashboard

## 🌟 Features

✅ Real-time ride dispatching
✅ Driver management
✅ Passenger accounts
✅ Fare calculation
✅ Route planning (OSRM)
✅ Geocoding (Nominatim)
✅ Analytics dashboard
✅ Multi-language support
✅ Secure authentication
✅ Rate limiting
✅ File uploads

## ⚡ Performance Tips

- Use PostgreSQL for production
- Enable Redis for rate limiting
- Use a production WSGI server (Gunicorn)
- Enable caching for static files
- Optimize database queries

---

**Need Help?** Check the documentation files or review the code comments.
