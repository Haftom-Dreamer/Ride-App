# RIDE Application - Setup and Migration Guide

## Overview
This guide will help you set up the improved RIDE application with all the security enhancements and configuration changes.

## What's New

### Security Improvements
- ✅ Environment-based configuration (no hardcoded secrets)
- ✅ CSRF protection for forms
- ✅ Rate limiting on sensitive endpoints
- ✅ Restricted CORS origins
- ✅ File upload validation (type and size limits)
- ✅ Input validation and sanitization
- ✅ Better password policies

### Performance Improvements
- ✅ Database indexes on frequently queried fields
- ✅ Optimized queries with proper joins

### Code Quality
- ✅ Decimal types for money (no more float rounding errors)
- ✅ Configuration management via `config.py`
- ✅ Error handlers for better user experience
- ✅ Removed duplicate code blocks

## Setup Instructions

### 1. Install Dependencies

First, install the updated requirements:

```bash
pip install -r requirements.txt
```

### 2. Create Environment File

Copy the environment template and update it with your values:

```bash
# On Windows
copy ENV_TEMPLATE.txt .env

# On Linux/Mac
cp ENV_TEMPLATE.txt .env
```

Edit `.env` and set your values:

```env
FLASK_ENV=development
FLASK_DEBUG=True
SECRET_KEY=your-super-secret-key-here-change-this-to-random-string

# For production, generate a secure secret key:
# python -c "import secrets; print(secrets.token_hex(32))"

DATABASE_URL=sqlite:///app.db
MAX_UPLOAD_SIZE=16777216
CORS_ORIGINS=http://localhost:3000,http://localhost:5000
RATELIMIT_ENABLED=True
RATELIMIT_STORAGE_URL=memory://
TIMEZONE_OFFSET_HOURS=3
```

### 3. Create Database Migration

Since we've added indexes and changed the `fare` field from Float to Numeric, you need to create a migration:

```bash
# Initialize migrations if not already done
flask db init

# Create a new migration
flask db migrate -m "Add indexes and change fare to Numeric"

# Apply the migration
flask db upgrade
```

### 4. Create Admin User

If you don't have an admin user yet:

```bash
python create_admin.py
```

### 5. Run the Application

```bash
python main.py
```

The app will run on `http://127.0.0.1:5000` by default.

## Important Database Changes

### Changed Fields
- `Ride.fare`: Changed from `Float` to `Numeric(10, 2)` for precise money calculations
- `Ride.distance_km`: Changed from `Float` to `Numeric(10, 2)`

### New Indexes
Indexes were added to improve query performance on:
- `Passenger.passenger_uid`
- `Passenger.phone_number`
- `Driver.driver_uid`
- `Driver.phone_number`
- `Driver.vehicle_type`
- `Driver.status`
- `Ride.passenger_id`
- `Ride.driver_id`
- `Ride.vehicle_type`
- `Ride.status`
- `Ride.request_time`

## Configuration Options

### File Upload Settings
- **MAX_UPLOAD_SIZE**: Maximum file size in bytes (default: 16MB)
- **ALLOWED_EXTENSIONS**: png, jpg, jpeg, gif, pdf, doc, docx

### Rate Limiting
Default limits:
- **Login endpoints**: 5 attempts per minute
- **Signup**: 3 attempts per hour
- **Ride requests**: 10 per hour
- **General API**: 200 per day, 50 per hour

### CORS Settings
Set `CORS_ORIGINS` in `.env` to restrict which domains can access your API:
```
CORS_ORIGINS=http://localhost:3000,https://yourdomain.com
```

## Production Deployment

### 1. Set Environment Variables

In production, make sure to:
- Set `FLASK_ENV=production`
- Set `FLASK_DEBUG=False`
- Generate a strong `SECRET_KEY`
- Use PostgreSQL instead of SQLite: `DATABASE_URL=postgresql://user:pass@localhost/dbname`
- Use Redis for rate limiting: `RATELIMIT_STORAGE_URL=redis://localhost:6379`
- Set specific `CORS_ORIGINS` (never use `*` in production)

### 2. Use a Production Server

Don't use the built-in Flask server in production. Use Gunicorn or similar:

```bash
pip install gunicorn

# Run with 4 worker processes
gunicorn -w 4 -b 0.0.0.0:8000 main:app
```

### 3. Set Up a Reverse Proxy

Use Nginx or Apache as a reverse proxy in front of Gunicorn for better performance and security.

### 4. Enable HTTPS

Always use HTTPS in production. Get a free SSL certificate from Let's Encrypt.

## Troubleshooting

### Migration Issues

If you encounter migration issues with existing data:

```bash
# Backup your database first!
cp app.db app.db.backup

# If migration fails, you might need to drop and recreate
# WARNING: This will delete all data
flask db downgrade base
flask db upgrade
```

### Import Errors

If you get import errors for new packages:
```bash
pip install -r requirements.txt --upgrade
```

### CSRF Token Errors

If you get CSRF token errors on forms, make sure your templates include:
```html
<form method="POST">
    {{ csrf_token() }}
    <!-- form fields -->
</form>
```

For AJAX requests to non-API endpoints, include the CSRF token in headers:
```javascript
fetch('/some-endpoint', {
    method: 'POST',
    headers: {
        'X-CSRFToken': getCsrfToken()
    }
})
```

API endpoints (`/api/*`) are exempt from CSRF protection.

### Rate Limiting Issues

If you're hitting rate limits during development, you can disable them:
```env
RATELIMIT_ENABLED=False
```

## Testing

To run tests (when implemented):
```bash
FLASK_ENV=testing python -m pytest
```

## Backup Strategy

### Daily Backups
```bash
# For SQLite
cp app.db backups/app_$(date +%Y%m%d).db

# For PostgreSQL
pg_dump dbname > backups/backup_$(date +%Y%m%d).sql
```

### Before Migrations
Always backup your database before running migrations:
```bash
cp app.db app.db.pre_migration_$(date +%Y%m%d)
```

## Support

For issues or questions:
1. Check this guide first
2. Review the error logs
3. Check the Flask/SQLAlchemy documentation
4. Review the code comments in `main.py` and `config.py`

## Next Steps

Consider these improvements for the future:
- Add unit and integration tests
- Implement blueprints for better code organization
- Add logging (Python logging module)
- Add monitoring (Sentry, New Relic, etc.)
- Implement API versioning
- Add WebSocket support for real-time updates
- Implement caching (Redis)
- Add API documentation (Swagger/OpenAPI)

