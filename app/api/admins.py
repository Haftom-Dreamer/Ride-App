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

@api.route('/admins')
@admin_required
def get_admins():
    """Get all admin users"""
    try:
        admins = Admin.query.all()
        admins_data = [
            {
                'id': admin.id,
                'username': admin.username,
                'email': admin.email,
                'created_at': admin.created_at.isoformat() if admin.created_at else None,
                'profile_picture': admin.profile_picture
            }
            for admin in admins
        ]
        return jsonify(admins_data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@api.route('/admins/add', methods=['POST'])
@admin_required
def add_admin():
    """Add a new admin user"""
    try:
        data = request.get_json()
        username = data.get('username', '').strip()
        password = data.get('password', '').strip()
        
        if not username or not password:
            return jsonify({'error': 'Username and password are required'}), 400
        
        # Check if username already exists
        existing_admin = Admin.query.filter_by(username=username).first()
        if existing_admin:
            return jsonify({'error': 'Username already exists'}), 409
        
        # Create new admin
        admin = Admin(
            username=username,
            email=f"{username}@admin.local"  # Default email
        )
        admin.set_password(password)
        
        db.session.add(admin)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Admin added successfully',
            'admin': {
                'id': admin.id,
                'username': admin.username,
                'email': admin.email
            }
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api.route('/admins/delete', methods=['POST'])
@admin_required
def delete_admin():
    """Delete an admin user"""
    try:
        data = request.get_json()
        admin_id = data.get('admin_id')
        
        if not admin_id:
            return jsonify({'error': 'Admin ID is required'}), 400
        
        # Prevent deleting self
        if admin_id == current_user.id:
            return jsonify({'error': 'Cannot delete your own account'}), 400
        
        admin = Admin.query.get(admin_id)
        if not admin:
            return jsonify({'error': 'Admin not found'}), 404
        
        db.session.delete(admin)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Admin deleted successfully'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api.route('/admins/change-password', methods=['POST'])
@admin_required
def change_admin_password():
    """Change admin password"""
    try:
        data = request.get_json()
        current_password = data.get('current_password', '').strip()
        new_password = data.get('new_password', '').strip()
        confirm_password = data.get('confirm_password', '').strip()
        
        if not current_password or not new_password or not confirm_password:
            return jsonify({'error': 'All password fields are required'}), 400
        
        if new_password != confirm_password:
            return jsonify({'error': 'New passwords do not match'}), 400
        
        if len(new_password) < 6:
            return jsonify({'error': 'New password must be at least 6 characters long'}), 400
        
        # Verify current password
        if not current_user.check_password(current_password):
            return jsonify({'error': 'Current password is incorrect'}), 400
        
        # Update password
        current_user.set_password(new_password)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Password changed successfully'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@api.route('/drivers/pending', methods=['GET'])
@admin_required
def list_pending_drivers():
    """List drivers with status Pending for approval"""
    pending = Driver.query.filter_by(status='Pending').all()
    return jsonify([
        {
            'id': d.id,
            'name': d.name,
            'phone_number': d.phone_number,
            'vehicle_type': d.vehicle_type,
            'vehicle_details': d.vehicle_details,
            'vehicle_plate_number': d.vehicle_plate_number,
            'status': d.status,
        } for d in pending
    ]), 200


@api.route('/drivers/approve', methods=['POST'])
@admin_required
def approve_driver():
    """Approve a pending driver; set status to Offline"""
    try:
        data = request.get_json() or {}
        driver_id = data.get('driver_id')
        if not driver_id:
            return jsonify({'error': 'driver_id is required'}), 400
        d = Driver.query.get(driver_id)
        if not d:
            return jsonify({'error': 'Driver not found'}), 404
        d.status = 'Offline'
        db.session.commit()
        return jsonify({
            'success': True,
            'message': 'Driver approved',
            'driver_id': d.id,
            'status': d.status
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@api.route('/drivers/reject', methods=['POST'])
@admin_required
def reject_driver():
    """Reject a pending driver; set status to Blocked and optional reason"""
    try:
        data = request.get_json() or {}
        driver_id = data.get('driver_id')
        reason = (data.get('reason') or '').strip() or 'Rejected by admin'
        if not driver_id:
            return jsonify({'error': 'driver_id is required'}), 400
        d = Driver.query.get(driver_id)
        if not d:
            return jsonify({'error': 'Driver not found'}), 404
        d.is_blocked = True
        d.blocked_reason = reason
        d.blocked_at = datetime.now(timezone.utc)
        d.status = 'Offline'
        db.session.commit()
        return jsonify({
            'success': True,
            'message': 'Driver rejected',
            'driver_id': d.id
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
