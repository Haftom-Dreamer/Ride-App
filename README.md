# 🚖 RIDE - Ride Sharing Dispatch System

A comprehensive Flask-based ride-sharing dispatch application with real-time ride management, driver tracking, and multi-language support.

## ✨ Features

- 🚗 Real-time ride dispatching
- 👥 Driver and passenger management
- 📊 Analytics dashboard
- 🗺️ Route planning with OSRM
- 🌍 Multi-language support (English, Amharic, Tigrinya)
- 💰 Dynamic fare calculation
- 📱 Responsive web interface
- 🔐 Secure authentication
- 📈 Performance analytics

## 🚀 Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Create Admin User
```bash
python scripts/create_admin.py
```

### 3. Run the Application
```bash
python main.py
# OR
python run.py
```

### 4. Access the Dashboard
- **Admin Dashboard**: http://127.0.0.1:5000/login
- **Passenger App**: http://127.0.0.1:5000/passenger/login

## 📂 Project Structure

```
RIDE/
├── main.py                  # Main Flask application
├── config.py                # Configuration settings
├── requirements.txt         # Python dependencies
├── run.py                   # Application entry point
├── translations.json        # Multi-language support
├── ride_app.db             # SQLite database
├── templates/               # HTML templates
├── static/                  # CSS, JavaScript, images
├── docs/                    # 📚 All documentation
├── scripts/                 # 🔧 Utility scripts
└── archive/                 # 📦 Backups & future features
```

## 📚 Documentation

All documentation is organized in the `docs/` folder:

- **[Documentation Index](docs/INDEX.md)** - Complete documentation directory
- **[Quick Start Guide](docs/QUICK_START.md)** - Get running in 5 minutes
- **[Setup Guide](docs/SETUP_GUIDE.md)** - Detailed installation instructions
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Common commands and operations

## 🔧 Utility Scripts

All utility scripts are in the `scripts/` folder:

```bash
# Create or reset admin user
python scripts/create_admin.py

# Check installation
python scripts/check_installation.py

# Initialize database
python scripts/init_database.py

# Generate secret key
python scripts/generate_secret_key.py

# Migrate database
python scripts/migrate_database.py
```

## 🛠️ Tech Stack

- **Backend**: Flask (Python)
- **Database**: SQLite (development) / PostgreSQL (production)
- **Frontend**: HTML, CSS, JavaScript
- **Maps**: Leaflet.js, OpenStreetMap
- **Routing**: OSRM
- **Authentication**: Flask-Login
- **Forms**: Flask-WTF

## 🌍 Multi-Language Support

The application supports three languages:
- English (en)
- Amharic (am)
- Tigrinya (ti)

Language can be switched from the dashboard interface.

## 🔐 Default Credentials

After running `python scripts/create_admin.py`:
- **Username**: admin
- **Password**: admin123

**⚠️ Change these credentials in production!**

## 📊 Key Features

### Admin Dashboard
- Real-time ride monitoring
- Driver management (add, edit, delete)
- Passenger tracking
- Analytics and reports
- Feedback management

### Passenger Features
- Request rides
- Track driver location
- View ride history
- Rate drivers
- Multi-language interface

### Driver Management
- Online/offline status
- Ride assignment
- Performance tracking
- Earnings reports

## 🔄 Recent Updates

The project has been reorganized for better maintainability:
- ✅ Documentation moved to `docs/` folder
- ✅ Utility scripts moved to `scripts/` folder
- ✅ Blueprint architecture available in `archive/`
- ✅ Cleaner root directory structure

See `docs/IMPROVEMENTS_COMPLETED.md` for detailed changelog.

## 📖 API Documentation

For API usage and service layer documentation, see:
- **[Service Layer Usage Guide](docs/SERVICE_LAYER_USAGE_GUIDE.md)**

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is proprietary software.

## 🆘 Support

For issues or questions:
1. Check the **[Quick Reference](docs/QUICK_REFERENCE.md)**
2. Review **[Bug Fixes Summary](docs/BUG_FIXES_SUMMARY.md)**
3. See **[Documentation Index](docs/INDEX.md)**

## 🔮 Future Enhancements

- Blueprint modular architecture (available in `archive/blueprint_structure/`)
- Real-time WebSocket notifications
- Mobile app integration
- Advanced analytics dashboard
- Payment gateway integration

---

**Version**: 2.0  
**Last Updated**: October 13, 2025  
**Status**: Production Ready ✅