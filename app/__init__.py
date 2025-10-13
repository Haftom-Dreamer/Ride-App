"""
Application Factory for Flask Ride App
"""

import os
import json
from datetime import datetime, timezone, timedelta
from flask import Flask, request, jsonify, session, render_template, redirect, url_for, flash
from flask_login import LoginManager
from flask_migrate import Migrate
from flask_marshmallow import Marshmallow
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_wtf.csrf import CSRFProtect
from config import config

def create_app(config_name=None):
    """Application Factory Pattern"""
    
    # Create Flask app with template and static folders in parent directory
    template_folder = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'templates')
    static_folder = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'static')
    
    app = Flask(__name__, 
                template_folder=template_folder,
                static_folder=static_folder)
    
    # Load configuration
    if config_name is None:
        config_name = os.environ.get('FLASK_ENV', 'development')
    app.config.from_object(config[config_name])
    
    # Initialize extensions
    from app.models import db, Admin, Passenger
    db.init_app(app)
    
    migrate = Migrate(app, db)
    ma = Marshmallow(app)
    csrf = CSRFProtect(app)
    
    # Handle CSRF errors
    from werkzeug.exceptions import BadRequest
    
    @app.errorhandler(400)
    def handle_csrf_error(e):
        # Check if it's a CSRF error
        if isinstance(e, BadRequest) and 'CSRF' in str(e.description):
            if request.path.startswith('/api/'):
                app.logger.error(f"CSRF error on API endpoint: {request.path}")
                return jsonify({'error': 'CSRF token missing or invalid'}), 400
            flash('Session expired. Please refresh and try again.', 'danger')
            return redirect(url_for('auth.login'))
        # Return generic 400 error
        if request.path.startswith('/api/'):
            return jsonify({'error': 'Bad request'}), 400
        return e
    
    # Login manager setup
    login_manager = LoginManager(app)
    login_manager.login_view = 'auth.login'
    
    @login_manager.user_loader
    def load_user(user_id):
        user_type = session.get('user_type')
        if user_type == 'admin':
            return Admin.query.get(int(user_id))
        elif user_type == 'passenger':
            return Passenger.query.get(int(user_id))
        return None
    
    # Rate limiting
    limiter = Limiter(
        app=app,
        key_func=get_remote_address,
        storage_uri=app.config.get('RATELIMIT_STORAGE_URL', 'memory://'),
        default_limits=["1000 per day", "200 per hour"],
        enabled=app.config.get('RATELIMIT_ENABLED', True)
    )
    
    # CSRF exemption for API routes
    @app.before_request
    def exempt_api_csrf():
        if request.path.startswith('/api/'):
            try:
                csrf._exempt_views.add(request.endpoint)
                setattr(request, 'csrf_exempt', True)
                app.logger.debug(f"CSRF exempted API endpoint: {request.endpoint}")
            except Exception as e:
                app.logger.debug(f"CSRF exemption failed: {e}")
                pass
        else:
            # Log non-API requests for debugging
            if request.method == 'POST' and request.path == '/login':
                app.logger.info(f"Login request - Path: {request.path}, Method: {request.method}")
                app.logger.info(f"Request headers: {dict(request.headers)}")
                app.logger.info(f"Form keys: {list(request.form.keys()) if request.form else 'No form data'}")
    
    # Error Handlers
    @app.errorhandler(404)
    def not_found(e):
        if request.path.startswith('/api/'):
            return jsonify({'error': 'Resource not found'}), 404
        return render_template('base.html'), 404

    @app.errorhandler(500)
    def internal_error(e):
        db.session.rollback()
        if request.path.startswith('/api/'):
            return jsonify({'error': 'Internal server error'}), 500
        flash('An unexpected error occurred. Please try again.', 'danger')
        return redirect(url_for('admin.dashboard'))

    @app.errorhandler(429)
    def ratelimit_handler(e):
        if request.path.startswith('/api/'):
            return jsonify({'error': 'Rate limit exceeded. Please try again later.'}), 429
        flash('Too many requests. Please slow down.', 'warning')
        return redirect(request.referrer or url_for('admin.dashboard'))
    
    # Language setup
    translations = {}
    try:
        with open(os.path.join(app.root_path, '..', 'translations.json'), 'r', encoding='utf-8') as f:
            translations = json.load(f)
    except Exception as e:
        app.logger.error(f"Failed to load translations: {e}")
        translations = {'en': {}, 'am': {}, 'ti': {}}

    def get_locale():
        """Get current locale from session or cookie"""
        lang = session.get('language')
        if not lang:
            from flask import request
            lang = request.cookies.get('language_preference', 'en')
            if lang:
                session['language'] = lang
        return lang or 'en'

    @app.context_processor
    def inject_gettext():
        def _(key):
            lang = get_locale()
            return translations.get(lang, translations['en']).get(key, key)
        return dict(_=_, translations=translations)
    
    # Language switching route
    @app.route('/change_language/<lang>')
    def change_language(lang):
        # Validate language code
        if lang not in ['en', 'am', 'ti']:
            lang = 'en'
        
        session['language'] = lang
        
        response = redirect(request.referrer or url_for('passenger.home'))
        response.set_cookie('language_preference', lang, max_age=365*24*60*60)  # 1 year
        
        return response
    
    # File upload route
    @app.route('/uploads/<filename>')
    def uploaded_file(filename):
        from flask import send_from_directory
        return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
    
    # Register Blueprints
    from app.auth import auth
    from app.admin import admin
    from app.passenger import passenger
    
    # Import API blueprint and all its routes BEFORE registering
    from app.api import api
    from app.api import rides, drivers, data  # Import all API modules
    
    # Initialize limiter for blueprints
    from app.auth import init_limiter as auth_init_limiter
    from app.api import init_limiter as api_init_limiter
    
    auth_init_limiter(app)
    api_init_limiter(app)
    
    # Exempt specific API routes from CSRF
    csrf.exempt(api)
    
    app.register_blueprint(auth, url_prefix='/auth')
    app.register_blueprint(api, url_prefix='/api')
    app.register_blueprint(admin)
    app.register_blueprint(passenger)
    
    # Root route redirect
    @app.route('/')
    def index():
        from flask_login import current_user
        if current_user.is_authenticated:
            if session.get('user_type') == 'admin':
                return redirect(url_for('admin.dashboard'))
            elif session.get('user_type') == 'passenger':
                return redirect(url_for('passenger.app'))
        return redirect(url_for('auth.login'))
    
    # Initialize database and default data
    with app.app_context():
        try:
            # Create upload directory
            os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
            
            # Create tables
            db.create_all()
            
            # Check for admin user
            if not Admin.query.first():
                print("WARNING: No admin user found. Please create one using the create_admin.py script.")
            
            # Update driver UIDs if needed
            from app.models import Driver
            drivers_without_uid = Driver.query.filter(Driver.driver_uid == None).all()
            if drivers_without_uid:
                for driver in drivers_without_uid:
                    driver.driver_uid = f"DRV-{driver.id:04d}"
                db.session.commit()
            
            # Update passenger UIDs if needed  
            passengers_without_uid = Passenger.query.filter(Passenger.passenger_uid == None).all()
            if passengers_without_uid:
                for passenger in passengers_without_uid:
                    passenger.passenger_uid = f"PAX-{passenger.id:05d}"
                db.session.commit()
            
            # Create default settings if needed
            from app.models import Setting
            if not Setting.query.first():
                db.session.add(Setting(key='base_fare', value='25'))
                db.session.add(Setting(key='per_km_bajaj', value='8'))
                db.session.add(Setting(key='per_km_car', value='12'))
                db.session.commit()
                
        except Exception as e:
            app.logger.error(f"Database initialization error: {e}")
    
    return app
