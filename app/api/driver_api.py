"""
Driver API Routes
Handles driver profile, availability, location updates, and earnings
"""

from flask import Blueprint, request, jsonify
from datetime import datetime, timezone
from werkzeug.security import generate_password_hash
from app.models import db, Driver, DriverLocation, DriverEarnings
from app.services.push import register_device_token
from app.models import Ride, ChatMessage
from app.utils import handle_file_upload

driver_api = Blueprint('driver_api', __name__)

def resolve_current_driver():
    """Resolve driver via X-User-Id header (mobile)"""
    try:
        user_id = request.headers.get('X-User-Id')
        if user_id:
            return Driver.query.get(int(user_id))
    except Exception:
        pass
    return None

@driver_api.route('/test', methods=['GET'])
def test_route():
    return jsonify({'message': 'Driver API is working!', 'status': 'success'})


@driver_api.route('/login', methods=['POST'])
def driver_login():
    """Driver login with phone/driver_id + password"""
    data = request.get_json() or {}
    identifier = (data.get('identifier') or '').strip()  # phone or driver_id
    password = (data.get('password') or '').strip()
    
    if not identifier or not password:
        return jsonify({'error': 'Phone/Driver ID and password are required'}), 400
    
    # Find driver by phone or driver_uid
    driver = Driver.query.filter(
        (Driver.phone_number == identifier) | (Driver.driver_uid == identifier)
    ).first()
    
    if not driver:
        return jsonify({'error': 'Invalid credentials'}), 401
    
    if not driver.password_hash:
        return jsonify({'error': 'Account not set up. Please contact admin.'}), 401
    
    if not driver.check_password(password):
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Check if driver is pending approval
    if driver.status == 'Pending':
        return jsonify({
            'error': 'Your registration is pending admin approval. Please wait for approval before logging in.',
            'status': 'Pending'
        }), 403
    
    if driver.is_blocked:
        return jsonify({'error': f'Account blocked: {driver.blocked_reason or "No reason provided"}'}), 403
    
    return jsonify({
        'driver_id': driver.id,
        'driver_uid': driver.driver_uid,
        'name': driver.name,
        'phone_number': driver.phone_number,
        'status': driver.status,
    }), 200


@driver_api.route('/signup', methods=['POST'])
def driver_signup():
    """Self-register a driver with password and file uploads; admin approval required"""
    # Check if JSON or form data
    is_json = request.is_json
    
    if is_json:
        # For JSON requests (minimal fields only)
        data = request.get_json() or {}
        password = (data.get('password') or '').strip()
        name = (data.get('name') or '').strip()
        phone_number = (data.get('phone_number') or '').strip()
        vehicle_type = (data.get('vehicle_type') or '').strip()
        vehicle_details = (data.get('vehicle_details') or '').strip()
        
        required = ['name', 'phone_number', 'password', 'vehicle_type', 'vehicle_details']
        for f in required:
            if not locals().get(f, '').strip():
                return jsonify({'error': f'{f} is required'}), 400
        
        # Check for existing driver - allow re-registration if rejected
        existing_driver = Driver.query.filter_by(phone_number=phone_number).first()
        if existing_driver:
            # If driver exists and is not rejected, block re-registration
            if existing_driver.status != 'Pending' and not existing_driver.is_blocked:
                return jsonify({'error': 'Phone number already registered'}), 409
            
            # If rejected/blocked, update the existing record instead of creating new one
            if existing_driver.is_blocked or (existing_driver.status == 'Pending' and existing_driver.is_blocked):
                existing_driver.name = name
                existing_driver.password_hash = generate_password_hash(password)
                existing_driver.vehicle_type = vehicle_type
                existing_driver.vehicle_details = vehicle_details
                existing_driver.vehicle_plate_number = (data.get('vehicle_plate_number') or '').strip() or None
                existing_driver.license_info = (data.get('license_info') or '').strip() or None
                existing_driver.email = (data.get('email') or '').strip() or None
                existing_driver.status = 'Pending'
                existing_driver.is_blocked = False
                existing_driver.blocked_reason = None
                existing_driver.blocked_at = None
                db.session.commit()
                # Emit notification
                try:
                    from app.utils.socket_utils import emit_driver_registration_notification
                    emit_driver_registration_notification({
                        'driver_id': existing_driver.id,
                        'driver_uid': existing_driver.driver_uid,
                        'name': existing_driver.name,
                        'phone_number': existing_driver.phone_number,
                        'vehicle_type': existing_driver.vehicle_type,
                        'join_date': existing_driver.join_date.isoformat() if existing_driver.join_date else None
                    })
                except Exception as e:
                    from flask import current_app
                    current_app.logger.error(f"Failed to emit driver registration notification: {e}")
                return jsonify({'driver_id': existing_driver.id, 'driver_uid': existing_driver.driver_uid, 'status': existing_driver.status, 'message': 'Registration updated. Awaiting admin approval.'}), 200
        
        # Create new driver
        try:
            d = Driver(
                name=name,
                phone_number=phone_number,
                password_hash=generate_password_hash(password),
                vehicle_type=vehicle_type,
                vehicle_details=vehicle_details,
                vehicle_plate_number=(data.get('vehicle_plate_number') or '').strip() or None,
                license_info=(data.get('license_info') or '').strip() or None,
                email=(data.get('email') or '').strip() or None,
                status='Pending',
            )
            db.session.add(d)
            db.session.flush()
            if not d.driver_uid:
                d.driver_uid = f"DRV-{d.id:04d}"
            db.session.commit()
            # Emit notification
            try:
                from app.utils.socket_utils import emit_driver_registration_notification
                emit_driver_registration_notification({
                    'driver_id': d.id,
                    'driver_uid': d.driver_uid,
                    'name': d.name,
                    'phone_number': d.phone_number,
                    'vehicle_type': d.vehicle_type,
                    'join_date': d.join_date.isoformat() if d.join_date else None
                })
            except Exception as e:
                from flask import current_app
                current_app.logger.error(f"Failed to emit driver registration notification: {e}")
            return jsonify({'driver_id': d.id, 'driver_uid': d.driver_uid, 'status': d.status}), 201
        except Exception as e:
            db.session.rollback()
            return jsonify({'error': str(e)}), 400
    else:
        # For multipart/form-data (with file uploads)
        try:
            password = (request.form.get('password') or '').strip()
            name = (request.form.get('name') or '').strip()
            phone_number = (request.form.get('phone_number') or '').strip()
            vehicle_type = (request.form.get('vehicle_type') or '').strip()
            vehicle_details = (request.form.get('vehicle_details') or '').strip()
            
            required = ['name', 'phone_number', 'password', 'vehicle_type', 'vehicle_details']
            for f in required:
                if not locals().get(f, '').strip():
                    return jsonify({'error': f'{f} is required'}), 400
            
            # Check for existing driver - allow re-registration if rejected
            existing_driver = Driver.query.filter_by(phone_number=phone_number).first()
            if existing_driver:
                # If driver exists and is not rejected, block re-registration
                if existing_driver.status != 'Pending' and not existing_driver.is_blocked:
                    return jsonify({'error': 'Phone number already registered'}), 409
            
            # Handle file uploads
            profile_picture = handle_file_upload(
                request.files.get('profile_picture'), 
                'static/img/default_user.svg'
            )
            license_document = handle_file_upload(request.files.get('license_document'))
            vehicle_document = handle_file_upload(request.files.get('vehicle_document'))
            plate_photo = handle_file_upload(request.files.get('plate_photo'))
            id_document = handle_file_upload(request.files.get('id_document'))
            
            # Check if existing driver should be updated (rejected case)
            if existing_driver and (existing_driver.is_blocked or (existing_driver.status == 'Pending' and existing_driver.is_blocked)):
                # Update existing rejected driver
                existing_driver.name = name
                existing_driver.password_hash = generate_password_hash(password)
                existing_driver.vehicle_type = vehicle_type
                existing_driver.vehicle_details = vehicle_details
                existing_driver.vehicle_plate_number = (request.form.get('vehicle_plate_number') or '').strip() or None
                existing_driver.license_info = (request.form.get('license_info') or '').strip() or None
                existing_driver.email = (request.form.get('email') or '').strip() or None
                existing_driver.status = 'Pending'
                existing_driver.is_blocked = False
                existing_driver.blocked_reason = None
                existing_driver.blocked_at = None
                # Update documents if new ones provided
                if profile_picture and profile_picture != 'static/img/default_user.svg':
                    existing_driver.profile_picture = profile_picture
                if license_document:
                    existing_driver.license_document = license_document
                if vehicle_document:
                    existing_driver.vehicle_document = vehicle_document
                if plate_photo:
                    existing_driver.plate_photo = plate_photo
                if id_document:
                    existing_driver.id_document = id_document
                db.session.commit()
                # Emit notification
                try:
                    from app.utils.socket_utils import emit_driver_registration_notification
                    emit_driver_registration_notification({
                        'driver_id': existing_driver.id,
                        'driver_uid': existing_driver.driver_uid,
                        'name': existing_driver.name,
                        'phone_number': existing_driver.phone_number,
                        'vehicle_type': existing_driver.vehicle_type,
                        'join_date': existing_driver.join_date.isoformat() if existing_driver.join_date else None
                    })
                except Exception as e:
                    from flask import current_app
                    current_app.logger.error(f"Failed to emit driver registration notification: {e}")
                return jsonify({
                    'driver_id': existing_driver.id, 
                    'driver_uid': existing_driver.driver_uid, 
                    'status': existing_driver.status,
                    'message': 'Registration updated. Awaiting admin approval.'
                }), 200
            
            # Create new driver
            d = Driver(
                name=name,
                phone_number=phone_number,
                password_hash=generate_password_hash(password),
                vehicle_type=vehicle_type,
                vehicle_details=vehicle_details,
                vehicle_plate_number=(request.form.get('vehicle_plate_number') or '').strip() or None,
                license_info=(request.form.get('license_info') or '').strip() or None,
                email=(request.form.get('email') or '').strip() or None,
                status='Pending',
                profile_picture=profile_picture,
                license_document=license_document,
                vehicle_document=vehicle_document,
                plate_photo=plate_photo,
                id_document=id_document,
            )
            db.session.add(d)
            db.session.flush()
            if not d.driver_uid:
                d.driver_uid = f"DRV-{d.id:04d}"
            db.session.commit()
            
            # Emit real-time notification to dispatchers
            try:
                from app.utils.socket_utils import emit_driver_registration_notification
                emit_driver_registration_notification({
                    'driver_id': d.id,
                    'driver_uid': d.driver_uid,
                    'name': d.name,
                    'phone_number': d.phone_number,
                    'vehicle_type': d.vehicle_type,
                    'join_date': d.join_date.isoformat() if d.join_date else None
                })
            except Exception as e:
                from flask import current_app
                current_app.logger.error(f"Failed to emit driver registration notification: {e}")
            
            return jsonify({
                'driver_id': d.id, 
                'driver_uid': d.driver_uid, 
                'status': d.status,
                'message': 'Registration submitted. Awaiting admin approval.'
            }), 201
        except ValueError as e:
            db.session.rollback()
            return jsonify({'error': str(e)}), 400
        except Exception as e:
            db.session.rollback()
            return jsonify({'error': str(e)}), 400

@driver_api.route('/profile', methods=['GET'])
def get_profile():
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    return jsonify({
        'id': driver.id,
        'name': driver.name,
        'phone_number': driver.phone_number,
        'vehicle_type': driver.vehicle_type,
        'vehicle_details': driver.vehicle_details,
        'vehicle_plate_number': driver.vehicle_plate_number,
        'status': driver.status,
        'profile_picture': driver.profile_picture,
    }), 200

@driver_api.route('/profile', methods=['PUT'])
def update_profile():
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json() or {}
    driver.name = data.get('name', driver.name)
    driver.phone_number = data.get('phone_number', driver.phone_number)
    driver.vehicle_type = data.get('vehicle_type', driver.vehicle_type)
    driver.vehicle_details = data.get('vehicle_details', driver.vehicle_details)
    driver.vehicle_plate_number = data.get('vehicle_plate_number', driver.vehicle_plate_number)
    db.session.commit()
    return jsonify({'message': 'Profile updated'}), 200

@driver_api.route('/availability', methods=['POST'])
def set_availability():
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json() or {}
    status = (data.get('status') or '').strip().capitalize()
    if status not in ['Online', 'Offline']:
        return jsonify({'error': 'Invalid status'}), 400
    driver.status = status
    db.session.commit()
    return jsonify({'message': 'Availability updated', 'status': status}), 200

@driver_api.route('/location', methods=['POST'])
def update_location():
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json() or {}
    try:
        lat = float(data.get('lat'))
        lon = float(data.get('lon'))
    except Exception:
        return jsonify({'error': 'lat and lon are required'}), 400
    heading = data.get('heading')
    try:
        record = DriverLocation.query.filter_by(driver_id=driver.id).first()
        if not record:
            record = DriverLocation(driver_id=driver.id, lat=lat, lon=lon, heading=heading)
            db.session.add(record)
        else:
            record.lat = lat
            record.lon = lon
            record.heading = heading
            record.updated_at = datetime.utcnow()
        db.session.commit()
        return jsonify({'message': 'Location updated'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400

@driver_api.route('/earnings', methods=['GET'])
def get_earnings():
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    # Optional date filters
    from_date = request.args.get('from')
    to_date = request.args.get('to')
    q = DriverEarnings.query.filter_by(driver_id=driver.id)
    if from_date:
        try:
            from_dt = datetime.fromisoformat(from_date)
            q = q.filter(DriverEarnings.created_at >= from_dt)
        except Exception:
            pass
    if to_date:
        try:
            to_dt = datetime.fromisoformat(to_date)
            q = q.filter(DriverEarnings.created_at <= to_dt)
        except Exception:
            pass
    rows = q.all()
    total = sum([float(e.driver_earnings or 0) for e in rows])
    return jsonify({
        'total_earnings': round(total, 2),
        'count': len(rows),
        'items': [
            {
                'ride_id': e.ride_id,
                'gross_fare': float(e.gross_fare or 0),
                'commission_amount': float(e.commission_amount or 0),
                'driver_earnings': float(e.driver_earnings or 0),
                'payment_status': e.payment_status,
                'created_at': e.created_at.isoformat() if e.created_at else None,
            } for e in rows
        ]
    }), 200


@driver_api.route('/register-token', methods=['POST'])
def register_token():
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json() or {}
    token = (data.get('token') or '').strip()
    platform = (data.get('platform') or '').strip() or None
    if not token:
        return jsonify({'error': 'token is required'}), 400
    try:
        register_device_token('driver', driver.id, token, platform)
        return jsonify({'message': 'Token registered'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 400


def _resolve_driver_and_ride(data):
    driver = resolve_current_driver()
    if not driver:
        return None, None, (jsonify({'error': 'Unauthorized'}), 401)
    ride_id = data.get('ride_id')
    if not ride_id:
        return None, None, (jsonify({'error': 'ride_id is required'}), 400)
    ride = Ride.query.filter_by(id=ride_id, driver_id=driver.id).first()
    if not ride:
        return None, None, (jsonify({'error': 'Ride not found'}), 404)
    return driver, ride, None


@driver_api.route('/ride/arrived', methods=['POST'])
def ride_arrived():
    data = request.get_json() or {}
    driver, ride, err = _resolve_driver_and_ride(data)
    if err:
        return err
    ride.status = 'Driver Arriving'
    db.session.commit()
    return jsonify({'message': 'Marked as arrived'}), 200


@driver_api.route('/ride/start', methods=['POST'])
def ride_start():
    data = request.get_json() or {}
    driver, ride, err = _resolve_driver_and_ride(data)
    if err:
        return err
    ride.status = 'On Trip'
    ride.start_time = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify({'message': 'Trip started'}), 200


@driver_api.route('/ride/end', methods=['POST'])
def ride_end():
    data = request.get_json() or {}
    driver, ride, err = _resolve_driver_and_ride(data)
    if err:
        return err
    ride.status = 'Completed'
    ride.end_time = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify({'message': 'Trip completed'}), 200


@driver_api.route('/available-rides', methods=['GET'])
def get_available_rides():
    """Get available rides for the current driver (rides with status 'Requested')"""
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    
    # Only show available rides if driver is online
    if driver.status not in ['Available', 'Offline']:
        return jsonify([]), 200
    
    # Get rides with status 'Requested' that match driver's vehicle type
    rides = Ride.query.filter_by(status='Requested').all()
    
    # Filter by vehicle type if driver has a specific vehicle type
    if driver.vehicle_type:
        rides = [r for r in rides if r.vehicle_type == driver.vehicle_type or r.vehicle_type == 'Any']
    
    rides_data = []
    for ride in rides:
        try:
            passenger = ride.passenger
            rides_data.append({
                'id': ride.id,
                'user_name': passenger.username if passenger else 'Unknown',
                'user_phone': passenger.phone_number if passenger else 'N/A',
                'pickup_address': ride.pickup_address,
                'pickup_lat': float(ride.pickup_lat),
                'pickup_lon': float(ride.pickup_lon),
                'dest_address': ride.dest_address,
                'dest_lat': float(ride.dest_lat) if ride.dest_lat else None,
                'dest_lon': float(ride.dest_lon) if ride.dest_lon else None,
                'fare': float(ride.fare),
                'distance_km': float(ride.distance_km) if ride.distance_km else None,
                'vehicle_type': ride.vehicle_type,
                'note': ride.note,
                'request_time': ride.request_time.strftime('%Y-%m-%d %H:%M:%S') if ride.request_time else None,
            })
        except Exception as e:
            # Skip rides with errors
            continue
    
    return jsonify(rides_data), 200


@driver_api.route('/accept-ride', methods=['POST'])
def accept_ride():
    """Driver accepts a ride offer"""
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json() or {}
    ride_id = data.get('ride_id')
    
    if not ride_id:
        return jsonify({'error': 'ride_id is required'}), 400
    
    ride = Ride.query.get(ride_id)
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    
    # Check if ride is still available
    if ride.status != 'Requested':
        return jsonify({'error': 'Ride is no longer available'}), 400
    
    # Check if driver is available
    if driver.status != 'Available':
        return jsonify({'error': 'Driver is not available'}), 400
    
    try:
        # Assign driver to ride
        ride.driver_id = driver.id
        ride.status = 'Assigned'
        ride.assigned_time = datetime.now(timezone.utc)
        
        # Update driver status
        driver.status = 'On Trip'
        driver.current_lat = ride.pickup_lat
        driver.current_lon = ride.pickup_lon
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Ride accepted successfully',
            'ride_id': ride.id
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@driver_api.route('/decline-offer', methods=['POST'])
def decline_offer():
    """Driver declines a ride offer (optional - for tracking purposes)"""
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.get_json() or {}
    ride_id = data.get('ride_id')
    
    if ride_id:
        # Optionally track declined offers here
        # For now, just return success
        pass
    
    return jsonify({'success': True, 'message': 'Offer declined'}), 200


@driver_api.route('/active-ride', methods=['GET'])
def get_active_ride():
    """Get active ride for the current driver"""
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    
    # Get active ride (status: Assigned, Driver Arriving, or On Trip)
    ride = Ride.query.filter_by(driver_id=driver.id).filter(
        Ride.status.in_(['Assigned', 'Driver Arriving', 'On Trip'])
    ).first()
    
    if not ride:
        return jsonify({'ride': None}), 200
    
    try:
        passenger = ride.passenger
        ride_data = {
            'id': ride.id,
            'status': ride.status,
            'passenger': {
                'id': passenger.id if passenger else None,
                'name': passenger.username if passenger else 'Unknown',
                'phone': passenger.phone_number if passenger else 'N/A',
            },
            'pickup_address': ride.pickup_address,
            'pickup_lat': float(ride.pickup_lat),
            'pickup_lon': float(ride.pickup_lon),
            'dest_address': ride.dest_address,
            'dest_lat': float(ride.dest_lat) if ride.dest_lat else None,
            'dest_lon': float(ride.dest_lon) if ride.dest_lon else None,
            'fare': float(ride.fare),
            'distance_km': float(ride.distance_km) if ride.distance_km else None,
            'vehicle_type': ride.vehicle_type,
            'note': ride.note,
            'request_time': ride.request_time.isoformat() if ride.request_time else None,
        }
        return jsonify({'ride': ride_data}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@driver_api.route('/ride/<int:ride_id>/chat', methods=['GET'])
def get_ride_chat(ride_id: int):
    driver = resolve_current_driver()
    if not driver:
        return jsonify({'error': 'Unauthorized'}), 401
    ride = Ride.query.filter_by(id=ride_id, driver_id=driver.id).first()
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


