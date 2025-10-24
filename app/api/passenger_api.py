from flask import Blueprint, request, jsonify, current_app
from flask_login import login_required, current_user
from app.models import db, Passenger, SavedPlace, PasswordReset, Ride
from app.utils.email_service import send_verification_email
from datetime import datetime, timedelta
import secrets
import re

passenger_api = Blueprint('passenger_api', __name__, url_prefix='/api/passenger')

@passenger_api.route('/profile', methods=['GET'])
@login_required
def get_profile():
    """Get current passenger profile"""
    try:
        if not hasattr(current_user, 'passenger_uid'):
            return {'error': 'Not a passenger account'}, 403
        
        return {
            'success': True,
            'user': {
                'id': current_user.id,
                'username': current_user.username,
                'email': current_user.email,
                'phone_number': current_user.phone_number,
                'passenger_uid': current_user.passenger_uid,
                'profile_picture': current_user.profile_picture,
                'created_at': current_user.created_at.isoformat() if current_user.created_at else None
            }
        }, 200
    except Exception as e:
        current_app.logger.error(f"Get profile failed: {str(e)}")
        return {'error': 'Failed to get profile'}, 500

@passenger_api.route('/profile', methods=['PUT'])
@login_required
def update_profile():
    """Update passenger profile"""
    try:
        if not hasattr(current_user, 'passenger_uid'):
            return {'error': 'Not a passenger account'}, 403
        
        data = request.get_json()
        if not data:
            return {'error': 'No data provided'}, 400
        
        # Update username if provided
        if 'username' in data:
            new_username = data['username'].strip()
            if new_username and len(new_username) >= 3:
                current_user.username = new_username
            else:
                return {'error': 'Username must be at least 3 characters'}, 400
        
        # Update email if provided
        if 'email' in data:
            new_email = data['email'].strip()
            if new_email:
                # Validate email format
                email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
                if not re.match(email_pattern, new_email):
                    return {'error': 'Invalid email format'}, 400
                
                # Check if email is already in use by another user
                existing_user = Passenger.query.filter(
                    Passenger.email == new_email,
                    Passenger.id != current_user.id
                ).first()
                if existing_user:
                    return {'error': 'Email already in use'}, 400
                
                current_user.email = new_email
        
        # Update phone number if provided
        if 'phone_number' in data:
            new_phone = data['phone_number'].strip()
            if new_phone:
                # Validate phone format
                if not new_phone.startswith('+251'):
                    return {'error': 'Phone number must start with +251'}, 400
                
                # Check if phone is already in use by another user
                existing_user = Passenger.query.filter(
                    Passenger.phone_number == new_phone,
                    Passenger.id != current_user.id
                ).first()
                if existing_user:
                    return {'error': 'Phone number already in use'}, 400
                
                current_user.phone_number = new_phone
        
        # Update profile picture if provided
        if 'profile_picture' in data:
            current_user.profile_picture = data['profile_picture']
        
        db.session.commit()
        
        return {
            'success': True,
            'message': 'Profile updated successfully',
            'user': {
                'id': current_user.id,
                'username': current_user.username,
                'email': current_user.email,
                'phone_number': current_user.phone_number,
                'passenger_uid': current_user.passenger_uid,
                'profile_picture': current_user.profile_picture
            }
        }, 200
        
    except Exception as e:
        current_app.logger.error(f"Update profile failed: {str(e)}")
        db.session.rollback()
        return {'error': 'Failed to update profile'}, 500

@passenger_api.route('/change-password', methods=['POST'])
@login_required
def change_password():
    """Change passenger password"""
    try:
        if not hasattr(current_user, 'passenger_uid'):
            return {'error': 'Not a passenger account'}, 403
        
        data = request.get_json()
        if not data:
            return {'error': 'No data provided'}, 400
        
        current_password = data.get('current_password', '').strip()
        new_password = data.get('new_password', '').strip()
        
        if not current_password or not new_password:
            return {'error': 'Current password and new password are required'}, 400
        
        # Verify current password
        if not current_user.check_password(current_password):
            return {'error': 'Current password is incorrect'}, 400
        
        # Validate new password
        if len(new_password) < 6:
            return {'error': 'New password must be at least 6 characters'}, 400
        
        # Set new password
        current_user.set_password(new_password)
        db.session.commit()
        
        return {'success': True, 'message': 'Password changed successfully'}, 200
        
    except Exception as e:
        current_app.logger.error(f"Change password failed: {str(e)}")
        db.session.rollback()
        return {'error': 'Failed to change password'}, 500

@passenger_api.route('/saved-places', methods=['GET'])
@login_required
def get_saved_places():
    """Get passenger's saved places"""
    try:
        if not hasattr(current_user, 'passenger_uid'):
            return {'error': 'Not a passenger account'}, 403
        
        places = SavedPlace.query.filter_by(passenger_id=current_user.id).all()
        
        return {
            'success': True,
            'places': [
                {
                    'id': place.id,
                    'label': place.label,
                    'address': place.address,
                    'latitude': place.latitude,
                    'longitude': place.longitude,
                    'created_at': place.created_at.isoformat()
                }
                for place in places
            ]
        }, 200
        
    except Exception as e:
        current_app.logger.error(f"Get saved places failed: {str(e)}")
        return {'error': 'Failed to get saved places'}, 500

@passenger_api.route('/saved-places', methods=['POST'])
@login_required
def add_saved_place():
    """Add a new saved place"""
    try:
        if not hasattr(current_user, 'passenger_uid'):
            return {'error': 'Not a passenger account'}, 403
        
        data = request.get_json()
        if not data:
            return {'error': 'No data provided'}, 400
        
        label = data.get('label', '').strip()
        address = data.get('address', '').strip()
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        if not label or not address or latitude is None or longitude is None:
            return {'error': 'Label, address, latitude, and longitude are required'}, 400
        
        # Check if label already exists for this user
        existing_place = SavedPlace.query.filter_by(
            passenger_id=current_user.id,
            label=label
        ).first()
        if existing_place:
            return {'error': 'A place with this label already exists'}, 400
        
        # Create new saved place
        new_place = SavedPlace(
            passenger_id=current_user.id,
            label=label,
            address=address,
            latitude=latitude,
            longitude=longitude
        )
        
        db.session.add(new_place)
        db.session.commit()
        
        return {
            'success': True,
            'message': 'Saved place added successfully',
            'place': {
                'id': new_place.id,
                'label': new_place.label,
                'address': new_place.address,
                'latitude': new_place.latitude,
                'longitude': new_place.longitude,
                'created_at': new_place.created_at.isoformat()
            }
        }, 201
        
    except Exception as e:
        current_app.logger.error(f"Add saved place failed: {str(e)}")
        db.session.rollback()
        return {'error': 'Failed to add saved place'}, 500

@passenger_api.route('/saved-places/<int:place_id>', methods=['DELETE'])
@login_required
def delete_saved_place(place_id):
    """Delete a saved place"""
    try:
        if not hasattr(current_user, 'passenger_uid'):
            return {'error': 'Not a passenger account'}, 403
        
        place = SavedPlace.query.filter_by(
            id=place_id,
            passenger_id=current_user.id
        ).first()
        
        if not place:
            return {'error': 'Saved place not found'}, 404
        
        db.session.delete(place)
        db.session.commit()
        
        return {'success': True, 'message': 'Saved place deleted successfully'}, 200
        
    except Exception as e:
        current_app.logger.error(f"Delete saved place failed: {str(e)}")
        db.session.rollback()
        return {'error': 'Failed to delete saved place'}, 500

@passenger_api.route('/password-reset/request', methods=['POST'])
def request_password_reset():
    """Request password reset code"""
    try:
        data = request.get_json()
        if not data:
            return {'error': 'No data provided'}, 400
        
        email = data.get('email', '').strip()
        if not email:
            return {'error': 'Email is required'}, 400
        
        # Validate email format
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            return {'error': 'Invalid email format'}, 400
        
        # Check if user exists
        passenger = Passenger.query.filter_by(email=email).first()
        if not passenger:
            return {'error': 'No account found with this email'}, 404
        
        # Check for recent reset requests (rate limiting)
        recent_resets = PasswordReset.query.filter(
            PasswordReset.email == email,
            PasswordReset.created_at >= datetime.utcnow() - timedelta(minutes=5)
        ).count()
        
        if recent_resets >= 3:
            return {'error': 'Too many reset requests. Please wait 5 minutes.'}, 429
        
        # Generate reset code
        reset_code = secrets.token_hex(4).upper()
        expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        # Create or update reset record
        existing_reset = PasswordReset.query.filter_by(email=email).first()
        if existing_reset:
            existing_reset.reset_code = reset_code
            existing_reset.expires_at = expires_at
            existing_reset.is_used = False
        else:
            new_reset = PasswordReset(
                email=email,
                reset_code=reset_code,
                expires_at=expires_at
            )
            db.session.add(new_reset)
        
        db.session.commit()
        
        # Send reset email
        from app.utils.email_service import send_password_reset_email
        success, message = send_password_reset_email(email, reset_code)
        
        if success:
            return {'success': True, 'message': 'Reset code sent to your email'}, 200
        else:
            return {'error': f'Failed to send email: {message}'}, 500
        
    except Exception as e:
        current_app.logger.error(f"Request password reset failed: {str(e)}")
        db.session.rollback()
        return {'error': 'Failed to request password reset'}, 500

@passenger_api.route('/password-reset/verify', methods=['POST'])
def verify_password_reset():
    """Verify reset code and update password"""
    try:
        data = request.get_json()
        if not data:
            return {'error': 'No data provided'}, 400
        
        email = data.get('email', '').strip()
        reset_code = data.get('reset_code', '').strip()
        new_password = data.get('new_password', '').strip()
        
        if not email or not reset_code or not new_password:
            return {'error': 'Email, reset code, and new password are required'}, 400
        
        # Validate new password
        if len(new_password) < 6:
            return {'error': 'New password must be at least 6 characters'}, 400
        
        # Find reset record
        reset_record = PasswordReset.query.filter_by(
            email=email,
            reset_code=reset_code,
            is_used=False
        ).first()
        
        if not reset_record:
            return {'error': 'Invalid or expired reset code'}, 400
        
        # Check if code has expired
        if reset_record.expires_at < datetime.utcnow():
            return {'error': 'Reset code has expired'}, 400
        
        # Find user and update password
        passenger = Passenger.query.filter_by(email=email).first()
        if not passenger:
            return {'error': 'User not found'}, 404
        
        passenger.set_password(new_password)
        reset_record.is_used = True
        
        db.session.commit()
        
        return {'success': True, 'message': 'Password reset successfully'}, 200
        
    except Exception as e:
        current_app.logger.error(f"Verify password reset failed: {str(e)}")
        db.session.rollback()
        return {'error': 'Failed to reset password'}, 500


@passenger_api.route('/ride-history', methods=['GET'])
@login_required
def get_ride_history():
    """Get passenger's ride history"""
    try:
        if not hasattr(current_user, 'passenger_uid'):
            return {'error': 'Not a passenger account'}, 403
        
        # Get all rides for this passenger
        rides = Ride.query.filter_by(passenger_id=current_user.id).order_by(Ride.request_time.desc()).all()
        
        return {
            'success': True,
            'rides': [
                {
                    'id': ride.id,
                    'pickup_address': ride.pickup_address,
                    'dest_address': ride.dest_address,
                    'distance_km': float(ride.distance_km),
                    'fare': float(ride.fare),
                    'vehicle_type': ride.vehicle_type,
                    'status': ride.status,
                    'request_time': ride.request_time.isoformat(),
                    'assigned_time': ride.assigned_time.isoformat() if ride.assigned_time else None,
                    'note': ride.note,
                    'payment_method': ride.payment_method,
                }
                for ride in rides
            ]
        }, 200
        
    except Exception as e:
        current_app.logger.error(f"Get ride history failed: {str(e)}")
        return {'error': 'Failed to get ride history'}, 500