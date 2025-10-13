"""
API Blueprint - All REST API endpoints
"""

import os
import json
import requests
from decimal import Decimal, ROUND_HALF_UP
from datetime import datetime, timezone, timedelta
from flask import Blueprint, request, jsonify, current_app, session, send_from_directory
from flask_login import login_required, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from sqlalchemy import func, case
from app.models import db, Admin, Passenger, Driver, Ride, Feedback, Setting
from app.utils import to_eat, handle_file_upload
from functools import wraps

api = Blueprint('api', __name__, url_prefix='/api')

# Create limiter instance (will be initialized in create_app)
limiter = None

def init_limiter(app):
    global limiter
    limiter = Limiter(
        app=app,
        key_func=get_remote_address,
        storage_uri=app.config.get('RATELIMIT_STORAGE_URL', 'memory://'),
        default_limits=["1000 per day", "200 per hour"]
    )

# Custom decorators for role-based access
def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or session.get('user_type') != 'admin':
            return jsonify({'error': 'Authentication required. Please log in as a dispatcher.'}), 401
        return f(*args, **kwargs)
    return decorated_function

def passenger_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or session.get('user_type') != 'passenger':
            return jsonify({'error': 'Authentication required. Please log in as a passenger.'}), 401
        return f(*args, **kwargs)
    return decorated_function

# Helper function for settings
def get_setting(key, default=None):
    """Get setting value from database"""
    setting = Setting.query.filter_by(key=key).first()
    return setting.value if setting else default

# --- Language API ---
@api.route('/get_language')
def get_language():
    """API endpoint to get current language preference"""
    from flask import session as flask_session
    lang = flask_session.get('language', 'en')
    return jsonify({'language': lang})

@api.route('/set_language', methods=['POST'])
def set_language():
    """API endpoint to set language preference"""
    data = request.get_json()
    lang = data.get('language', 'en')
    
    # Validate language code
    if lang not in ['en', 'am', 'ti']:
        lang = 'en'
    
    session['language'] = lang
    return jsonify({'success': True, 'language': lang})

# --- Debug Endpoints ---
@api.route('/debug/status')
def debug_status():
    """Debug endpoint to check system status"""
    try:
        # Check database connection
        db_status = "OK"
        try:
            db.session.execute(db.text("SELECT 1")).fetchone()
        except Exception as e:
            db_status = f"Error: {str(e)}"
        
        # Check tables exist
        tables = {}
        try:
            tables['admin_count'] = Admin.query.count()
            tables['setting_count'] = Setting.query.count()
            tables['driver_count'] = Driver.query.count()
            tables['passenger_count'] = Passenger.query.count()
        except Exception as e:
            tables['error'] = str(e)
        
        return jsonify({
            'status': 'running',
            'database': db_status,
            'tables': tables,
            'config': {
                'debug': current_app.config.get('DEBUG'),
                'upload_folder': current_app.config.get('UPLOAD_FOLDER')
            }
        })
    except Exception as e:
        return jsonify({'error': str(e), 'status': 'error'}), 500

@api.route('/debug/test-post', methods=['POST'])
def test_post():
    """Simple POST test endpoint to debug request handling"""
    try:
        data = {
            'method': request.method,
            'content_type': request.content_type,
            'headers': dict(request.headers),
            'json_data': request.get_json(silent=True),
            'form_data': dict(request.form),
            'raw_data': request.get_data(as_text=True)[:200]  # First 200 chars
        }
        return jsonify({'success': True, 'request_info': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@api.route('/debug/admin-users')
def debug_admin_users():
    """Debug endpoint to check admin users"""
    try:
        admins = Admin.query.all()
        admin_info = [{
            'id': admin.id,
            'username': admin.username,
            'has_password': bool(admin.password_hash)
        } for admin in admins]
        
        return jsonify({
            'total_admins': len(admins),
            'admins': admin_info
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@api.route('/debug/create-test-admin', methods=['POST'])
def create_test_admin():
    """Debug endpoint to create a test admin user"""
    try:
        # Check if test admin already exists
        existing = Admin.query.filter_by(username='admin').first()
        if existing:
            return jsonify({'message': 'Test admin already exists', 'username': 'admin'})
        
        # Create test admin
        test_admin = Admin(username='admin')
        test_admin.set_password('admin123')
        db.session.add(test_admin)
        db.session.commit()
        
        return jsonify({
            'message': 'Test admin created successfully',
            'username': 'admin',
            'password': 'admin123'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
