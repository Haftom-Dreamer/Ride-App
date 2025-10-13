"""
Custom decorators for authentication and authorization
"""

from functools import wraps
from flask import session, jsonify, redirect, url_for, flash, request
from flask_login import current_user

def admin_required(f):
    """Decorator to require admin authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or session.get('user_type') != 'admin':
            # Return JSON for API requests, HTML redirect for page requests
            if request.path.startswith('/api/'):
                return jsonify({'error': 'Authentication required. Please log in as a dispatcher.'}), 401
            flash('You must be logged in as a dispatcher to view this page.', 'danger')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function

def passenger_required(f):
    """Decorator to require passenger authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or session.get('user_type') != 'passenger':
            # Return JSON for API requests, HTML redirect for page requests
            if request.path.startswith('/api/'):
                return jsonify({'error': 'Authentication required. Please log in as a passenger.'}), 401
            flash('Please log in to access this page.', 'warning')
            return redirect(url_for('auth.passenger_login'))
        return f(*args, **kwargs)
    return decorated_function
