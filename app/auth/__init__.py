"""
Authentication Blueprint
"""

from flask import Blueprint, render_template, request, redirect, url_for, flash, session, current_app
from flask_login import login_user, logout_user, login_required, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from app.models import Admin, Passenger, db, EmailVerification

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
        
        # Check if this is an API request (from Flutter app)
        content_type = request.headers.get('Content-Type', '')
        if 'application/x-www-form-urlencoded' in content_type:
            # This is an API request from Flutter app
            if not phone_number_input or not password:
                return {'error': 'Phone number and password are required.'}, 400
            
            # Handle different phone number formats
            if phone_number_input.startswith('+251'):
                phone_number = phone_number_input
            elif phone_number_input.startswith('251'):
                phone_number = '+' + phone_number_input
            elif phone_number_input.startswith('0'):
                phone_number = '+251' + phone_number_input[1:]
            else:
                phone_number = '+251' + phone_number_input
            
            passenger = Passenger.query.filter_by(phone_number=phone_number).first()
            
            if passenger and passenger.check_password(password):
                login_user(passenger)
                session['user_type'] = 'passenger'
                
                # Return JSON response with user data
                return {
                    'success': True,
                    'message': 'Login successful',
                    'user': {
                        'id': passenger.id,
                        'username': passenger.username,
                        'email': passenger.email,
                        'phone_number': passenger.phone_number,
                        'passenger_uid': passenger.passenger_uid,
                        'profile_picture': passenger.profile_picture
                    }
                }, 200
            else:
                return {'error': 'Invalid phone number or password.'}, 401
        
        # Regular web form request
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
    # FIRST LINE - ABSOLUTE FIRST THING TO EXECUTE
    with open('C:/Users/H.Dreamer/Documents/Adobe/RIDE/FUNCTION_CALLED.txt', 'a') as f:
        from datetime import datetime
        f.write(f"{datetime.now()} - passenger_signup() was called! Method: {request.method}\n")
    
    if current_user.is_authenticated and session.get('user_type') == 'passenger':
        return redirect(url_for('passenger.app'))
    
    # Debug: Log ALL POST requests to see what we're receiving
    if request.method == 'POST':
        import sys
        from datetime import datetime
        
        # Write to file to PROVE the code is executing
        with open('debug_signup.log', 'a') as f:
            f.write(f"\n{datetime.now()} - POST request received\n")
            f.write(f"Content-Type: {request.headers.get('Content-Type')}\n")
            f.write(f"Form data: {dict(request.form)}\n")
        
        sys.stdout.write("\n" + "="*60 + "\n")
        sys.stdout.write("📥 POST REQUEST TO /auth/passenger/signup\n")
        sys.stdout.write("="*60 + "\n")
        sys.stdout.write(f"Content-Type: {request.headers.get('Content-Type')}\n")
        sys.stdout.write(f"Accept: {request.headers.get('Accept')}\n")
        sys.stdout.write(f"User-Agent: {request.headers.get('User-Agent', 'Not provided')[:50]}\n")
        sys.stdout.write(f"Form data keys: {list(request.form.keys())}\n")
        sys.stdout.write("="*60 + "\n\n")
        sys.stdout.flush()
    
    # Check if this is an API request (from Flutter app)
    content_type = request.headers.get('Content-Type', '')
    if request.method == 'POST' and 'application/x-www-form-urlencoded' in content_type:
        # This is an API request from Flutter app
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        phone_number_input = request.form.get('phone_number', '').strip()
        password = request.form.get('password', '')
        verification_code = request.form.get('verification_code', '').strip()
        
        print(f"\n{'='*60}")
        print(f"🚀 API SIGNUP REQUEST RECEIVED")
        print(f"{'='*60}")
        print(f"📧 Email: {email}")
        print(f"👤 Username: {username}")
        print(f"📱 Phone: {phone_number_input}")
        print(f"🔑 Verification code: {verification_code if verification_code else 'Not provided (initial signup)'}")
        print(f"{'='*60}\n")
        
        # Validation
        if not username or not email or not phone_number_input or not password:
            return {'error': 'All fields are required.'}, 400
        
        if len(password) < 6:
            return {'error': 'Password must be at least 6 characters long.'}, 400
        
        # Validate email format
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            return {'error': 'Invalid email format.'}, 400
        
        # Sanitize phone number - accept both 9 digits (0912345678) and 10 digits (+251912345678 or 0912345678)
        if phone_number_input.startswith('+251'):
            # Already has country code
            phone_number = phone_number_input
            phone_digits = phone_number_input[4:]  # Remove +251
        elif phone_number_input.startswith('251'):
            # Has country code without +
            phone_number = '+' + phone_number_input
            phone_digits = phone_number_input[3:]
        elif phone_number_input.startswith('0'):
            # Ethiopian format with leading 0 (e.g., 0912345678)
            phone_number = "+251" + phone_number_input[1:]  # Remove 0, add +251
            phone_digits = phone_number_input[1:]
        else:
            # Assume it's 9 digits without leading 0
            phone_number = "+251" + phone_number_input
            phone_digits = phone_number_input
        
        # Validate: should be 9 digits after country code
        if not phone_digits.isdigit() or len(phone_digits) != 9:
            return {'error': 'Invalid phone number format. Please enter 9 digits (e.g., 0912345678 or 912345678).'}, 400
        
        # Check if phone number is already registered (before sending verification email)
        existing_passenger = Passenger.query.filter_by(phone_number=phone_number).first()
        if existing_passenger:
            return {'error': 'Phone number already registered.'}, 400
        
        # Check if email is already registered (before sending verification email)
        existing_email = Passenger.query.filter_by(email=email).first()
        if existing_email:
            return {'error': 'Email already registered.'}, 400
        
        # If verification code is provided, verify it first
        if verification_code:
            from app.utils.email_service import verify_email_code
            is_verified, message = verify_email_code(email, verification_code)
            if not is_verified:
                return {'error': message}, 400
            
            # Phone number already checked before sending verification email
            
            # Create new passenger
            new_passenger = Passenger(
                username=username,
                email=email,
                phone_number=phone_number
            )
            new_passenger.set_password(password)
            db.session.add(new_passenger)
            db.session.flush()
            new_passenger.passenger_uid = f"PAX-{new_passenger.id:05d}"
            
            # Mark verification as used only after successful account creation
            from app.models import EmailVerification
            verification_record = EmailVerification.query.filter_by(
                email=email,
                verification_code=verification_code
            ).first()
            if verification_record:
                verification_record.is_verified = True
            db.session.commit()
            
            # Emit real-time notification to dispatchers
            try:
                from app.utils.socket_utils import emit_passenger_registration_notification
                emit_passenger_registration_notification({
                    'passenger_id': new_passenger.id,
                    'passenger_uid': new_passenger.passenger_uid,
                    'username': new_passenger.username,
                    'phone_number': new_passenger.phone_number,
                    'email': new_passenger.email,
                    'join_date': new_passenger.join_date.isoformat() if new_passenger.join_date else None
                })
            except Exception as e:
                current_app.logger.error(f"Failed to emit passenger registration notification: {e}")
            
            return {'success': 'Account created successfully! Please log in.'}, 200
        else:
            # Send verification email
            print(f"📧 No verification code provided, sending email to {email}...")
            from app.utils.email_service import send_verification_email
            success, message = send_verification_email(email)
            print(f"📧 Email sending result - Success: {success}, Message: {message}")
            if success:
                print(f"✅ Returning success response to Flutter app")
                return {'success': 'Verification email sent! Please check your email and enter the code.'}, 200
            else:
                print(f"❌ Returning error response to Flutter app")
                return {'error': message}, 400
    
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        phone_number_input = request.form.get('phone_number', '').strip()
        password = request.form.get('password', '')
        verification_code = request.form.get('verification_code', '').strip()
        
        # Validation
        if not username or not email or not phone_number_input or not password:
            flash('All fields are required.', 'danger')
            return render_template('passenger_signup.html')
        
        if len(password) < 6:
            flash('Password must be at least 6 characters long.', 'danger')
            return render_template('passenger_signup.html')
        
        # Validate email format
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            flash('Invalid email format.', 'danger')
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
        
        # If verification code is provided, verify it
        if verification_code:
            from app.utils.email_service import verify_email_code
            is_verified, message = verify_email_code(email, verification_code)
            if not is_verified:
                flash(message, 'danger')
                return render_template('passenger_signup.html')
            
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
        else:
            # Send verification email
            from app.utils.email_service import send_verification_email
            success, message = send_verification_email(email)
            if success:
                flash('Verification email sent! Please check your email and enter the code.', 'info')
                return render_template('passenger_signup.html', email=email, show_verification=True)
            else:
                flash(message, 'danger')
                return render_template('passenger_signup.html')
    
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
    # Check if this is an API request (from Flutter app)
    content_type = request.headers.get('Content-Type', '')
    if 'application/x-www-form-urlencoded' in content_type:
        # This is an API request from Flutter app
        logout_user()
        session.clear()
        return {'success': True, 'message': 'Logged out successfully'}, 200
    
    # Regular web request
    user_type = session.get('user_type')
    logout_user()
    session.pop('user_type', None)
    
    if user_type == 'admin':
        return redirect(url_for('auth.login'))
    else:
        return redirect(url_for('auth.passenger_login'))


@auth.route('/passenger/resend-verification', methods=['POST'])
def resend_verification():
    """Resend verification email with rate limiting"""
    try:
        email = request.form.get('email', '').strip()
        
        if not email:
            return {'error': 'Email is required.'}, 400
        
        # Check if email is valid
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            return {'error': 'Invalid email format.'}, 400
        
        # Rate limiting: Check if user has sent too many requests recently
        from datetime import datetime, timedelta
        recent_verifications = EmailVerification.query.filter(
            EmailVerification.email == email,
            EmailVerification.created_at >= datetime.utcnow() - timedelta(minutes=1)
        ).count()
        
        if recent_verifications >= 3:  # Max 3 requests per minute
            return {'error': 'Too many requests. Please wait 1 minute before requesting another code.'}, 429
        
        # Check if there's an unverified code that's still valid (not expired)
        existing_verification = EmailVerification.query.filter_by(
            email=email,
            is_verified=False
        ).filter(
            EmailVerification.expires_at > datetime.utcnow()
        ).first()
        
        if existing_verification:
            # Don't send new code if there's still a valid unverified one
            return {'error': 'A verification code has already been sent. Please check your email or wait for it to expire.'}, 400
        
        # Send new verification email
        from app.utils.email_service import send_verification_email
        success, message = send_verification_email(email)
        
        if success:
            return {'success': 'Verification code sent successfully!'}, 200
        else:
            return {'error': message}, 400
            
    except Exception as e:
        print(f"❌ Resend verification failed: {str(e)}")
        return {'error': 'Failed to resend verification code.'}, 500

@auth.route('/passenger/password-reset/request', methods=['POST'])
def request_password_reset():
    """Request password reset for passenger"""
    try:
        # Check if this is an API request (from Flutter app)
        content_type = request.headers.get('Content-Type', '')
        if 'application/json' in content_type:
            data = request.get_json()
            email = data.get('email', '').strip()
        else:
            email = request.form.get('email', '').strip()
        
        if not email:
            return {'error': 'Email is required.'}, 400
        
        # Check if email is valid
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            return {'error': 'Invalid email format.'}, 400
        
        # Check if passenger exists with this email
        passenger = Passenger.query.filter_by(email=email).first()
        if not passenger:
            # Don't reveal if email exists or not for security
            return {'success': 'If an account with this email exists, a password reset link has been sent.'}, 200
        
        # Generate 6-digit verification code for reset
        import random
        reset_token = f"{random.randint(0, 999999):06d}"

        # Remove any existing unverified/expired codes for this email
        try:
            EmailVerification.query.filter_by(email=email).delete()
            db.session.commit()
        except Exception:
            db.session.rollback()

        # Store reset token in EmailVerification table with short expiry
        from datetime import datetime, timedelta
        verification = EmailVerification(
            email=email,
            verification_code=reset_token,
            expires_at=datetime.utcnow() + timedelta(minutes=15)
        )
        db.session.add(verification)
        db.session.commit()

        # Send password reset email
        from app.utils.email_service import send_password_reset_email
        success, message = send_password_reset_email(email, reset_token)
        if not success:
            current_app.logger.error(f"Password reset email failed for {email}: {message}")
            # Keep generic response but log failure
            return {'success': 'If an account with this email exists, a password reset link has been sent.'}, 200

        return {'success': 'If an account with this email exists, a password reset link has been sent.'}, 200
        
    except Exception as e:
        print(f"❌ Password reset request failed: {str(e)}")
        return {'error': 'Failed to process password reset request.'}, 500

@auth.route('/passenger/password-reset/confirm', methods=['POST'])
def confirm_password_reset():
    """Confirm password reset with token"""
    try:
        # Check if this is an API request (from Flutter app)
        content_type = request.headers.get('Content-Type', '')
        if 'application/json' in content_type:
            data = request.get_json()
            email = data.get('email', '').strip()
            # Accept both 'token' and 'reset_code' from clients
            token = (data.get('token') or data.get('reset_code') or '').strip()
            new_password = data.get('new_password', '').strip()
        else:
            email = request.form.get('email', '').strip()
            # Accept both 'token' and 'reset_code'
            token = (request.form.get('token') or request.form.get('reset_code') or '').strip()
            new_password = request.form.get('new_password', '').strip()
        
        if not email or not token or not new_password:
            return {'error': 'Email, token and new password are required.'}, 400
        
        if len(new_password) < 6:
            return {'error': 'Password must be at least 6 characters long.'}, 400
        
        # Verify token against EmailVerification
        verification = EmailVerification.query.filter_by(
            email=email,
            verification_code=token
        ).first()

        if not verification:
            return {'error': 'Invalid reset code.'}, 400

        # Check expiry and used status
        try:
            is_expired = verification.is_expired()
        except Exception:
            # Fallback if model lacks helper
            from datetime import datetime
            is_expired = getattr(verification, 'expires_at', None) and verification.expires_at < datetime.utcnow()

        if is_expired:
            return {'error': 'Reset code has expired.'}, 400
        if getattr(verification, 'is_verified', False):
            return {'error': 'Reset code already used.'}, 400

        # Update passenger password
        passenger = Passenger.query.filter_by(email=email).first()
        if not passenger:
            # Generic response; don't reveal account status
            return {'success': 'Password has been reset successfully. Please log in with your new password.'}, 200

        passenger.set_password(new_password)
        # Mark code as used
        try:
            verification.is_verified = True
        except Exception:
            pass
        db.session.commit()

        return {'success': 'Password has been reset successfully. Please log in with your new password.'}, 200
        
    except Exception as e:
        print(f"❌ Password reset confirmation failed: {str(e)}")
        return {'error': 'Failed to reset password.'}, 500

# Compatibility aliases under /api to match mobile client paths
@auth.route('/api/passenger/password-reset/request', methods=['POST'])
def request_password_reset_api_alias():
    return request_password_reset()

@auth.route('/api/passenger/password-reset/confirm', methods=['POST'])
def confirm_password_reset_api_alias():
    return confirm_password_reset()
