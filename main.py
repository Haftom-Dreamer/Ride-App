from flask import Flask, render_template, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import os
import requests
from sqlalchemy import func, case
from datetime import datetime, timedelta
from werkzeug.utils import secure_filename

# --- App and Database Setup ---
base_dir = os.path.abspath(os.path.dirname(__file__))
app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(base_dir, 'app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = os.path.join(base_dir, 'static/uploads')
db = SQLAlchemy(app)


# --- Database Models ---
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    phone_number = db.Column(db.String(20), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=True, default='Guest')


class Driver(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False)
    vehicle_details = db.Column(db.String(150), nullable=False)
    status = db.Column(db.String(20), default='Offline', nullable=False)
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_avatar.png')
    join_date = db.Column(db.DateTime, server_default=db.func.now())
    current_lat = db.Column(db.Float, nullable=True)
    current_lon = db.Column(db.Float, nullable=True)


class Ride(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True)
    pickup_lat = db.Column(db.Float, nullable=False)
    pickup_lon = db.Column(db.Float, nullable=False)
    dest_address = db.Column(db.String(255), nullable=False)
    distance_km = db.Column(db.Float, nullable=False)
    fare = db.Column(db.Float, nullable=False)
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj')
    status = db.Column(db.String(20), default='Requested', nullable=False)
    request_time = db.Column(db.DateTime, server_default=db.func.now())
    note = db.Column(db.String(255), nullable=True)
    rating = db.Column(db.Integer, nullable=True)
    comment = db.Column(db.String(500), nullable=True)

    user = db.relationship('User', backref=db.backref('rides', lazy=True))
    driver = db.relationship('Driver', backref=db.backref('rides', lazy=True))


class Setting(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(50), unique=True, nullable=False)
    value = db.Column(db.String(100), nullable=False)


def get_setting(key, default=None):
    setting = Setting.query.filter_by(key=key).first()
    return setting.value if setting else default


@app.route('/')
def dispatcher_dashboard():
    return render_template('dashboard.html')


@app.route('/request')
def passenger_app():
    return render_template('passenger.html')


@app.route('/api/ride-request', methods=['POST'])
def request_ride():
    data = request.json
    phone_number = data.get('phone_number')
    user_name = data.get('name', 'Guest')

    user = User.query.filter_by(phone_number=phone_number).first()
    if not user:
        user = User(phone_number=phone_number, name=user_name)
        db.session.add(user)
    else:
        if user.name == 'Guest' and user_name != 'Guest':
            user.name = user_name
    db.session.commit()

    new_ride = Ride(
        user_id=user.id,
        pickup_lat=data.get('pickup_lat'),
        pickup_lon=data.get('pickup_lon'),
        dest_address=data.get('dest_address'),
        distance_km=data.get('distance_km'),
        fare=data.get('fare'),
        vehicle_type=data.get('vehicle_type', 'Bajaj'),
        note=data.get('note')
    )
    db.session.add(new_ride)
    db.session.commit()

    return jsonify({'message': 'Ride requested successfully', 'ride_id': new_ride.id}), 201


@app.route('/api/assign-ride', methods=['POST'])
def assign_ride():
    data = request.json
    ride = Ride.query.get(data.get('ride_id'))
    driver = Driver.query.get(data.get('driver_id'))
    if not ride or not driver:
        return jsonify({'error': 'Ride or Driver not found'}), 404

    ride.driver_id = driver.id
    ride.status = 'Assigned'
    driver.status = 'On Trip'
    driver.current_lat = ride.pickup_lat + 0.01
    driver.current_lon = ride.pickup_lon + 0.01
    db.session.commit()
    return jsonify({'message': 'Ride assigned successfully'})


@app.route('/api/complete-ride', methods=['POST'])
def complete_ride():
    ride = Ride.query.get(request.json.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    ride.status = 'Completed'
    if ride.driver:
        ride.driver.status = 'Available'
    db.session.commit()
    return jsonify({'message': 'Ride marked as completed'})


@app.route('/api/cancel-ride', methods=['POST'])
def cancel_ride():
    ride = Ride.query.get(request.json.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    if ride.status not in ['Requested', 'Assigned', 'On Trip']:
        return jsonify({'error': 'This ride cannot be canceled'}), 400
    if ride.driver:
        ride.driver.status = 'Available'
    ride.status = 'Canceled'
    db.session.commit()
    return jsonify({'message': 'Ride canceled successfully'})


@app.route('/api/add-driver', methods=['POST'])
def add_driver():
    name = request.form.get('name')
    phone_number = request.form.get('phone_number')
    vehicle_details = request.form.get('vehicle_details')
    
    profile_picture_path = 'static/img/default_avatar.png'
    if 'profile_picture' in request.files:
        file = request.files['profile_picture']
        if file and file.filename != '':
            filename = secure_filename(file.filename)
            upload_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(upload_path)
            profile_picture_path = os.path.join('static/uploads', filename).replace("\\", "/")

    new_driver = Driver(
        name=name,
        phone_number=phone_number,
        vehicle_details=vehicle_details,
        profile_picture=profile_picture_path,
        status='Offline'
    )
    db.session.add(new_driver)
    db.session.commit()
    return jsonify({'message': 'Driver added successfully'}), 201

@app.route('/api/update-driver/<int:driver_id>', methods=['POST'])
def update_driver(driver_id):
    driver = Driver.query.get_or_404(driver_id)
    driver.name = request.form.get('name', driver.name)
    driver.phone_number = request.form.get('phone_number', driver.phone_number)
    driver.vehicle_details = request.form.get('vehicle_details', driver.vehicle_details)
    
    if 'profile_picture' in request.files:
        file = request.files['profile_picture']
        if file and file.filename != '':
            filename = secure_filename(file.filename)
            upload_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(upload_path)
            driver.profile_picture = os.path.join('static/uploads', filename).replace("\\", "/")

    db.session.commit()
    return jsonify({'message': 'Driver updated successfully'})


@app.route('/api/delete-driver', methods=['POST'])
def delete_driver():
    data = request.json
    driver = Driver.query.get(data.get('driver_id'))
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    db.session.delete(driver)
    db.session.commit()
    return jsonify({'message': 'Driver deleted successfully'})


@app.route('/api/update-driver-status', methods=['POST'])
def update_driver_status():
    data = request.json
    driver = Driver.query.get(data.get('driver_id'))
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    driver.status = data.get('status')
    db.session.commit()
    return jsonify({'message': f'Driver status updated to {driver.status}'})


@app.route('/api/rate-ride', methods=['POST'])
def rate_ride():
    data = request.json
    ride = Ride.query.get(data.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    if ride.status != 'Completed':
        return jsonify({'error': 'Only completed rides can be rated'}), 400
    ride.rating = data.get('rating')
    if data.get('comment'):
        ride.comment = data.get('comment')
    db.session.commit()
    return jsonify({'message': 'Thank you for your feedback!'})


@app.route('/api/pending-rides')
def get_pending_rides():
    rides = Ride.query.filter_by(status='Requested').order_by(Ride.request_time.desc()).all()
    return jsonify([
        {
            'id': r.id,
            'user_name': r.user.name,
            'user_phone': r.user.phone_number,
            'pickup_lat': r.pickup_lat,
            'pickup_lon': r.pickup_lon,
            'dest_address': r.dest_address,
            'fare': r.fare,
            'vehicle_type': r.vehicle_type,
            'note': r.note,
            'request_time': r.request_time.strftime('%Y-%m-%d %H:%M:%S')
        }
        for r in rides
    ])


@app.route('/api/active-rides')
def get_active_rides():
    rides = Ride.query.filter(Ride.status.in_(['Assigned', 'On Trip'])).order_by(Ride.request_time.asc()).all()
    return jsonify([
        {
            'id': r.id,
            'user_name': r.user.name,
            'driver_name': r.driver.name if r.driver else "N/A",
            'dest_address': r.dest_address,
            'status': r.status,
            'request_time': r.request_time.strftime('%Y-%m-%d %H:%M')
        }
        for r in rides
    ])


@app.route('/api/drivers')
def get_all_drivers():
    drivers = Driver.query.all()
    return jsonify([
        {
            "id": d.id,
            "name": d.name,
            "phone_number": d.phone_number,
            "vehicle_details": d.vehicle_details,
            "status": d.status,
            "join_date": d.join_date.strftime('%Y-%m-%d'),
            "profile_picture": d.profile_picture,
            "lat": d.current_lat,
            "lon": d.current_lon
        }
        for d in drivers
    ])


@app.route('/api/driver/<int:driver_id>')
def get_driver(driver_id):
    driver = Driver.query.get_or_404(driver_id)
    return jsonify({
        "id": driver.id,
        "name": driver.name,
        "phone_number": driver.phone_number,
        "vehicle_details": driver.vehicle_details,
        "profile_picture": driver.profile_picture
    })


@app.route('/api/available-drivers')
def get_available_drivers():
    drivers = Driver.query.filter_by(status='Available').all()
    return jsonify([{'id': d.id, 'name': d.name, 'phone_number': d.phone_number} for d in drivers])


@app.route('/api/all-rides-data')
def get_all_rides_data():
    rides = Ride.query.order_by(Ride.request_time.desc()).all()
    return jsonify([
        {
            'id': r.id,
            'user_name': r.user.name,
            'user_phone': r.user.phone_number,
            'driver_name': r.driver.name if r.driver else "N/A",
            'fare': r.fare,
            'status': r.status,
            'rating': r.rating,
            'request_time': r.request_time.strftime('%Y-%m-%d %H:%M')
        }
        for r in rides
    ])


@app.route('/api/ride-status/<int:ride_id>')
def get_ride_status(ride_id):
    ride = Ride.query.get_or_404(ride_id)
    driver_info = None
    if ride.driver:
        driver_info = {
            'id': ride.driver.id,
            'name': ride.driver.name,
            'phone_number': ride.driver.phone_number,
            'vehicle_details': ride.driver.vehicle_details
        }
    ride_details = {'fare': ride.fare, 'dest_address': ride.dest_address} if ride.status == 'Completed' else None
    return jsonify({'status': ride.status, 'driver': driver_info, 'ride_details': ride_details})


@app.route('/api/driver-details/<int:driver_id>')
def get_driver_details(driver_id):
    driver = Driver.query.get_or_404(driver_id)
    stats = {
        'completed_rides': Ride.query.filter_by(driver_id=driver_id, status='Completed').count(),
        'total_earnings': db.session.query(func.sum(Ride.fare)).filter_by(driver_id=driver_id, status='Completed').scalar() or 0,
        'avg_rating': db.session.query(func.avg(Ride.rating)).filter(Ride.driver_id == driver_id, Ride.rating != None).scalar() or 0
    }
    history = Ride.query.filter_by(driver_id=driver_id).order_by(Ride.request_time.desc()).limit(10).all()
    return jsonify({
        'profile': {'name': driver.name, 'status': driver.status, 'avatar': driver.profile_picture},
        'stats': {k: round(v, 2) if isinstance(v, float) else v for k, v in stats.items()},
        'history': [{'id': r.id, 'status': r.status, 'fare': r.fare, 'date': r.request_time.strftime('%Y-%m-%d')} for r in history]
    })


@app.route('/api/fare-estimate', methods=['POST'])
def fare_estimate():
    data = request.json
    base_fare = float(get_setting('base_fare', 25))
    per_km_rates = {
        "Bajaj": float(get_setting('per_km_bajaj', 8)),
        "Car": float(get_setting('per_km_car', 12))
    }
    per_km_rate = per_km_rates.get(data.get('vehicle_type', 'Bajaj'))

    osrm_url = (
        f"http://router.project-osrm.org/route/v1/driving/"
        f"{data['pickup_lon']},{data['pickup_lat']};{data['dest_lon']},{data['dest_lat']}?overview=false"
    )

    try:
        response = requests.get(osrm_url)
        response.raise_for_status()
        distance_km = response.json()['routes'][0]['distance'] / 1000.0
        fare = round(base_fare + (distance_km * per_km_rate))
        return jsonify({'distance_km': round(distance_km, 2), 'estimated_fare': fare})
    except (requests.exceptions.RequestException, KeyError, IndexError) as e:
        return jsonify({'error': 'Could not calculate route.'}), 500


@app.route('/api/dashboard-stats')
def get_dashboard_stats():
    total_revenue = db.session.query(func.sum(Ride.fare)).filter(Ride.status == 'Completed').scalar() or 0
    total_rides = Ride.query.count()
    drivers_online = Driver.query.filter(Driver.status == 'Available').count()
    pending_requests = Ride.query.filter(Ride.status == 'Requested').count()

    return jsonify({
        'total_revenue': round(total_revenue, 2),
        'total_rides': total_rides,
        'drivers_online': drivers_online,
        'pending_requests': pending_requests,
    })

@app.route('/api/analytics-data')
def get_analytics_data():
    period = request.args.get('period')
    start_date_str = request.args.get('start_date')
    end_date_str = request.args.get('end_date')

    now = datetime.utcnow()
    end_date = now.replace(hour=23, minute=59, second=59)
    start_date = None

    if period == 'today':
        start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == 'week':
        start_date = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == 'month':
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    elif start_date_str and end_date_str:
        try:
            start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
            end_date = datetime.strptime(end_date_str, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
        except (ValueError, TypeError):
            start_date = None
            
    # Base query for the selected period
    base_query = Ride.query
    if start_date:
        base_query = base_query.filter(Ride.request_time.between(start_date, end_date))

    # Create subqueries for different statuses within the period
    completed_rides_sq = base_query.filter(Ride.status == 'Completed').subquery()
    canceled_rides_sq = base_query.filter(Ride.status == 'Canceled').subquery()

    # Calculate KPIs using the subqueries
    completed_rides_in_period = db.session.query(func.count(completed_rides_sq.c.id)).scalar()
    canceled_rides_in_period = db.session.query(func.count(canceled_rides_sq.c.id)).scalar()
    
    revenue_in_period = db.session.query(func.sum(completed_rides_sq.c.fare)).scalar() or 0
    avg_fare_in_period = db.session.query(func.avg(completed_rides_sq.c.fare)).scalar() or 0

    # Current State KPI (not affected by date range)
    active_rides_now = Ride.query.filter(Ride.status.in_(['Assigned', 'On Trip'])).count()

    # Chart data for the period
    revenue_by_day_query = db.session.query(
        func.date(completed_rides_sq.c.request_time).label('day'),
        func.sum(completed_rides_sq.c.fare)
    ).group_by('day').order_by('day').all()
    
    revenue_chart_data = {
        'labels': [item[0] for item in revenue_by_day_query],
        'data': [float(item[1]) if item[1] is not None else 0 for item in revenue_by_day_query]
    }
    
    return jsonify({
        'kpis': {
            'rides_completed': completed_rides_in_period,
            'rides_canceled': canceled_rides_in_period,
            'total_revenue': round(revenue_in_period, 2),
            'avg_fare': round(avg_fare_in_period, 2),
            'active_rides_now': active_rides_now
        },
        'revenue_chart': revenue_chart_data
    })


@app.route('/api/rides-by-day')
def get_rides_by_day():
    rides = Ride.query.order_by(Ride.request_time.desc()).limit(100).all()
    rides_by_day = {}
    for ride in rides:
        day = ride.request_time.strftime('%Y-%m-%d')
        rides_by_day[day] = rides_by_day.get(day, 0) + 1
    sorted_days = sorted(rides_by_day.items())[-7:]
    return jsonify({'labels': [d[0] for d in sorted_days], 'data': [d[1] for d in sorted_days]})


@app.route('/api/rides-by-vehicle')
def get_rides_by_vehicle():
    return jsonify(dict(db.session.query(Ride.vehicle_type, func.count(Ride.vehicle_type)).group_by(Ride.vehicle_type).all()))


@app.route('/api/settings', methods=['GET', 'POST'])
def handle_settings():
    if request.method == 'POST':
        for key, value in request.json.items():
            setting = Setting.query.filter_by(key=key).first()
            if setting:
                setting.value = str(value)
            else:
                db.session.add(Setting(key=key, value=str(value)))
        db.session.commit()
        return jsonify({'message': 'Settings saved successfully!'})
    else:
        return jsonify({s.key: s.value for s in Setting.query.all()})


# --- Main Execution ---
if __name__ == '__main__':
    with app.app_context():
        os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
        db.create_all()
        if not Setting.query.first():
            db.session.add(Setting(key='base_fare', value='25'))
            db.session.add(Setting(key='per_km_bajaj', value='8'))
            db.session.add(Setting(key='per_km_car', value='12'))
            db.session.commit()
    app.run(debug=True)

