"""
Admin operations API endpoints
"""

from flask import request, jsonify
from datetime import datetime, timezone
from app.models import db, Driver, Passenger, Admin
from app.api import api, admin_required
from app.utils import handle_file_upload
from flask_login import current_user

@api.route('/users/block', methods=['POST'])
@admin_required
def block_user():
    """Block a user (driver or passenger)"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        user_type = data.get('user_type')  # 'driver' or 'passenger'
        reason = data.get('reason', 'No reason provided')
        
        if not user_id or not user_type:
            return jsonify({'error': 'Missing user_id or user_type'}), 400
        
        # Get the appropriate user model
        if user_type == 'driver':
            user = Driver.query.get(user_id)
        elif user_type == 'passenger':
            user = Passenger.query.get(user_id)
        else:
            return jsonify({'error': 'Invalid user_type. Must be "driver" or "passenger"'}), 400
        
        if not user:
            return jsonify({'error': f'{user_type.capitalize()} not found'}), 404
        
        # Block the user
        user.is_blocked = True
        user.blocked_reason = reason
        user.blocked_at = datetime.now(timezone.utc)
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': f'{user_type.capitalize()} blocked successfully'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api.route('/users/unblock', methods=['POST'])
@admin_required
def unblock_user():
    """Unblock a user (driver or passenger)"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        user_type = data.get('user_type')  # 'driver' or 'passenger'
        
        if not user_id or not user_type:
            return jsonify({'error': 'Missing user_id or user_type'}), 400
        
        # Get the appropriate user model
        if user_type == 'driver':
            user = Driver.query.get(user_id)
        elif user_type == 'passenger':
            user = Passenger.query.get(user_id)
        else:
            return jsonify({'error': 'Invalid user_type. Must be "driver" or "passenger"'}), 400
        
        if not user:
            return jsonify({'error': f'{user_type.capitalize()} not found'}), 404
        
        # Unblock the user
        user.is_blocked = False
        user.blocked_reason = None
        user.blocked_at = None
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': f'{user_type.capitalize()} unblocked successfully'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api.route('/admins/update-profile', methods=['POST'])
@admin_required
def update_admin_profile():
    """Update admin profile (username and profile picture)"""
    try:
        new_username = request.form.get('username', '').strip()
        profile_picture = request.files.get('profile_picture')
        
        # Update username if provided and different
        if new_username and new_username != current_user.username:
            # Check if username is already taken
            existing_admin = Admin.query.filter_by(username=new_username).first()
            if existing_admin and existing_admin.id != current_user.id:
                return jsonify({'error': 'Username is already taken'}), 409
            current_user.username = new_username
        
        # Update profile picture if provided
        if profile_picture and profile_picture.filename:
            try:
                current_user.profile_picture = handle_file_upload(
                    profile_picture, 
                    current_user.profile_picture
                )
            except ValueError as e:
                return jsonify({'error': str(e)}), 400
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Profile updated successfully',
            'username': current_user.username,
            'profile_picture': current_user.profile_picture
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
