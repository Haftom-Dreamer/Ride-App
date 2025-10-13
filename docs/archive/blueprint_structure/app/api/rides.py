"""
Ride-related API endpoints
"""

from decimal import Decimal, ROUND_HALF_UP
from datetime import datetime, timezone
from flask import request, jsonify, current_app
from flask_login import current_user
from app.models import db, Driver, Ride, Passenger
from app.api import api, admin_required, passenger_required, limiter, get_setting
import requests

@api.route('/ride-request', methods=['POST'])
@passenger_required
def request_ride():
    """Create a new ride request"""
    if limiter:
        limiter.limit("10 per hour")(lambda: None)()
    
    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    # Validate required fields
    required_fields = ['pickup_lat', 'pickup_lon', 'dest_address', 'dest_lat', 'dest_lon', 'distance_km', 'fare']
    for field in required_fields:
        if field not in data or data[field] is None:
            return jsonify({'error': f'Missing required field: {field}'}), 400
    
    # Validate coordinates
    try:
        pickup_lat = float(data['pickup_lat'])
        pickup_lon = float(data['pickup_lon'])
        dest_lat = float(data['dest_lat'])
        dest_lon = float(data['dest_lon'])
        
        if not (-90 <= pickup_lat <= 90) or not (-180 <= pickup_lon <= 180):
            return jsonify({'error': 'Invalid pickup coordinates'}), 400
        if not (-90 <= dest_lat <= 90) or not (-180 <= dest_lon <= 180):
            return jsonify({'error': 'Invalid destination coordinates'}), 400
    except (ValueError, TypeError):
        return jsonify({'error': 'Invalid coordinate format'}), 400
    
    # Validate distance and fare
    try:
        distance_km = Decimal(str(data['distance_km']))
        fare = Decimal(str(data['fare']))
        
        if distance_km <= 0 or distance_km > 1000:
            return jsonify({'error': 'Invalid distance'}), 400
        if fare <= 0 or fare > 100000:
            return jsonify({'error': 'Invalid fare amount'}), 400
    except (ValueError, TypeError):
        return jsonify({'error': 'Invalid distance or fare format'}), 400
    
    # Validate vehicle type
    vehicle_type = data.get('vehicle_type', 'Bajaj')
    if vehicle_type not in ['Bajaj', 'Car']:
        vehicle_type = 'Bajaj'
    
    # Validate payment method
    payment_method = data.get('payment_method', 'Cash')
    if payment_method not in ['Cash', 'Mobile Money', 'Card']:
        payment_method = 'Cash'
    
    # Sanitize optional fields
    pickup_address = data.get('pickup_address', '')[:255] if data.get('pickup_address') else None
    dest_address = data.get('dest_address', '')[:255]
    note = data.get('note', '')[:255] if data.get('note') else None
    
    # Create new ride
    new_ride = Ride(
        passenger_id=current_user.id,
        pickup_address=pickup_address,
        pickup_lat=pickup_lat,
        pickup_lon=pickup_lon,
        dest_address=dest_address,
        dest_lat=dest_lat,
        dest_lon=dest_lon,
        distance_km=distance_km,
        fare=fare,
        vehicle_type=vehicle_type,
        payment_method=payment_method,
        note=note
    )
    
    db.session.add(new_ride)
    db.session.commit()
    
    return jsonify({'message': 'Ride requested successfully', 'ride_id': new_ride.id}), 201

@api.route('/assign-ride', methods=['POST'])
@admin_required
def assign_ride():
    """Assign a driver to a ride"""
    data = request.json
    ride = Ride.query.get(data.get('ride_id'))
    driver = Driver.query.get(data.get('driver_id'))
    
    if not ride or not driver:
        return jsonify({'error': 'Ride or Driver not found'}), 404

    # Assign driver to ride
    ride.driver_id = driver.id
    ride.status = 'Assigned'
    ride.assigned_time = datetime.now(timezone.utc)
    
    # Update driver status
    driver.status = 'On Trip'
    driver.current_lat = ride.pickup_lat
    driver.current_lon = ride.pickup_lon
    
    db.session.commit()
    return jsonify({'message': 'Ride assigned successfully'})

@api.route('/complete-ride', methods=['POST'])
@admin_required
def complete_ride():
    """Mark a ride as completed"""
    ride = Ride.query.get(request.json.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    
    ride.status = 'Completed'
    if ride.driver:
        ride.driver.status = 'Available'
    
    db.session.commit()
    return jsonify({'message': 'Ride marked as completed'})

@api.route('/cancel-ride', methods=['POST'])
def cancel_ride():
    """Cancel a ride"""
    ride = Ride.query.get(request.json.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    
    # Security check: only allow passenger who owns ride or an admin to cancel
    if hasattr(current_user, 'id'):
        from flask import session
        if session.get('user_type') == 'passenger' and ride.passenger_id != current_user.id:
            return jsonify({'error': 'Unauthorized'}), 403

    is_reassign = ride.status in ['Assigned', 'On Trip'] and session.get('user_type') == 'admin'

    if ride.driver:
        ride.driver.status = 'Available'

    if is_reassign:
        ride.status = 'Requested'
        ride.driver_id = None
        ride.assigned_time = None
        message = "Ride has been reassigned to the pending queue."
    else:
        ride.status = 'Canceled'
        message = 'Ride canceled successfully'

    db.session.commit()
    return jsonify({'message': message})

@api.route('/ride-status/<int:ride_id>')
def get_ride_status(ride_id):
    """Get ride status for passenger tracking"""
    ride = Ride.query.get_or_404(ride_id)
    
    # Security check for passengers
    from flask import session
    if session.get('user_type') == 'passenger' and ride.passenger_id != current_user.id:
        return jsonify({'error': 'Unauthorized'}), 403
        
    driver_info = None
    if ride.driver:
        driver_info = {
            'id': ride.driver.id,
            'name': ride.driver.name,
            'phone_number': ride.driver.phone_number,
            'vehicle_details': ride.driver.vehicle_details
        }
    
    ride_details = None
    if ride.status == 'Completed':
        ride_details = {'fare': ride.fare, 'dest_address': ride.dest_address}
    
    return jsonify({
        'status': ride.status,
        'driver': driver_info,
        'ride_details': ride_details
    })

@api.route('/fare-estimate', methods=['POST'])
def fare_estimate():
    """Calculate fare estimate based on pickup and destination"""
    if limiter:
        limiter.exempt(lambda: None)()  # Allow frequent fare estimates
    
    try:
        # Debug logging
        current_app.logger.info(f"Fare estimate request - Content-Type: {request.content_type}")
        current_app.logger.info(f"Fare estimate request - Raw data: {request.get_data()}")
        
        data = request.json
        current_app.logger.info(f"Parsed JSON data: {data}")
        
        if not data:
            current_app.logger.error("No JSON data provided")
            return jsonify({'error': 'No data provided'}), 400
        
        # Validate required fields
        required_fields = ['pickup_lat', 'pickup_lon', 'dest_lat', 'dest_lon']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Validate coordinate values
        try:
            pickup_lat = float(data['pickup_lat'])
            pickup_lon = float(data['pickup_lon'])
            dest_lat = float(data['dest_lat'])
            dest_lon = float(data['dest_lon'])
            
            # Basic coordinate validation
            if not (-90 <= pickup_lat <= 90) or not (-180 <= pickup_lon <= 180):
                return jsonify({'error': 'Invalid pickup coordinates'}), 400
            if not (-90 <= dest_lat <= 90) or not (-180 <= dest_lon <= 180):
                return jsonify({'error': 'Invalid destination coordinates'}), 400
        except (ValueError, TypeError):
            return jsonify({'error': 'Invalid coordinate format'}), 400
        
        # Get pricing settings
        base_fare = Decimal(get_setting('base_fare', '25'))
        per_km_rates = {
            "Bajaj": Decimal(get_setting('per_km_bajaj', '8')),
            "Car": Decimal(get_setting('per_km_car', '12'))
        }
        vehicle_type = data.get('vehicle_type', 'Bajaj')
        per_km_rate = per_km_rates.get(vehicle_type, per_km_rates['Bajaj'])
        
        # Call OSRM routing service
        osrm_url = (f"http://router.project-osrm.org/route/v1/driving/"
                    f"{pickup_lon},{pickup_lat};{dest_lon},{dest_lat}?overview=false")
        
        try:
            response = requests.get(osrm_url, timeout=15)
            response.raise_for_status()
            
            route_data = response.json()
            if 'routes' not in route_data or not route_data['routes']:
                return jsonify({'error': 'No route found between the locations'}), 400
            
            distance_meters = route_data['routes'][0]['distance']
            distance_km = Decimal(str(distance_meters / 1000.0))
            
        except requests.exceptions.Timeout:
            return jsonify({'error': 'Route calculation timed out. Please try again.'}), 503
        except requests.exceptions.ConnectionError:
            return jsonify({'error': 'Unable to connect to routing service. Please try again later.'}), 503
        except requests.exceptions.RequestException as e:
            current_app.logger.error(f"OSRM request failed: {str(e)}")
            return jsonify({'error': 'Route service temporarily unavailable'}), 503
        except (KeyError, IndexError, TypeError) as e:
            current_app.logger.error(f"OSRM response parsing failed: {str(e)}")
            return jsonify({'error': 'Invalid route response'}), 500
        
        # Calculate fare
        fare = (base_fare + (distance_km * per_km_rate)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        
        return jsonify({
            'distance_km': float(distance_km.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)),
            'estimated_fare': float(fare)
        })
        
    except Exception as e:
        current_app.logger.error(f"Fare estimation error: {str(e)}")
        return jsonify({'error': 'Unable to calculate fare. Please try again.'}), 500
