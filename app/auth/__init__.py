"""
Authentication Blueprint
"""

from flask import Blueprint, render_template, request, redirect, url_for, flash, session, current_app
from flask_login import login_user, logout_user, login_required, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from app.models import Admin, Passenger, db

auth = Blueprint('auth', __name__)

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

@auth.route('/login', methods=['GET', 'POST'])
def login():
    """Admin login route"""
    if current_user.is_authenticated:
        if session.get('user_type') == 'admin':
            return redirect(url_for('admin.dashboard'))
        else:
            # Allow switching to admin role - just show a warning but allow access
            flash('Switching to dispatcher mode. You can access both sides simultaneously.', 'info')
    
    if request.method == 'POST':
        try:
            # Debug logging for login attempts
            current_app.logger.info(f"Login POST request received")
            current_app.logger.info(f"Content-Type: {request.content_type}")
            current_app.logger.info(f"Form data keys: {list(request.form.keys())}")
            current_app.logger.info(f"Has CSRF token: {'csrf_token' in request.form}")
            
            username = request.form.get('username', '').strip()
            password = request.form.get('password', '')
            
            current_app.logger.info(f"Username provided: {bool(username)}")
            current_app.logger.info(f"Password provided: {bool(password)}")
            
            if not username or not password:
                current_app.logger.warning("Missing username or password")
                flash('Username and password are required', 'danger')
                return render_template('login.html')
            
            admin = Admin.query.filter_by(username=username).first()
            if admin and admin.check_password(password):
                current_app.logger.info(f"Login successful for user: {username}")
                login_user(admin)
                session['user_type'] = 'admin'
                return redirect(url_for('admin.dashboard'))
            else:
                current_app.logger.warning(f"Login failed for user: {username}")
                flash('Invalid username or password', 'danger')
                return render_template('login.html')
        except Exception as e:
            current_app.logger.error(f"Login error: {str(e)}")
            flash('Login error occurred', 'danger')
            return render_template('login.html'), 500
    
    return render_template('login.html')

@auth.route('/passenger/login', methods=['GET', 'POST'])
def passenger_login():
    """Passenger login route"""
    if current_user.is_authenticated:
        if session.get('user_type') == 'passenger':
            return redirect(url_for('passenger.app'))
        else:
            # Allow switching to passenger role - just show a warning but allow access
            flash('Switching to passenger mode. You can access both sides simultaneously.', 'info')
    
    if request.method == 'POST':
        phone_number_input = request.form.get('phone_number', '').strip()
        password = request.form.get('password', '')
        
        if not phone_number_input or not password:
            flash('Phone number and password are required.', 'danger')
            return render_template('passenger_login.html')
        
        phone_number = "+251" + phone_number_input
        passenger = Passenger.query.filter_by(phone_number=phone_number).first()
        
        if passenger and passenger.check_password(password):
            login_user(passenger)
            session['user_type'] = 'passenger'
            return redirect(url_for('passenger.app'))
        else:
            flash('Invalid phone number or password.', 'danger')
    
    return render_template('passenger_login.html')

@auth.route('/passenger/signup', methods=['GET', 'POST'])
def passenger_signup():
    """Passenger signup route"""
    if current_user.is_authenticated and session.get('user_type') == 'passenger':
        return redirect(url_for('passenger.app'))
    
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        phone_number_input = request.form.get('phone_number', '').strip()
        password = request.form.get('password', '')
        
        # Validation
        if not username or not phone_number_input or not password:
            flash('All fields are required.', 'danger')
            return render_template('passenger_signup.html')
        
        if len(password) < 6:
            flash('Password must be at least 6 characters long.', 'danger')
            return render_template('passenger_signup.html')
        
        # Sanitize phone number
        phone_number = "+251" + phone_number_input
        if not phone_number_input.isdigit() or len(phone_number_input) != 9:
            flash('Invalid phone number format. Please enter 9 digits.', 'danger')
            return render_template('passenger_signup.html')
        
        # Check if passenger exists
        existing_passenger = Passenger.query.filter_by(phone_number=phone_number).first()
        if existing_passenger:
            flash('Phone number already registered.', 'danger')
            return redirect(url_for('auth.passenger_signup'))
        
        # Create new passenger
        new_passenger = Passenger(
            username=username,
            phone_number=phone_number
        )
        new_passenger.set_password(password)
        db.session.add(new_passenger)
        db.session.flush()
        new_passenger.passenger_uid = f"PAX-{new_passenger.id:05d}"
        db.session.commit()
        
        flash('Account created successfully! Please log in.', 'success')
        return redirect(url_for('auth.passenger_login'))
    
    return render_template('passenger_signup.html')

@auth.route('/switch-role/<role>')
@login_required
def switch_role(role):
    """Switch between admin and passenger roles without logging out"""
    if role in ['admin', 'passenger']:
        session['user_type'] = role
        flash(f'Switched to {role} mode. You can now access both sides simultaneously.', 'success')
        
        if role == 'admin':
            return redirect(url_for('admin.dashboard'))
        else:
            return redirect(url_for('passenger.app'))
    else:
        flash('Invalid role specified.', 'error')
        return redirect(url_for('admin.dashboard'))

@auth.route('/logout')
@login_required
def logout():
    """Logout route for both admin and passenger"""
    user_type = session.get('user_type')
    logout_user()
    session.pop('user_type', None)
    
    if user_type == 'admin':
        return redirect(url_for('auth.login'))
    else:
        return redirect(url_for('auth.passenger_login'))
