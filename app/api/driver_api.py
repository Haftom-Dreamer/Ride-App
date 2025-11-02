"""
Driver API Routes
Handles driver profile, availability, location updates, and earnings
"""

from flask import Blueprint, request, jsonify
from datetime import datetime
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
        
        # Check for duplicate phone
        if Driver.query.filter_by(phone_number=phone_number).first():
            return jsonify({'error': 'Phone number already registered'}), 409
        
        # Create driver
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
            
            # Check for duplicate phone
            if Driver.query.filter_by(phone_number=phone_number).first():
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
            
            # Create driver
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
    ride.start_time = datetime.utcnow()
    db.session.commit()
    return jsonify({'message': 'Trip started'}), 200


@driver_api.route('/ride/end', methods=['POST'])
def ride_end():
    data = request.get_json() or {}
    driver, ride, err = _resolve_driver_and_ride(data)
    if err:
        return err
    ride.status = 'Completed'
    ride.end_time = datetime.utcnow()
    db.session.commit()
    return jsonify({'message': 'Trip completed'}), 200


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


