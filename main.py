# main.py

# --- Imports ---
from flask import Flask, request, jsonify, render_template
from flask_sqlalchemy import SQLAlchemy
import os
from math import radians, cos, sin, asin, sqrt

# --- App and Database Configuration ---
basedir = os.path.abspath(os.path.dirname(__file__))
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# --- Pricing Configuration ---
# This is a simple pricing model, e.g., 10 birr per KM + 20 birr base fare
PRICE_PER_KM = 10 
BASE_FARE = 20


# --- Database Models ---
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), unique=True, nullable=False)
    rides = db.relationship('Ride', backref='user', lazy=True)

class Driver(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), unique=True, nullable=False)
    vehicle_details = db.Column(db.String(200), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='Offline')
    rides = db.relationship('Ride', backref='driver', lazy=True)

class Ride(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True)
    pickup_lat = db.Column(db.Float, nullable=False)
    pickup_lon = db.Column(db.Float, nullable=False)
    dest_address = db.Column(db.String(255), nullable=False)
    distance_km = db.Column(db.Float, nullable=True)
    fare = db.Column(db.Float, nullable=True)
    status = db.Column(db.String(20), nullable=False, default='Requested')
    request_time = db.Column(db.DateTime, server_default=db.func.now())


# --- HTML Routes ---
@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/request')
def passenger_app():
    return render_template('passenger.html')


# --- API Endpoints ---

# RIDE ENDPOINTS
@app.route('/api/ride-request', methods=['POST'])
def create_ride_request():
    data = request.get_json()
    if not all(key in data for key in ['phone_number', 'pickup_lat', 'pickup_lon', 'dest_address', 'distance_km', 'fare']):
        return jsonify({'error': 'Missing data for ride request'}), 400
        
    user = User.query.filter_by(phone_number=data['phone_number']).first()
    if not user:
        user = User(name="New User", phone_number=data['phone_number'])
        db.session.add(user)
        db.session.commit()

    new_ride = Ride(
        user_id=user.id, 
        pickup_lat=data['pickup_lat'], 
        pickup_lon=data['pickup_lon'], 
        dest_address=data['dest_address'],
        distance_km=data['distance_km'],
        fare=data['fare']
    )
    db.session.add(new_ride)
    db.session.commit()
    return jsonify({'message': 'Ride requested successfully!'}), 201

@app.route('/api/fare-estimate', methods=['POST'])
def get_fare_estimate():
    """
    Calculates the estimated fare based on distance.
    In a real app, this would call the Google Maps Directions API.
    Here, we simulate it to avoid needing a real API key.
    """
    data = request.get_json()
    if not all(key in data for key in ['pickup_lat', 'pickup_lon', 'dest_lat', 'dest_lon']):
        return jsonify({'error': 'Missing location data'}), 400

    # --- SIMULATION of Google Maps API Call ---
    # This is a simplified distance calculation (Haversine formula).
    # A real API call is more accurate as it uses actual road data.
    lon1, lat1, lon2, lat2 = map(radians, [data['pickup_lon'], data['pickup_lat'], data['dest_lon'], data['dest_lat']])
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a)) 
    r = 6371 # Radius of earth in kilometers.
    distance = c * r
    # --- END OF SIMULATION ---

    fare = (distance * PRICE_PER_KM) + BASE_FARE

    return jsonify({
        'distance_km': round(distance, 2),
        'estimated_fare': round(fare, 2)
    })

@app.route('/api/rides/pending', methods=['GET'])
def get_pending_rides():
    rides = Ride.query.filter_by(status='Requested').all()
    output = [{'ride_id': r.id, 'user_name': r.user.name, 'dest_address': r.dest_address} for r in rides]
    return jsonify({'pending_rides': output})

@app.route('/api/rides/assigned', methods=['GET'])
def get_assigned_rides():
    rides = Ride.query.filter_by(status='Assigned').all()
    output = [{'ride_id': r.id, 'user_name': r.user.name, 'driver_name': r.driver.name} for r in rides]
    return jsonify({'assigned_rides': output})

@app.route('/api/ride/assign', methods=['POST'])
def assign_driver_to_ride():
    data = request.get_json()
    ride = Ride.query.get(data['ride_id'])
    driver = Driver.query.get(data['driver_id'])
    if not ride or not driver:
        return jsonify({'error': 'Ride or Driver not found'}), 404
    ride.driver_id = driver.id
    ride.status = 'Assigned'
    driver.status = 'On Trip'
    db.session.commit()
    return jsonify({'message': 'Success'})

@app.route('/api/ride/complete', methods=['POST'])
def complete_ride():
    data = request.get_json()
    ride = Ride.query.get(data['ride_id'])
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    
    ride.status = 'Completed'
    if ride.driver:
        ride.driver.status = 'Available'
    
    db.session.commit()
    return jsonify({'message': 'Ride completed'})

# DRIVER ENDPOINTS
@app.route('/api/drivers/add', methods=['POST'])
def add_driver():
    data = request.get_json()
    if not all(key in data for key in ['name', 'phone_number', 'vehicle_details']):
        return jsonify({'error': 'Missing data'}), 400
    if Driver.query.filter_by(phone_number=data['phone_number']).first():
        return jsonify({'error': 'Driver with this phone number already exists'}), 409
    new_driver = Driver(name=data['name'], phone_number=data['phone_number'], vehicle_details=data['vehicle_details'])
    db.session.add(new_driver)
    db.session.commit()
    return jsonify({'message': 'Driver added successfully!', 'driver_id': new_driver.id}), 201

@app.route('/api/drivers/available', methods=['GET'])
def get_available_drivers():
    drivers = Driver.query.filter_by(status='Available').all()
    output = [{'driver_id': d.id, 'name': d.name, 'vehicle_details': d.vehicle_details} for d in drivers]
    return jsonify({'available_drivers': output})

@app.route('/api/drivers/all', methods=['GET'])
def get_all_drivers():
    drivers = Driver.query.all()
    output = [{'driver_id': d.id, 'name': d.name, 'vehicle_details': d.vehicle_details, 'status': d.status} for d in drivers]
    return jsonify({'all_drivers': output})

@app.route('/api/driver/status', methods=['POST'])
def update_driver_status():
    data = request.get_json()
    driver = Driver.query.get(data['driver_id'])
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    
    if data['status'] not in ['Available', 'Offline', 'On Trip']:
         return jsonify({'error': 'Invalid status provided'}), 400

    driver.status = data['status']
    db.session.commit()
    return jsonify({'message': 'Status updated'})


# --- Main Execution ---
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True)
