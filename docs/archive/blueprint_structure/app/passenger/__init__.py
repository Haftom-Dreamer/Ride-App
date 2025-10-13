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
    @login_required  
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or session.get('user_type') != 'passenger':
            flash('Please log in to access this page.', 'warning')
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
        current_password = request.form.get('current_password')
        if not passenger_user.check_password(current_password):
            flash('Your current password is not correct.', 'danger')
            return redirect(url_for('passenger.profile'))
        
        passenger_user.username = request.form.get('username', passenger_user.username)
        
        new_password = request.form.get('new_password')
        if new_password:
            passenger_user.set_password(new_password)
        
        if 'profile_picture' in request.files:
            try:
                passenger_user.profile_picture = handle_file_upload(
                    request.files['profile_picture'], 
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
