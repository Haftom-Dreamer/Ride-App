"""
Admin/Dashboard Blueprint
"""

from flask import Blueprint, render_template, redirect, url_for, session
from flask_login import login_required, current_user
from functools import wraps

admin = Blueprint('admin', __name__)

def admin_required(f):
    """Decorator to require admin authentication"""
    @wraps(f)
    @login_required
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or session.get('user_type') != 'admin':
            from flask import flash
            flash('You must be logged in as a dispatcher to view this page.', 'danger')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function

@admin.route('/')
@admin.route('/dashboard')
@admin_required
def dashboard():
    """Main dispatcher dashboard"""
    return render_template('dashboard.html')
