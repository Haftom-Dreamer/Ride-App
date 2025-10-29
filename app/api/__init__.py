"""
API Package Initialization
Creates the main API blueprint and exports decorators and utilities
"""

from flask import Blueprint
from flask import current_app

# Create the main API blueprint
api = Blueprint('api', __name__)

# Import decorators from utils
from app.utils.decorators import admin_required, passenger_required

# Import limiter - it will be initialized in app factory
# We'll make it available but it might be None if not initialized
limiter = None

def init_limiter(app_limiter):
    """Initialize limiter for API routes"""
    global limiter
    limiter = app_limiter

# Helper function for settings
def get_setting(key, default=None):
    """Get setting value from database"""
    from app.models import Setting
    try:
        setting = Setting.query.filter_by(key=key).first()
        return setting.value if setting else default
    except Exception:
        # If database is not available, return default
        return default

# Import all route modules to register their routes
# This must be done AFTER the blueprint is created
# Routes are registered when these modules are imported and decorators are evaluated
from app.api import data, rides, drivers, admins

# Export the blueprint and utilities
__all__ = ['api', 'admin_required', 'passenger_required', 'limiter', 'get_setting', 'init_limiter']
