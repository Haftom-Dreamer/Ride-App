"""
Driver-related API endpoints
"""

from flask import request, jsonify, current_app
from sqlalchemy import func
from app.models import db, Driver, Ride, Feedback
from app.api import api, admin_required
from app.utils import handle_file_upload

@api.route('/add-driver', methods=['POST'])
@admin_required
def add_driver():
    """Add a new driver"""
    try:
        # Validate required fields (matching HTML form requirements)
        required_fields = ['name', 'phone_number', 'vehicle_type', 'vehicle_details', 'vehicle_plate_number', 'license_info']
        for field in required_fields:
            if not request.form.get(field, '').strip():
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Validate phone number format
        phone = request.form.get('phone_number', '').strip()
        if not phone or len(phone) < 10:
            return jsonify({'error': 'Invalid phone number format'}), 400
        
        # Check for duplicate phone number
        existing_driver = Driver.query.filter_by(phone_number=phone).first()
        if existing_driver:
            return jsonify({'error': 'Phone number already registered to another driver'}), 409
        
        # Handle file uploads with error checking
        try:
            profile_picture = handle_file_upload(request.files.get('profile_picture'), 'static/img/default_user.svg')
            license_document = handle_file_upload(request.files.get('license_document'))
            vehicle_document = handle_file_upload(request.files.get('vehicle_document'))
        except ValueError as e:
            return jsonify({'error': str(e)}), 400
        
        new_driver = Driver(
            name=request.form.get('name').strip(),
            phone_number=phone,
            vehicle_type=request.form.get('vehicle_type'),
            vehicle_details=request.form.get('vehicle_details').strip(),
            vehicle_plate_number=request.form.get('vehicle_plate_number').strip(),
            license_info=request.form.get('license_info').strip(),
            status='Offline',
            profile_picture=profile_picture,
            license_document=license_document,
            vehicle_document=vehicle_document
        )
        
        db.session.add(new_driver)
        db.session.flush()
        new_driver.driver_uid = f"DRV-{new_driver.id:04d}"
        db.session.commit()
        return jsonify({'message': 'Driver added successfully', 'driver_id': new_driver.id}), 201
        
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Error adding driver: {str(e)}")
        return jsonify({'error': 'Failed to add driver. Please check your input and try again.'}), 500

@api.route('/update-driver/<int:driver_id>', methods=['POST'])
@admin_required
def update_driver(driver_id):
    """Update driver information"""
    driver = Driver.query.get_or_404(driver_id)
    
    try:
        driver.name = request.form.get('name', driver.name)
        driver.phone_number = request.form.get('phone_number', driver.phone_number)
        driver.vehicle_type = request.form.get('vehicle_type', driver.vehicle_type)
        driver.vehicle_details = request.form.get('vehicle_details', driver.vehicle_details)
        driver.vehicle_plate_number = request.form.get('vehicle_plate_number', driver.vehicle_plate_number)
        driver.license_info = request.form.get('license_info', driver.license_info)
        
        # Handle file uploads
        if request.files.get('profile_picture'):
            driver.profile_picture = handle_file_upload(request.files.get('profile_picture'), driver.profile_picture)
        if request.files.get('license_document'):
            driver.license_document = handle_file_upload(request.files.get('license_document'), driver.license_document)
        if request.files.get('vehicle_document'):
            driver.vehicle_document = handle_file_upload(request.files.get('vehicle_document'), driver.vehicle_document)

        db.session.commit()
        return jsonify({'message': 'Driver updated successfully'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api.route('/delete-driver', methods=['POST'])
@admin_required
def delete_driver():
    """Delete a driver"""
    data = request.json
    driver = Driver.query.get(data.get('driver_id'))
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    
    try:
        db.session.delete(driver)
        db.session.commit()
        return jsonify({'message': 'Driver deleted successfully'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api.route('/update-driver-status', methods=['POST'])
@admin_required
def update_driver_status():
    """Update driver status"""
    data = request.json
    driver = Driver.query.get(data.get('driver_id'))
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    
    driver.status = data.get('status')
    db.session.commit()
    return jsonify({'message': f'Driver status updated to {driver.status}'})

@api.route('/drivers')
@admin_required
def get_all_drivers():
    """Get all drivers with their average ratings"""
    try:
        drivers = Driver.query.all()
        drivers_data = []
        
        for driver in drivers:
            # Calculate average rating
            avg_rating = db.session.query(func.avg(Feedback.rating)).join(Ride).filter(
                Ride.driver_id == driver.id, 
                Feedback.rating.isnot(None)
            ).scalar() or 0
            
            driver_info = {
                'id': driver.id,
                'driver_uid': driver.driver_uid,
                'name': driver.name,
                'phone_number': driver.phone_number,
                'vehicle_type': driver.vehicle_type,
                'vehicle_details': driver.vehicle_details,
                'vehicle_plate_number': driver.vehicle_plate_number,
                'license_info': driver.license_info,
                'status': driver.status,
                'profile_picture': driver.profile_picture,
                'license_document': driver.license_document,
                'vehicle_document': driver.vehicle_document,
                'join_date': driver.join_date.strftime('%Y-%m-%d') if driver.join_date else None,
                'avg_rating': round(avg_rating, 2) if avg_rating else 0
            }
            drivers_data.append(driver_info)
        
        return jsonify(drivers_data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@api.route('/driver/<int:driver_id>')
@admin_required
def get_driver(driver_id):
    """Get specific driver details"""
    driver = Driver.query.get_or_404(driver_id)
    return jsonify({
        "id": driver.id,
        "name": driver.name,
        "phone_number": driver.phone_number,
        "vehicle_type": driver.vehicle_type,
        "vehicle_details": driver.vehicle_details,
        "vehicle_plate_number": driver.vehicle_plate_number,
        "license_info": driver.license_info,
        "profile_picture": driver.profile_picture,
        "license_document": driver.license_document,
        "vehicle_document": driver.vehicle_document,
    })

@api.route('/available-drivers')
@admin_required
def get_available_drivers():
    """Get available drivers for assignment"""
    vehicle_type = request.args.get('vehicle_type')
    
    query = Driver.query.filter_by(status='Available')
    if vehicle_type:
        query = query.filter_by(vehicle_type=vehicle_type)
    
    drivers = query.all()
    
    drivers_data = [
        {
            'id': driver.id,
            'name': driver.name,
            'vehicle_type': driver.vehicle_type,
            'status': driver.status
        }
        for driver in drivers
    ]

    return jsonify(drivers_data)

@api.route('/driver-details/<int:driver_id>')
@admin_required
def get_driver_details(driver_id):
    """Get detailed driver information including statistics"""
    from datetime import datetime, timezone, timedelta
    from app.utils import to_eat
    
    driver = Driver.query.get_or_404(driver_id)
    
    now = datetime.now(timezone.utc)
    week_start = now - timedelta(days=now.weekday())

    # Calculate statistics
    total_earnings_all_time = db.session.query(func.sum(Ride.fare)).filter(
        Ride.driver_id == driver_id, 
        Ride.status == 'Completed'
    ).scalar() or 0
    
    weekly_earnings = db.session.query(func.sum(Ride.fare)).filter(
        Ride.driver_id == driver_id,
        Ride.status == 'Completed',
        Ride.request_time >= week_start
    ).scalar() or 0
    
    avg_rating = db.session.query(func.avg(Feedback.rating)).join(Ride).filter(
        Ride.driver_id == driver.id,
        Feedback.rating.isnot(None)
    ).scalar() or 0
    
    completed_rides = Ride.query.filter_by(driver_id=driver_id, status='Completed').count()
    
    stats = {
        'completed_rides': completed_rides,
        'total_earnings_all_time': float(total_earnings_all_time),
        'total_earnings_weekly': float(weekly_earnings),
        'avg_rating': round(float(avg_rating), 2) if avg_rating else 0
    }
    
    # Get recent ride history
    history = Ride.query.filter_by(driver_id=driver_id).order_by(Ride.request_time.desc()).limit(10).all()
    
    return jsonify({
        'profile': {
            'name': driver.name,
            'driver_uid': driver.driver_uid,
            'status': driver.status,
            'avatar': driver.profile_picture,
            'phone_number': driver.phone_number,
            'vehicle_type': driver.vehicle_type,
            'vehicle_details': driver.vehicle_details,
            'plate_number': driver.vehicle_plate_number,
            'license': driver.license_info,
            'license_document': driver.license_document,
            'vehicle_document': driver.vehicle_document
        },
        'stats': stats,
        'history': [{
            'id': ride.id,
            'status': ride.status,
            'fare': float(ride.fare),
            'date': to_eat(ride.request_time).strftime('%Y-%m-%d')
        } for ride in history]
    })
