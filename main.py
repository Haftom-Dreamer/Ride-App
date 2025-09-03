# main.py
from flask import Flask, render_template, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import os
import requests

# --- App and Database Setup ---
base_dir = os.path.abspath(os.path.dirname(__file__))
app = Flask(__name__)
CORS(app) 

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(base_dir, 'app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# --- Database Models ---
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    phone_number = db.Column(db.String(20), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=True)

class Driver(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False)
    vehicle_details = db.Column(db.String(150), nullable=False)
    status = db.Column(db.String(20), default='Offline', nullable=False)

class Ride(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True)
    pickup_lat = db.Column(db.Float, nullable=False)
    pickup_lon = db.Column(db.Float, nullable=False)
    dest_address = db.Column(db.String(255), nullable=False)
    distance_km = db.Column(db.Float, nullable=False)
    fare = db.Column(db.Float, nullable=False)
    # NEW: Added vehicle type to the ride
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj')
    status = db.Column(db.String(20), default='Requested', nullable=False)
    request_time = db.Column(db.DateTime, server_default=db.func.now())
    
    user = db.relationship('User', backref=db.backref('rides', lazy=True))
    driver = db.relationship('Driver', backref=db.backref('rides', lazy=True))

# --- HTML Rendering Routes ---
@app.route('/')
def dispatcher_dashboard():
    return render_template('dashboard.html')

@app.route('/request')
def passenger_app():
    return render_template('passenger.html')

# --- API Endpoints ---
@app.route('/api/ride-request', methods=['POST'])
def request_ride():
    data = request.json
    phone_number = data.get('phone_number')
    user = User.query.filter_by(phone_number=phone_number).first()
    if not user:
        user = User(phone_number=phone_number)
        db.session.add(user)
        db.session.commit()
    new_ride = Ride(
        user_id=user.id,
        pickup_lat=data.get('pickup_lat'),
        pickup_lon=data.get('pickup_lon'),
        dest_address=data.get('dest_address'),
        distance_km=data.get('distance_km'),
        fare=data.get('fare'),
        # NEW: Save the selected vehicle type
        vehicle_type=data.get('vehicle_type', 'Bajaj') 
    )
    db.session.add(new_ride)
    db.session.commit()
    return jsonify({'message': 'Ride requested successfully', 'ride_id': new_ride.id}), 201

@app.route('/api/pending-rides')
def get_pending_rides():
    rides = Ride.query.filter_by(status='Requested').order_by(Ride.request_time.desc()).all()
    rides_data = []
    for ride in rides:
        user_phone = "N/A"
        if ride.user:
            user_phone = ride.user.phone_number
        rides_data.append({
            'id': ride.id, 
            'user_phone': user_phone, 
            'pickup_lat': ride.pickup_lat, 
            'pickup_lon': ride.pickup_lon, 
            'dest_address': ride.dest_address, 
            'fare': ride.fare, 
            # NEW: Return the vehicle type to the dispatcher
            'vehicle_type': ride.vehicle_type,
            'request_time': ride.request_time.strftime('%Y-%m-%d %H:%M:%S')
        })
    return jsonify(rides_data)

# ... (All other endpoints from get_assigned_rides to cancel_ride are unchanged) ...
@app.route('/api/assigned-rides')
def get_assigned_rides():
    rides = Ride.query.filter_by(status='Assigned').order_by(Ride.request_time.desc()).all()
    rides_data = [{'id': ride.id, 'driver_name': ride.driver.name if ride.driver else 'N/A', 'user_phone': ride.user.phone_number, 'dest_address': ride.dest_address,} for ride in rides]
    return jsonify(rides_data)
@app.route('/api/drivers')
def get_all_drivers():
    drivers = Driver.query.all()
    drivers_data = [{'id': driver.id, 'name': driver.name, 'phone_number': driver.phone_number, 'vehicle_details': driver.vehicle_details, 'status': driver.status} for driver in drivers]
    return jsonify(drivers_data)
@app.route('/api/available-drivers')
def get_available_drivers():
    drivers = Driver.query.filter_by(status='Available').all()
    drivers_data = [{'id': driver.id, 'name': driver.name} for driver in drivers]
    return jsonify(drivers_data)
@app.route('/api/assign-ride', methods=['POST'])
def assign_ride():
    data = request.json
    ride_id = data.get('ride_id')
    driver_id = data.get('driver_id')
    ride = Ride.query.get(ride_id)
    driver = Driver.query.get(driver_id)
    if not ride or not driver:
        return jsonify({'error': 'Ride or Driver not found'}), 404
    ride.driver_id = driver_id
    ride.status = 'Assigned'
    driver.status = 'On Trip'
    db.session.commit()
    return jsonify({'message': 'Ride assigned successfully'})
@app.route('/api/add-driver', methods=['POST'])
def add_driver():
    data = request.json
    new_driver = Driver(name=data.get('name'), phone_number=data.get('phone_number'), vehicle_details=data.get('vehicle_details'), status='Offline')
    db.session.add(new_driver)
    db.session.commit()
    return jsonify({'message': 'Driver added successfully'}), 201
@app.route('/api/update-driver-status', methods=['POST'])
def update_driver_status():
    data = request.json
    driver_id = data.get('driver_id')
    new_status = data.get('status')
    driver = Driver.query.get(driver_id)
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    driver.status = new_status
    db.session.commit()
    return jsonify({'message': f'Driver status updated to {new_status}'})
@app.route('/api/complete-ride', methods=['POST'])
def complete_ride():
    data = request.json
    ride_id = data.get('ride_id')
    ride = Ride.query.get(ride_id)
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    ride.status = 'Completed'
    if ride.driver:
        ride.driver.status = 'Available'
    db.session.commit()
    return jsonify({'message': 'Ride marked as completed'})
@app.route('/api/cancel-ride', methods=['POST'])
def cancel_ride():
    data = request.json
    ride_id = data.get('ride_id')
    ride = Ride.query.get(ride_id)
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    if ride.status != 'Requested':
        return jsonify({'error': 'Only pending rides can be canceled'}), 400
    ride.status = 'Canceled'
    db.session.commit()
    return jsonify({'message': 'Ride canceled successfully'})


@app.route('/api/fare-estimate', methods=['POST'])
def fare_estimate():
    data = request.json
    
    # NEW: Dynamic pricing based on vehicle type
    vehicle_type = data.get('vehicle_type', 'Bajaj')
    
    # --- Pricing Configuration ---
    base_fare = 25
    per_km_rates = {
        "Bajaj": 8,
        "Car": 12 
    }
    per_km_rate = per_km_rates.get(vehicle_type, 8) # Default to Bajaj rate

    pickup_lon, pickup_lat = data['pickup_lon'], data['pickup_lat']
    dest_lon, dest_lat = data['dest_lon'], data['dest_lat']
    
    osrm_url = f"http://router.project-osrm.org/route/v1/driving/{pickup_lon},{pickup_lat};{dest_lon},{dest_lat}?overview=false"
    
    try:
        response = requests.get(osrm_url)
        response.raise_for_status()
        route_data = response.json()
        distance_meters = route_data['routes'][0]['distance']
        distance_km = distance_meters / 1000.0
        estimated_fare = round(base_fare + (distance_km * per_km_rate))
        
        return jsonify({
            'distance_km': round(distance_km, 2),
            'estimated_fare': estimated_fare
        })
        
    except requests.exceptions.RequestException as e:
        print(f"Error calling OSRM API: {e}")
        return jsonify({'error': 'Could not calculate route distance.'}), 500
    except (KeyError, IndexError):
        return jsonify({'error': 'No route found between the specified locations.'}), 400

@app.route('/api/ride-status/<int:ride_id>')
def get_ride_status(ride_id):
    ride = Ride.query.get(ride_id)
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    driver_info = None
    if ride.driver:
        driver_info = {'name': ride.driver.name, 'phone_number': ride.driver.phone_number, 'vehicle_details': ride.driver.vehicle_details}
    return jsonify({'status': ride.status, 'driver': driver_info})

# --- Main Execution ---
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True)

