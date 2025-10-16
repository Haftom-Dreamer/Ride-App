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
        # Validate required fields with user-friendly names
        required_fields = {
            'name': 'Driver Name',
            'phone_number': 'Phone Number',
            'vehicle_type': 'Vehicle Type',
            'vehicle_details': 'Vehicle Details',
            'vehicle_plate_number': 'Plate Number',
            'license_info': 'License Number'
        }
        
        for field, label in required_fields.items():
            if not request.form.get(field, '').strip():
                return jsonify({'error': f'{label} is required'}), 400
        
        # Validate phone number format
        phone = request.form.get('phone_number', '').strip()
        
        # Check if phone starts with + or country code
        if phone.startswith('+'):
            # International format: +251912345678 (minimum 12 chars)
            if len(phone) < 12 or not phone[1:].isdigit():
                return jsonify({'error': 'Phone number must be in format: +251912345678'}), 400
        elif phone.startswith('251'):
            # Country code without +: 251912345678
            if len(phone) < 12 or not phone.isdigit():
                return jsonify({'error': 'Phone number must be in format: 251912345678 or +251912345678'}), 400
        elif phone.startswith('0'):
            # Local format: 0912345678 (10 digits)
            if len(phone) != 10 or not phone.isdigit():
                return jsonify({'error': 'Phone number must be 10 digits starting with 0 (e.g., 0912345678)'}), 400
            # Convert to international format
            phone = '+251' + phone[1:]
        elif phone.startswith('9'):
            # Without leading 0: 912345678 (9 digits)
            if len(phone) != 9 or not phone.isdigit():
                return jsonify({'error': 'Phone number must be 9 digits (e.g., 912345678) or 10 digits with 0'}), 400
            # Convert to international format
            phone = '+251' + phone
        else:
            return jsonify({'error': 'Invalid phone format. Use: +251912345678, 0912345678, or 912345678'}), 400
        
        # Check for duplicate phone number
        existing_driver = Driver.query.filter_by(phone_number=phone).first()
        if existing_driver:
            return jsonify({'error': f'Phone number already registered to driver: {existing_driver.name}'}), 409
        
        # Validate plate number format (basic validation)
        plate = request.form.get('vehicle_plate_number', '').strip()
        if len(plate) < 3:
            return jsonify({'error': 'Plate number is too short (minimum 3 characters)'}), 400
        
        # Check for duplicate plate number
        existing_plate = Driver.query.filter_by(vehicle_plate_number=plate).first()
        if existing_plate:
            return jsonify({'error': f'Plate number already registered to driver: {existing_plate.name}'}), 409
        
        # Validate license number
        license_num = request.form.get('license_info', '').strip()
        if len(license_num) < 5:
            return jsonify({'error': 'License number is too short (minimum 5 characters)'}), 400
        
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
                'avg_rating': round(avg_rating, 2) if avg_rating else 0,
                'is_blocked': driver.is_blocked,
                'blocked_reason': driver.blocked_reason if driver.is_blocked else None
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

@api.route('/drivers/export')
@admin_required
def export_drivers():
    """Export drivers data to CSV"""
    try:
        import csv
        import io
        from flask import make_response
        
        drivers = Driver.query.all()
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Write header
        writer.writerow([
            'ID', 'Name', 'Phone', 'Email', 'Vehicle Type', 'Vehicle Details', 
            'License Info', 'Status', 'Rating', 'Total Rides', 'Total Earnings', 'Registration Date'
        ])
        
        # Write data
        for driver in drivers:
            total_rides = Ride.query.filter_by(driver_id=driver.id, status='Completed').count()
            total_earnings = db.session.query(func.sum(Ride.fare)).filter(
                Ride.driver_id == driver.id, 
                Ride.status == 'Completed'
            ).scalar() or 0
            
            writer.writerow([
                driver.id,
                driver.name,
                driver.phone_number,
                driver.email or '',
                driver.vehicle_type,
                driver.vehicle_details,
                driver.license_info,
                driver.status,
                driver.rating or 0,
                total_rides,
                float(total_earnings),
                driver.created_at.strftime('%Y-%m-%d %H:%M:%S') if driver.created_at else ''
            ])
        
        output.seek(0)
        
        response = make_response(output.getvalue())
        response.headers['Content-Type'] = 'text/csv'
        response.headers['Content-Disposition'] = f'attachment; filename=drivers_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
        
        return response
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

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
            'id': driver.id,
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
            'vehicle_document': driver.vehicle_document,
            'is_blocked': driver.is_blocked,
            'blocked_reason': driver.blocked_reason if driver.is_blocked else None,
            'blocked_at': to_eat(driver.blocked_at).strftime('%b %d, %Y') if driver.blocked_at else None
        },
        'stats': stats,
        'history': [{
            'id': ride.id,
            'status': ride.status,
            'fare': float(ride.fare),
            'date': to_eat(ride.request_time).strftime('%Y-%m-%d')
        } for ride in history]
    })

@api.route('/suggest-drivers', methods=['POST'])
@admin_required
def suggest_drivers():
    """Suggest best drivers for a ride based on various criteria"""
    try:
        data = request.json
        ride_id = data.get('ride_id')
        pickup_lat = data.get('pickup_lat')
        pickup_lon = data.get('pickup_lon')
        vehicle_type = data.get('vehicle_type', 'Bajaj')
        
        if not ride_id or not pickup_lat or not pickup_lon:
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Get available drivers of the requested vehicle type
        available_drivers = Driver.query.filter(
            Driver.status == 'Available',
            Driver.vehicle_type == vehicle_type,
            Driver.is_blocked == False
        ).all()
        
        if not available_drivers:
            return jsonify({
                'success': True,
                'suggestions': [],
                'message': 'No available drivers found'
            })
        
        # Calculate driver scores and suggestions
        suggestions = []
        for driver in available_drivers:
            score = _calculate_driver_score(driver, pickup_lat, pickup_lon, vehicle_type)
            
            # Get driver's last ride for distance estimation
            last_ride = Ride.query.filter_by(driver_id=driver.id).order_by(Ride.request_time.desc()).first()
            
            # Estimate distance (simplified - in real app would use GPS)
            estimated_distance = "Unknown"
            if last_ride:
                # Simple distance estimation based on last known location
                estimated_distance = "~2.5 km"  # Placeholder
            
            # Get driver rating
            rating = _get_driver_rating(driver.id)
            
            suggestions.append({
                'driver_id': driver.id,
                'name': driver.name,
                'phone_number': driver.phone_number,
                'vehicle_type': driver.vehicle_type,
                'vehicle_details': driver.vehicle_details,
                'profile_picture': driver.profile_picture,
                'rating': rating,
                'estimated_distance': estimated_distance,
                'score': score,
                'last_ride_time': last_ride.request_time.isoformat() if last_ride else None,
                'total_rides': Ride.query.filter_by(driver_id=driver.id, status='Completed').count()
            })
        
        # Sort by score (highest first)
        suggestions.sort(key=lambda x: x['score'], reverse=True)
        
        # Limit to top 5 suggestions
        suggestions = suggestions[:5]
        
        return jsonify({
            'success': True,
            'suggestions': suggestions,
            'total_available': len(available_drivers)
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def _calculate_driver_score(driver, pickup_lat, pickup_lon, vehicle_type):
    """Calculate driver suitability score (0-100)"""
    score = 50  # Base score
    
    # Vehicle type match (already filtered, but good to have)
    if driver.vehicle_type == vehicle_type:
        score += 20
    
    # Driver rating bonus
    rating = _get_driver_rating(driver.id)
    if rating >= 4.5:
        score += 20
    elif rating >= 4.0:
        score += 15
    elif rating >= 3.5:
        score += 10
    elif rating >= 3.0:
        score += 5
    
    # Recent activity bonus (more recent = higher score)
    last_ride = Ride.query.filter_by(driver_id=driver.id).order_by(Ride.request_time.desc()).first()
    if last_ride:
        from datetime import datetime, timezone, timedelta
        time_diff = datetime.now(timezone.utc) - last_ride.request_time
        if time_diff < timedelta(hours=2):
            score += 10
        elif time_diff < timedelta(hours=6):
            score += 5
    
    # Total rides experience bonus
    total_rides = Ride.query.filter_by(driver_id=driver.id, status='Completed').count()
    if total_rides >= 100:
        score += 10
    elif total_rides >= 50:
        score += 5
    elif total_rides >= 20:
        score += 2
    
    return min(score, 100)  # Cap at 100

def _get_driver_rating(driver_id):
    """Get average rating for a driver"""
    rating_result = db.session.query(func.avg(Feedback.rating)).join(
        Ride, Feedback.ride_id == Ride.id
    ).filter(
        Ride.driver_id == driver_id,
        Feedback.rating.isnot(None)
    ).scalar()
    
    return round(float(rating_result or 0), 1)
