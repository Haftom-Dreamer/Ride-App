"""
Passenger Blueprint
"""

from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from flask_login import login_required, current_user
from app.models import db
from app.utils import handle_file_upload
from functools import wraps

passenger = Blueprint('passenger', __name__)

def passenger_required(f):
    """Decorator to require passenger authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Check if user is authenticated and is a passenger
        if not current_user.is_authenticated or session.get('user_type') != 'passenger':
            flash('Please log in as a passenger to access this page.', 'warning')
            return redirect(url_for('auth.passenger_login'))
        return f(*args, **kwargs)
    return decorated_function

@passenger.route('/passenger')
def home():
    """Passenger home route"""
    if current_user.is_authenticated and session.get('user_type') == 'passenger':
        return redirect(url_for('passenger.app'))
    return redirect(url_for('auth.passenger_login'))

@passenger.route('/request')
@passenger_required
def app():
    """Main passenger app for requesting rides"""
    return render_template('passenger.html')

@passenger.route('/passenger/profile', methods=['GET', 'POST'])
@passenger_required
def profile():
    """Passenger profile management"""
    passenger_user = current_user
    
    if request.method == 'POST':
        # Check if this is just a profile picture update
        current_password = request.form.get('current_password', '').strip()
        new_username = request.form.get('username', '').strip()
        new_password = request.form.get('new_password', '').strip()
        
        # Password required only if changing username or password
        password_required = new_username != passenger_user.username or new_password
        
        if password_required:
            if not current_password:
                flash('Please enter your current password to make changes.', 'warning')
                return redirect(url_for('passenger.profile'))
            
            if not passenger_user.check_password(current_password):
                flash('Your current password is not correct.', 'danger')
                return redirect(url_for('passenger.profile'))
            
            # Update username if changed
            if new_username and new_username != passenger_user.username:
                passenger_user.username = new_username
            
            # Update password if provided
            if new_password:
                passenger_user.set_password(new_password)
        
        # Profile picture can be updated without password
        if 'profile_picture' in request.files:
            file = request.files['profile_picture']
            if file and file.filename:
                try:
                    passenger_user.profile_picture = handle_file_upload(
                        file, 
                        passenger_user.profile_picture
                    )
                except ValueError as e:
                    flash(str(e), 'danger')
                    return redirect(url_for('passenger.profile'))

        db.session.commit()
        flash('Profile updated successfully!', 'success')
        return redirect(url_for('passenger.profile'))

    return render_template('passenger_profile.html')

@passenger.route('/passenger/history')
@passenger_required
def history():
    """Passenger ride history"""
    return render_template('passenger_history.html')

@passenger.route('/passenger/support')
@passenger_required
def support():
    """Passenger support page"""
    return render_template('Passenger Support.html')
