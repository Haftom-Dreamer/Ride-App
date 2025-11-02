"""
Passenger API Routes
Handles all passenger-related API endpoints for the mobile app
"""

from flask import Blueprint, request, jsonify, session
from flask_login import current_user
from app.models import db, Passenger, Ride, Driver, SavedPlace, EmergencyAlert, ChatMessage
from datetime import datetime, timedelta
from sqlalchemy import or_, desc
import math
from app.utils import handle_file_upload
from app.services.push import register_device_token

passenger_api = Blueprint('passenger_api', __name__)

def resolve_current_passenger():
    """Resolve passenger from session or X-User-Id header for mobile API."""
    try:
        if current_user.is_authenticated and hasattr(current_user, 'id'):
            return current_user
    except Exception:
        pass
    try:
        user_id = request.headers.get('X-User-Id')
        if user_id:
            pax = Passenger.query.get(int(user_id))
            return pax
    except Exception:
        pass
    return None

@passenger_api.route('/test', methods=['GET'])
def test_route():
    """Test route to verify blueprint is working"""
    return jsonify({'message': 'Passenger API is working!', 'status': 'success'})

def calculate_distance(lat1, lon1, lat2, lon2):
    """Calculate distance between two points using Haversine formula"""
    R = 6371  # Earth's radius in kilometers
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c

def calculate_fare(distance_km, vehicle_type='Bajaj'):
    """Calculate fare based on distance and vehicle type"""
    base_fare = 50.0 if vehicle_type == 'Bajaj' else 80.0
    rate_per_km = 15.0 if vehicle_type == 'Bajaj' else 25.0
    
    fare = base_fare + (distance_km * rate_per_km)
    return round(fare, 2)

@passenger_api.route('/fare-estimate', methods=['POST'])
def estimate_fare():
    """Calculate fare estimate for a ride"""
    try:
        data = request.get_json()
        
        pickup_lat = float(data.get('pickup_lat'))
        pickup_lon = float(data.get('pickup_lon'))
        dest_lat = float(data.get('dest_lat'))
        dest_lon = float(data.get('dest_lon'))
        vehicle_type = data.get('vehicle_type', 'Bajaj')
        
        # Calculate distance
        distance_km = calculate_distance(pickup_lat, pickup_lon, dest_lat, dest_lon)
        
        # Calculate fare
        estimated_fare = calculate_fare(distance_km, vehicle_type)
        
        return jsonify({
            'distance_km': round(distance_km, 2),
            'estimated_fare': estimated_fare,
            'vehicle_type': vehicle_type
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/ride-request', methods=['POST'])
def request_ride():
    """Submit a new ride request"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json()
        
        # Create new ride
        new_ride = Ride(
            passenger_id=user.id,
            pickup_address=data.get('pickup_address', ''),
            pickup_lat=float(data.get('pickup_lat')),
            pickup_lon=float(data.get('pickup_lon')),
            dest_address=data.get('dest_address'),
            dest_lat=float(data.get('dest_lat')),
            dest_lon=float(data.get('dest_lon')),
            distance_km=float(data.get('distance_km', 0)),
            fare=float(data.get('fare', 0)),
            vehicle_type=data.get('vehicle_type', 'Bajaj'),
            payment_method=data.get('payment_method', 'Cash'),
            note=data.get('note'),
            status='Requested',
            request_time=datetime.utcnow()
        )
        
        db.session.add(new_ride)
        db.session.commit()

        # Broadcast offers to nearby drivers (non-blocking best-effort)
        try:
            from app.services.assigner import broadcast_offers
            broadcast_offers(new_ride)
        except Exception as e:
            # Log but do not fail request
            print(f"Broadcast offers failed: {e}")

        return jsonify({
            'ride_id': new_ride.id,
            'status': 'Requested',
            'message': 'Ride requested successfully'
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/ride-status/<int:ride_id>', methods=['GET'])
def get_ride_status(ride_id):
    """Get current status of a ride"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        ride = Ride.query.filter_by(id=ride_id, passenger_id=user.id).first()
        
        if not ride:
            return jsonify({'error': 'Ride not found'}), 404
        
        response = {
            'ride_id': ride.id,
            'status': ride.status,
            'pickup_address': ride.pickup_address,
            'dest_address': ride.dest_address,
            'fare': ride.fare,
            'vehicle_type': ride.vehicle_type
        }
        
        # If driver is assigned, include driver info
        if ride.driver_id and ride.status in ['Assigned', 'On Trip']:
            driver = Driver.query.get(ride.driver_id)
            if driver:
                response['driver'] = {
                    'name': driver.name,
                    'phone_number': driver.phone_number,
                    'vehicle_details': f"{driver.vehicle_type} - {driver.vehicle_plate_number}",
                    'rating': driver.rating if hasattr(driver, 'rating') else 4.5
                }
        
        # If ride is completed, include details
        if ride.status == 'Completed':
            response['ride_details'] = {
                'dest_address': ride.dest_address,
                'fare': ride.fare,
                'start_time': ride.start_time.isoformat() if ride.start_time else None,
                'end_time': ride.end_time.isoformat() if ride.end_time else None
            }
        
        return jsonify(response), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/cancel-ride', methods=['POST'])
def cancel_ride():
    """Cancel a pending ride"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json()
        ride_id = data.get('ride_id')
        
        ride = Ride.query.filter_by(id=ride_id, passenger_id=user.id).first()
        
        if not ride:
            return jsonify({'error': 'Ride not found'}), 404
        
        if ride.status not in ['Requested', 'Assigned']:
            return jsonify({'error': 'Cannot cancel ride in current status'}), 400
        
        ride.status = 'Cancelled'
        db.session.commit()
        
        return jsonify({'message': 'Ride cancelled successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/rate-ride', methods=['POST'])
def rate_ride():
    """Submit rating and feedback for a completed ride"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json()
        ride_id = data.get('ride_id')
        rating = int(data.get('rating'))
        comment = data.get('comment', '')
        
        ride = Ride.query.filter_by(id=ride_id, passenger_id=user.id).first()
        
        if not ride:
            return jsonify({'error': 'Ride not found'}), 404
        
        if ride.status != 'Completed':
            return jsonify({'error': 'Can only rate completed rides'}), 400
        
        ride.rating = rating
        ride.feedback = comment
        db.session.commit()
        
        return jsonify({'message': 'Rating submitted successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/saved-places', methods=['GET'])
def get_saved_places():
    """Get all saved places for current user"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        places = SavedPlace.query.filter_by(passenger_id=user.id).all()
        
        return jsonify([{
                    'id': place.id,
                    'label': place.label,
                    'address': place.address,
                    'latitude': place.latitude,
            'longitude': place.longitude
        } for place in places]), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/saved-places', methods=['POST'])
def add_saved_place():
    """Add or update a saved place"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json()
        
        place_id = data.get('id')
        
        if place_id:
            # Update existing place
            place = SavedPlace.query.filter_by(id=place_id, passenger_id=user.id).first()
            if not place:
                return jsonify({'error': 'Place not found'}), 404
            
            place.label = data.get('label', place.label)
            place.address = data.get('address', place.address)
            place.latitude = float(data.get('latitude', place.latitude))
            place.longitude = float(data.get('longitude', place.longitude))
        else:
            # Create new place
            place = SavedPlace(
            passenger_id=user.id,
                label=data.get('label'),
                address=data.get('address'),
                latitude=float(data.get('latitude')),
                longitude=float(data.get('longitude'))
            )
            db.session.add(place)
        
        db.session.commit()
        
        return jsonify({
            'id': place.id,
            'label': place.label,
            'address': place.address,
            'latitude': place.latitude,
            'longitude': place.longitude
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/saved-places/<int:place_id>', methods=['DELETE'])
def delete_saved_place(place_id):
    """Delete a saved place"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        place = SavedPlace.query.filter_by(id=place_id, passenger_id=user.id).first()
        
        if not place:
            return jsonify({'error': 'Place not found'}), 404
        
        db.session.delete(place)
        db.session.commit()
        
        return jsonify({'message': 'Place deleted successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/emergency-sos', methods=['POST'])
def emergency_sos():
    """Handle emergency SOS alert"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json()
        
        alert = EmergencyAlert(
            passenger_id=user.id,
            ride_id=data.get('ride_id'),
            latitude=float(data.get('latitude', 0)),
            longitude=float(data.get('longitude', 0)),
            message=data.get('message', 'Emergency SOS activated'),
            alert_time=datetime.utcnow()
        )
        
        db.session.add(alert)
        db.session.commit()
        
        # TODO: Send notifications to admin/support
        
        return jsonify({
            'message': 'Emergency alert sent',
            'emergency_contact': '911',
            'support_contact': '+251-XXX-XXXX'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400


@passenger_api.route('/register-token', methods=['POST'])
def passenger_register_token():
    """Register push token for passenger"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json() or {}
        token = (data.get('token') or '').strip()
        platform = (data.get('platform') or '').strip() or None
        if not token:
            return jsonify({'error': 'token is required'}), 400
        register_device_token('passenger', user.id, token, platform)
        return jsonify({'message': 'Token registered'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/ride-history', methods=['GET'])
def get_ride_history():
    """Get ride history with pagination"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        status_filter = request.args.get('status', None)
        
        query = Ride.query.filter_by(passenger_id=user.id)
        
        if status_filter:
            query = query.filter_by(status=status_filter)
        
        query = query.order_by(desc(Ride.request_time))
        
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        
        rides = [{
            'id': ride.id,
            'pickup_address': ride.pickup_address,
            'dest_address': ride.dest_address,
            'fare': ride.fare,
            'status': ride.status,
            'vehicle_type': ride.vehicle_type,
            'request_time': ride.request_time.isoformat(),
            'end_time': ride.end_time.isoformat() if ride.end_time else None
        } for ride in pagination.items]
        
        return jsonify({
            'rides': rides,
            'page': page,
            'per_page': per_page,
            'total': pagination.total,
            'pages': pagination.pages
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/ride-details/<int:ride_id>', methods=['GET'])
def get_ride_details(ride_id):
    """Get detailed information about a specific ride"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        ride = Ride.query.filter_by(id=ride_id, passenger_id=user.id).first()
        
        if not ride:
            return jsonify({'error': 'Ride not found'}), 404
        
        details = {
                    'id': ride.id,
                    'pickup_address': ride.pickup_address,
            'pickup_lat': ride.pickup_lat,
            'pickup_lon': ride.pickup_lon,
                    'dest_address': ride.dest_address,
            'dest_lat': ride.dest_lat,
            'dest_lon': ride.dest_lon,
            'distance_km': ride.distance_km,
            'fare': ride.fare,
                    'vehicle_type': ride.vehicle_type,
            'payment_method': ride.payment_method,
            'note': ride.note,
                    'status': ride.status,
                    'request_time': ride.request_time.isoformat(),
                    'assigned_time': ride.assigned_time.isoformat() if ride.assigned_time else None,
            'start_time': ride.start_time.isoformat() if ride.start_time else None,
            'end_time': ride.end_time.isoformat() if ride.end_time else None,
            'rating': ride.rating,
            'feedback': ride.feedback
        }
        
        # Include driver info if available
        if ride.driver_id:
            driver = Driver.query.get(ride.driver_id)
            if driver:
                details['driver'] = {
                    'name': driver.name,
                    'phone_number': driver.phone_number,
                    'vehicle_type': driver.vehicle_type,
                    'vehicle_plate_number': driver.vehicle_plate_number
                }
        
        return jsonify(details), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 400


@passenger_api.route('/ride/<int:ride_id>/chat', methods=['GET'])
def get_ride_chat(ride_id: int):
    """Get chat messages for a ride (passenger side)"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        ride = Ride.query.filter_by(id=ride_id, passenger_id=user.id).first()
        if not ride:
            return jsonify({'error': 'Ride not found'}), 404
        msgs = ChatMessage.query.filter_by(ride_id=ride.id).order_by(ChatMessage.created_at.asc()).all()
        return jsonify([
            {
                'id': m.id,
                'sender_role': m.sender_role,
                'sender_id': m.sender_id,
                'message': m.message,
                'created_at': m.created_at.isoformat() if m.created_at else None,
            } for m in msgs
        ]), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/profile-picture', methods=['POST'])
def upload_profile_picture():
    """Upload or replace passenger profile picture"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        if 'profile_picture' not in request.files:
            return jsonify({'error': 'No file provided'}), 400

        file = request.files['profile_picture']
        if not file or not file.filename:
            return jsonify({'error': 'Invalid file'}), 400

        # Save file and update user
        new_path = handle_file_upload(file, user.profile_picture)
        user.profile_picture = new_path
        db.session.commit()

        return jsonify({
            'profile_picture': new_path,
            'message': 'Profile picture updated'
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/profile', methods=['PUT'])
def update_profile():
    """Update passenger profile fields"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json() or {}
        username = data.get('username')
        email = data.get('email')
        phone_number = data.get('phone_number')
        profile_picture = data.get('profile_picture')

        if username:
            user.username = username
        if email:
            user.email = email
        if phone_number:
            user.phone_number = phone_number
        if profile_picture:
            user.profile_picture = profile_picture

        db.session.commit()

        return jsonify({
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'phone_number': user.phone_number,
                'passenger_uid': getattr(user, 'passenger_uid', None),
                'profile_picture': user.profile_picture,
            }
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@passenger_api.route('/change-password', methods=['POST'])
def change_password():
    """Change passenger password with current password verification"""
    try:
        user = resolve_current_passenger()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        data = request.get_json() or {}
        current_password = (data.get('current_password') or '').strip()
        new_password = (data.get('new_password') or '').strip()

        if not current_password or not new_password:
            return jsonify({'error': 'Current and new password are required'}), 400

        if not user.check_password(current_password):
            return jsonify({'error': 'Current password is incorrect'}), 400

        user.set_password(new_password)
        db.session.commit()
        return jsonify({'message': 'Password changed successfully'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400
