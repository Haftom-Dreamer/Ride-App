# RIDE Application - Quick Reference

## Installation & Setup

### First Time Setup
```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Check installation
python check_installation.py

# 3. Create .env file
copy ENV_TEMPLATE.txt .env  # Windows
cp ENV_TEMPLATE.txt .env    # Linux/Mac

# 4. Edit .env and set SECRET_KEY
# Generate secure key: python -c "import secrets; print(secrets.token_hex(32))"

# 5. Initialize database
flask db init
flask db migrate -m "Initial migration"
flask db upgrade

# 6. Create admin user
python create_admin.py

# 7. Run application
python main.py
```

### Migrating Existing Installation
```bash
# 1. Backup database
copy app.db app.db.backup  # Windows
cp app.db app.db.backup    # Linux/Mac

# 2. Run migration helper
python migrate_database.py

# 3. Start application
python main.py
```

## Environment Variables (.env)

### Required Settings
```env
SECRET_KEY=your-secret-key-here-must-be-changed
FLASK_ENV=development  # or production
FLASK_DEBUG=True       # False for production
DATABASE_URL=sqlite:///app.db
```

### Optional Settings
```env
MAX_UPLOAD_SIZE=16777216  # 16MB in bytes
CORS_ORIGINS=http://localhost:3000,http://localhost:5000
RATELIMIT_ENABLED=True
RATELIMIT_STORAGE_URL=memory://  # or redis://localhost:6379
TIMEZONE_OFFSET_HOURS=3
```

## Database Commands

```bash
# Create new migration
flask db migrate -m "Description of changes"

# Apply migrations
flask db upgrade

# Rollback last migration
flask db downgrade

# Show migration history
flask db history

# Create database backup
copy app.db backups\app_YYYYMMDD.db  # Windows
cp app.db backups/app_$(date +%Y%m%d).db  # Linux/Mac
```

## Running the Application

### Development
```bash
# Standard run
python main.py

# With different port
FLASK_RUN_PORT=8000 python main.py

# With debug mode
FLASK_DEBUG=True python main.py
```

### Production
```bash
# Install gunicorn
pip install gunicorn

# Run with gunicorn (4 workers)
gunicorn -w 4 -b 0.0.0.0:8000 main:app

# Run with gunicorn (auto-reload for testing)
gunicorn --reload -w 2 -b 0.0.0.0:8000 main:app
```

## Common Tasks

### Create Admin User
```bash
python create_admin.py
```

### Reset Admin Password
```python
# In Python shell or create a script
from main import app, Admin, db

with app.app_context():
    admin = Admin.query.filter_by(username='admin').first()
    if admin:
        admin.set_password('new_password_here')
        db.session.commit()
        print("Password updated")
```

### Check Rate Limits
```python
# Temporarily disable in .env
RATELIMIT_ENABLED=False
```

### View Database
```bash
# Install sqlite browser
pip install sqlite-web

# Run browser
sqlite_web app.db
```

## Troubleshooting

### Import Errors
```bash
pip install -r requirements.txt --upgrade
```

### Migration Errors
```bash
# Delete migrations and start fresh (WARNING: loses data)
rm -rf migrations  # Linux/Mac
rmdir /s migrations  # Windows
flask db init
flask db migrate -m "Fresh start"
flask db upgrade
```

### Database Locked
```bash
# Someone else is accessing the database
# Close all connections and try again
# Or restart the application
```

### CSRF Token Missing
```html
<!-- Add to forms -->
<form method="POST">
    {{ csrf_token() }}
    <!-- form fields -->
</form>
```

### Rate Limit Errors
```bash
# Temporarily disable in .env
RATELIMIT_ENABLED=False

# Or increase limits in main.py
# @limiter.limit("100 per minute")
```

### Upload Fails
```bash
# Check file size (default 16MB max)
MAX_UPLOAD_SIZE=33554432  # 32MB

# Check file type is allowed
# Allowed: png, jpg, jpeg, gif, pdf, doc, docx
```

## API Endpoints

### Authentication
```
POST /login                  - Admin login
POST /passenger/login        - Passenger login
POST /passenger/signup       - Passenger signup
GET  /logout                 - Logout
```

### Rides
```
POST /api/ride-request       - Request a ride
POST /api/assign-ride        - Assign driver to ride
POST /api/complete-ride      - Mark ride as completed
POST /api/cancel-ride        - Cancel/reassign ride
GET  /api/pending-rides      - Get pending rides
GET  /api/active-rides       - Get active rides
POST /api/fare-estimate      - Calculate fare
```

### Drivers
```
POST /api/add-driver         - Add new driver
POST /api/update-driver/:id  - Update driver
POST /api/delete-driver      - Delete driver
POST /api/update-driver-status - Change driver status
GET  /api/drivers            - Get all drivers
GET  /api/available-drivers  - Get available drivers
```

### Analytics
```
GET  /api/dashboard-stats    - Dashboard statistics
GET  /api/analytics-data     - Analytics data
GET  /api/export-report      - Export report (PDF/Excel)
```

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| Login | 5 per minute |
| Signup | 3 per hour |
| Ride Requests | 10 per hour |
| General API | 50 per hour, 200 per day |

## File Upload Limits

- **Max Size**: 16MB (configurable)
- **Allowed Types**: png, jpg, jpeg, gif, pdf, doc, docx
- **Storage**: `static/uploads/`

## Security Checklist

### Development
- [ ] `.env` file created with settings
- [ ] `SECRET_KEY` set (any value OK)
- [ ] Database initialized
- [ ] Admin user created

### Production
- [ ] `FLASK_ENV=production`
- [ ] `FLASK_DEBUG=False`
- [ ] Strong `SECRET_KEY` (32+ random characters)
- [ ] PostgreSQL database (not SQLite)
- [ ] `CORS_ORIGINS` set to specific domains
- [ ] HTTPS enabled
- [ ] Gunicorn/uWSGI for serving
- [ ] Nginx/Apache reverse proxy
- [ ] Regular database backups
- [ ] Log monitoring set up

## Default Accounts

After `create_admin.py`:
- Username: (you choose)
- Password: (you choose)

No default passenger accounts - users must sign up.

## Logs Location

```
# Console output by default
# For file logging, redirect:
python main.py > logs/app.log 2>&1  # Linux/Mac
python main.py > logs\app.log 2>&1  # Windows
```

## Backup Strategy

```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
cp app.db backups/app_$DATE.db
# Keep last 30 days
find backups/ -name "app_*.db" -mtime +30 -delete
```

## Performance Tips

1. **Use PostgreSQL** in production instead of SQLite
2. **Enable caching** with Redis for frequent queries
3. **Use Gunicorn** with multiple workers
4. **Set up Nginx** as reverse proxy
5. **Enable gzip** compression in Nginx
6. **Use CDN** for static files if public-facing
7. **Monitor** with tools like New Relic or Datadog

## Support & Resources

- **Setup Guide**: `SETUP_GUIDE.md`
- **Changes**: `CHANGES_SUMMARY.md`
- **Main README**: `README.md`
- **Check Installation**: `python check_installation.py`
- **Migrate Database**: `python migrate_database.py`

## Quick Diagnostic Commands

```bash
# Check Python version
python --version

# Check if Flask is installed
python -c "import flask; print(flask.__version__)"

# Check if database exists
ls -lh app.db  # Linux/Mac
dir app.db     # Windows

# Test database connection
python -c "from main import app, db; app.app_context().push(); print('DB connected')"

# Count rides in database
python -c "from main import app, Ride; app.app_context().push(); print(Ride.query.count(), 'rides')"

# List all admin users
python -c "from main import app, Admin; app.app_context().push(); [print(a.username) for a in Admin.query.all()]"
```

## Emergency Procedures

### Database Corrupted
```bash
# 1. Stop application
# 2. Restore from backup
copy backups\app_latest.db app.db

# 3. If no backup, rebuild
rm app.db
flask db upgrade
python create_admin.py
```

### Forgotten Admin Password
```python
# reset_password.py
from main import app, Admin, db

with app.app_context():
    admin = Admin.query.first()
    admin.set_password('newpassword123')
    db.session.commit()
    print(f"Password reset for {admin.username}")
```

### Application Won't Start
1. Check Python version (need 3.8+)
2. Check dependencies: `pip install -r requirements.txt`
3. Check `.env` file exists
4. Check `config.py` exists
5. Check database not locked
6. Check port not already in use

## Getting Help

1. Run `python check_installation.py`
2. Check error messages carefully
3. Review relevant documentation
4. Check Flask/SQLAlchemy docs
5. Search error messages online

---

**Last Updated**: 2024
**Version**: 2.0

