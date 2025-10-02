from flask import Flask, render_template, request, jsonify, send_from_directory, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import os
import requests
from sqlalchemy import func, case
from datetime import datetime, timedelta, timezone
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from reportlab.lib.pagesizes import letter, landscape
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib import colors
import io
import openpyxl
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.utils import get_column_letter

# --- App and Database Setup ---
base_dir = os.path.abspath(os.path.dirname(__file__))
app = Flask(__name__)
CORS(app)

app.config['SECRET_KEY'] = 'a-very-secret-key-that-should-be-changed'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(base_dir, 'app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = os.path.join(base_dir, 'static/uploads')
db = SQLAlchemy(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'


# --- Database Models ---
class Admin(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_avatar.png')


    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    phone_number = db.Column(db.String(20), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=True, default='Guest')


class Driver(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    driver_uid = db.Column(db.String(20), unique=True, nullable=True) # User-friendly ID
    name = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False)
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj')
    vehicle_details = db.Column(db.String(150), nullable=False)
    vehicle_plate_number = db.Column(db.String(50), nullable=True)
    license_info = db.Column(db.String(100), nullable=True)
    status = db.Column(db.String(20), default='Offline', nullable=False)
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_avatar.png')
    license_document = db.Column(db.String(255), nullable=True)
    vehicle_document = db.Column(db.String(255), nullable=True)
    join_date = db.Column(db.DateTime, server_default=db.func.now())
    current_lat = db.Column(db.Float, nullable=True)
    current_lon = db.Column(db.Float, nullable=True)


class Ride(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True)
    pickup_address = db.Column(db.String(255), nullable=True)
    pickup_lat = db.Column(db.Float, nullable=False)
    pickup_lon = db.Column(db.Float, nullable=False)
    dest_address = db.Column(db.String(255), nullable=False)
    dest_lat = db.Column(db.Float, nullable=True)
    dest_lon = db.Column(db.Float, nullable=True)
    distance_km = db.Column(db.Float, nullable=False)
    fare = db.Column(db.Float, nullable=False)
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj')
    status = db.Column(db.String(20), default='Requested', nullable=False)
    request_time = db.Column(db.DateTime, server_default=db.func.now(timezone.utc))
    assigned_time = db.Column(db.DateTime, nullable=True)
    note = db.Column(db.String(255), nullable=True)
    payment_method = db.Column(db.String(20), nullable=False, default='Cash')


    user = db.relationship('User', backref=db.backref('rides', lazy=True))
    driver = db.relationship('Driver', backref=db.backref('rides', lazy=True))
    feedback = db.relationship('Feedback', backref='ride', uselist=False, cascade="all, delete-orphan")


class Feedback(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('ride.id'), unique=True, nullable=False)
    rating = db.Column(db.Integer, nullable=True)
    comment = db.Column(db.String(500), nullable=True)
    feedback_type = db.Column(db.String(50), nullable=False, default='Rating') # e.g., 'Rating', 'Complaint', 'Lost Item'
    details = db.Column(db.Text, nullable=True) # For complaint/lost item details
    is_resolved = db.Column(db.Boolean, default=False)
    submitted_at = db.Column(db.DateTime, server_default=db.func.now(timezone.utc))


class Setting(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(50), unique=True, nullable=False)
    value = db.Column(db.String(100), nullable=False)


def get_setting(key, default=None):
    setting = Setting.query.filter_by(key=key).first()
    return setting.value if setting else default

# --- Helper Functions ---
def _handle_file_upload(file_storage, existing_path=None):
    """
    Save an uploaded FileStorage to app.config['UPLOAD_FOLDER'] and return a web-relative path.
    If no file is provided, return existing_path (so caller keeps previous value).
    """
    if not file_storage:
        return existing_path

    filename = secure_filename(file_storage.filename or '')
    if not filename:
        return existing_path

    # Ensure upload folder exists
    os.makedirs(app.config.get('UPLOAD_FOLDER', os.path.join(base_dir, 'static', 'uploads')), exist_ok=True)

    # Avoid overwriting existing files by appending a timestamp if needed
    save_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if os.path.exists(save_path):
        name, ext = os.path.splitext(filename)
        filename = f"{name}_{int(datetime.utcnow().timestamp())}{ext}"
        save_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)

    # Save file
    file_storage.save(save_path)

    # Return a path usable by templates (static relative path)
    rel_path = os.path.join('static', 'uploads', filename).replace('\\', '/')
    return rel_path

# --- Authentication ---
@login_manager.user_loader
def load_user(user_id):
    return Admin.query.get(int(user_id))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('dispatcher_dashboard'))
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        admin = Admin.query.filter_by(username=username).first()
        if admin and admin.check_password(password):
            login_user(admin)
            return redirect(url_for('dispatcher_dashboard'))
        else:
            flash('Invalid username or password', 'danger')
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

# --- Frontend Routes ---
@app.route('/')
@login_required
def dispatcher_dashboard():
    return render_template('dashboard.html')


@app.route('/request')
def passenger_app():
    return render_template('passenger.html')

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# --- API Routes ---
@app.route('/api/ride-request', methods=['POST'])
def request_ride():
    data = request.json
    phone_number = data.get('phone_number')
    user_name = data.get('name', 'Guest')

    user = User.query.filter_by(phone_number=phone_number).first()
    if not user:
        user = User(phone_number=phone_number, name=user_name)
        db.session.add(user)
    elif user.name == 'Guest' and user_name != 'Guest':
        user.name = user_name
    db.session.commit()

    new_ride = Ride(
        user_id=user.id,
        pickup_address=data.get('pickup_address'),
        pickup_lat=data.get('pickup_lat'),
        pickup_lon=data.get('pickup_lon'),
        dest_address=data.get('dest_address'),
        dest_lat=data.get('dest_lat'),
        dest_lon=data.get('dest_lon'),
        distance_km=data.get('distance_km'),
        fare=data.get('fare'),
        vehicle_type=data.get('vehicle_type', 'Bajaj'),
        note=data.get('note'),
        payment_method=data.get('payment_method', 'Cash'),
        request_time=datetime.now(timezone.utc)
    )
    db.session.add(new_ride)
    db.session.commit()

    return jsonify({'message': 'Ride requested successfully', 'ride_id': new_ride.id}), 201


@app.route('/api/assign-ride', methods=['POST'])
@login_required
def assign_ride():
    data = request.json
    ride = Ride.query.get(data.get('ride_id'))
    driver = Driver.query.get(data.get('driver_id'))
    if not ride or not driver:
        return jsonify({'error': 'Ride or Driver not found'}), 404

    ride.driver_id = driver.id
    ride.status = 'Assigned'
    ride.assigned_time = datetime.now(timezone.utc)
    driver.status = 'On Trip'
    driver.current_lat = ride.pickup_lat
    driver.current_lon = ride.pickup_lon
    db.session.commit()
    return jsonify({'message': 'Ride assigned successfully'})


@app.route('/api/complete-ride', methods=['POST'])
@login_required
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
@login_required
def cancel_ride():
    ride = Ride.query.get(request.json.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    
    is_reassign = ride.status in ['Assigned', 'On Trip']

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


@app.route('/api/add-driver', methods=['POST'])
@login_required
def add_driver():
    new_driver = Driver(
        name=request.form.get('name'),
        phone_number=request.form.get('phone_number'),
        vehicle_type=request.form.get('vehicle_type'),
        vehicle_details=request.form.get('vehicle_details'),
        vehicle_plate_number=request.form.get('vehicle_plate_number'),
        license_info=request.form.get('license_info'),
        status='Offline',
        profile_picture=_handle_file_upload(request.files.get('profile_picture'), 'static/img/default_avatar.png'),
        license_document=_handle_file_upload(request.files.get('license_document')),
        vehicle_document=_handle_file_upload(request.files.get('vehicle_document'))
    )
    db.session.add(new_driver)
    db.session.flush()
    new_driver.driver_uid = f"DRV-{new_driver.id:04d}"
    db.session.commit()
    return jsonify({'message': 'Driver added successfully'}), 201

@app.route('/api/update-driver/<int:driver_id>', methods=['POST'])
@login_required
def update_driver(driver_id):
    driver = Driver.query.get_or_404(driver_id)
    driver.name = request.form.get('name', driver.name)
    driver.phone_number = request.form.get('phone_number', driver.phone_number)
    driver.vehicle_type = request.form.get('vehicle_type', driver.vehicle_type)
    driver.vehicle_details = request.form.get('vehicle_details', driver.vehicle_details)
    driver.vehicle_plate_number = request.form.get('vehicle_plate_number', driver.vehicle_plate_number)
    driver.license_info = request.form.get('license_info', driver.license_info)
    
    driver.profile_picture = _handle_file_upload(request.files.get('profile_picture'), driver.profile_picture)
    driver.license_document = _handle_file_upload(request.files.get('license_document'), driver.license_document)
    driver.vehicle_document = _handle_file_upload(request.files.get('vehicle_document'), driver.vehicle_document)

    db.session.commit()
    return jsonify({'message': 'Driver updated successfully'})


@app.route('/api/delete-driver', methods=['POST'])
@login_required
def delete_driver():
    data = request.json
    driver = Driver.query.get(data.get('driver_id'))
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    db.session.delete(driver)
    db.session.commit()
    return jsonify({'message': 'Driver deleted successfully'})


@app.route('/api/update-driver-status', methods=['POST'])
@login_required
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
    
    feedback = Feedback.query.filter_by(ride_id=ride.id).first()
    if not feedback:
        feedback = Feedback(ride_id=ride.id)
        db.session.add(feedback)

    feedback.rating = data.get('rating')
    feedback.comment = data.get('comment')
    feedback.feedback_type = 'Rating'

    db.session.commit()
    return jsonify({'message': 'Thank you for your feedback!'})

@app.route('/api/all-feedback')
@login_required
def get_all_feedback():
    feedback_items = Feedback.query.order_by(Feedback.is_resolved.asc(), Feedback.submitted_at.desc()).all()
    return jsonify([
        {
            'id': f.id,
            'ride_id': f.ride_id,
            'passenger_name': f.ride.user.name,
            'driver_name': f.ride.driver.name if f.ride.driver else 'N/A',
            'rating': f.rating,
            'comment': f.comment,
            'type': f.feedback_type,
            'details': f.details,
            'is_resolved': f.is_resolved,
            'date': f.submitted_at.strftime('%Y-%m-%d %H:%M')
        }
        for f in feedback_items
    ])

@app.route('/api/unread-feedback-count')
@login_required
def get_unread_feedback_count():
    count = Feedback.query.filter_by(is_resolved=False).count()
    return jsonify({'count': count})

@app.route('/api/feedback/resolve/<int:feedback_id>', methods=['POST'])
@login_required
def resolve_feedback(feedback_id):
    feedback = Feedback.query.get_or_404(feedback_id)
    feedback.is_resolved = True
    db.session.commit()
    return jsonify({'message': 'Feedback marked as resolved.'})


# --- Data Fetching API Routes ---
@app.route('/api/pending-rides')
@login_required
def get_pending_rides():
    rides = Ride.query.filter_by(status='Requested').order_by(Ride.request_time.desc()).all()
    return jsonify([
        {
            'id': r.id,
            'user_name': r.user.name,
            'user_phone': r.user.phone_number,
            'pickup_address': r.pickup_address,
            'pickup_lat': r.pickup_lat,
            'pickup_lon': r.pickup_lon,
            'dest_address': r.dest_address,
            'fare': r.fare,
            'vehicle_type': r.vehicle_type,
            'note': r.note,
            'request_time': r.request_time.strftime('%I:%M %p'),
        }
        for r in rides
    ])

@app.route('/api/active-rides')
@login_required
def get_active_rides():
    rides = Ride.query.filter(Ride.status.in_(['Assigned', 'On Trip'])).order_by(Ride.request_time.asc()).all()
    return jsonify([ { 
        'id': r.id, 
        'user_name': r.user.name, 
        'driver_name': r.driver.name if r.driver else "N/A", 
        'dest_address': r.dest_address, 
        'status': r.status, 
        'request_time': r.request_time.strftime('%Y-%m-%d %H:%M'),
        'pickup_lat': r.pickup_lat,
        'pickup_lon': r.pickup_lon,
        'dest_lat': r.dest_lat,
        'dest_lon': r.dest_lon
    } for r in rides ])


@app.route('/api/drivers')
@login_required
def get_all_drivers():
    drivers = Driver.query.all()
    drivers_data = []
    for d in drivers:
        avg_rating = db.session.query(func.avg(Feedback.rating)).join(Ride).filter(Ride.driver_id == d.id, Feedback.rating.isnot(None)).scalar() or 0
        drivers_data.append({ "id": d.id, "driver_uid": d.driver_uid, "name": d.name, "phone_number": d.phone_number, "vehicle_type": d.vehicle_type, "vehicle_details": d.vehicle_details, "status": d.status, "join_date": d.join_date.strftime('%Y-%m-%d'), "profile_picture": d.profile_picture, "lat": d.current_lat, "lon": d.current_lon, "avg_rating": avg_rating })
    return jsonify(drivers_data)


@app.route('/api/driver/<int:driver_id>')
@login_required
def get_driver(driver_id):
    driver = Driver.query.get_or_404(driver_id)
    return jsonify({ "id": driver.id, "name": driver.name, "phone_number": driver.phone_number, "vehicle_type": driver.vehicle_type, "vehicle_details": driver.vehicle_details, "vehicle_plate_number": driver.vehicle_plate_number, "license_info": driver.license_info, "profile_picture": driver.profile_picture, "license_document": driver.license_document, "vehicle_document": driver.vehicle_document, })


@app.route('/api/available-drivers')
@login_required
def get_available_drivers():
    vehicle_type = request.args.get('vehicle_type')
    query = Driver.query.filter_by(status='Available')
    if vehicle_type:
        query = query.filter_by(vehicle_type=vehicle_type)
    
    drivers = query.all()
    
    drivers_data = [
        {'id': d.id, 'name': d.name, 'vehicle_type': d.vehicle_type, 'status': d.status}
        for d in drivers
    ]

    return jsonify(drivers_data)


@app.route('/api/all-rides-data')
@login_required
def get_all_rides_data():
    rides = Ride.query.options(db.joinedload(Ride.feedback)).order_by(Ride.request_time.desc()).all()
    return jsonify([
        {
            'id': r.id,
            'user_name': r.user.name,
            'user_phone': r.user.phone_number,
            'driver_name': r.driver.name if r.driver else "N/A",
            'fare': r.fare,
            'status': r.status,
            'rating': r.feedback.rating if r.feedback else None,
            'request_time': r.request_time.strftime('%Y-%m-%d %H:%M')
        }
        for r in rides
    ])


@app.route('/api/ride-status/<int:ride_id>')
def get_ride_status(ride_id):
    ride = Ride.query.get_or_404(ride_id)
    driver_info = None
    if ride.driver:
        driver_info = { 'id': ride.driver.id, 'name': ride.driver.name, 'phone_number': ride.driver.phone_number, 'vehicle_details': ride.driver.vehicle_details }
    ride_details = {'fare': ride.fare, 'dest_address': ride.dest_address} if ride.status == 'Completed' else None
    return jsonify({'status': ride.status, 'driver': driver_info, 'ride_details': ride_details})


@app.route('/api/driver-details/<int:driver_id>')
@login_required
def get_driver_details(driver_id):
    driver = Driver.query.get_or_404(driver_id)
    
    now = datetime.now(timezone.utc)
    week_start = now - timedelta(days=now.weekday())

    total_earnings_all_time = db.session.query(func.sum(Ride.fare)).filter(Ride.driver_id == driver_id, Ride.status == 'Completed').scalar() or 0
    stats = {
        'completed_rides': Ride.query.filter_by(driver_id=driver_id, status='Completed').count(),
        'total_earnings_all_time': total_earnings_all_time,
        'total_earnings_weekly': db.session.query(func.sum(Ride.fare)).filter(Ride.driver_id == driver_id, Ride.status == 'Completed', Ride.request_time >= week_start).scalar() or 0,
        'avg_rating': db.session.query(func.avg(Feedback.rating)).join(Ride).filter(Ride.driver_id == driver.id, Feedback.rating.isnot(None)).scalar() or 0
    }
    history = Ride.query.filter_by(driver_id=driver_id).order_by(Ride.request_time.desc()).limit(10).all()
    return jsonify({
        'profile': { 'name': driver.name, 'driver_uid': driver.driver_uid, 'status': driver.status, 'avatar': driver.profile_picture, 'phone_number': driver.phone_number, 'vehicle_type': driver.vehicle_type, 'vehicle_details': driver.vehicle_details, 'plate_number': driver.vehicle_plate_number, 'license': driver.license_info, 'license_document': driver.license_document, 'vehicle_document': driver.vehicle_document },
        'stats': {k: round(v, 2) if isinstance(v, float) else v for k, v in stats.items()},
        'history': [{'id': r.id, 'status': r.status, 'fare': r.fare, 'date': r.request_time.strftime('%Y-%m-%d')} for r in history]
    })


@app.route('/api/fare-estimate', methods=['POST'])
def fare_estimate():
    data = request.json
    base_fare = float(get_setting('base_fare', 25))
    per_km_rates = { "Bajaj": float(get_setting('per_km_bajaj', 8)), "Car": float(get_setting('per_km_car', 12)) }
    per_km_rate = per_km_rates.get(data.get('vehicle_type', 'Bajaj'))
    osrm_url = (f"http://router.project-osrm.org/route/v1/driving/" f"{data['pickup_lon']},{data['pickup_lat']};{data['dest_lon']},{data['dest_lat']}?overview=false")
    try:
        response = requests.get(osrm_url)
        response.raise_for_status()
        distance_km = response.json()['routes'][0]['distance'] / 1000.0
        fare = round(base_fare + (distance_km * per_km_rate))
        return jsonify({'distance_km': round(distance_km, 2), 'estimated_fare': fare})
    except (requests.exceptions.RequestException, KeyError, IndexError):
        return jsonify({'error': 'Could not calculate route.'}), 500


@app.route('/api/dashboard-stats')
@login_required
def get_dashboard_stats():
    total_revenue = db.session.query(func.sum(Ride.fare)).filter(Ride.status == 'Completed').scalar() or 0
    total_rides = Ride.query.count()
    drivers_online = Driver.query.filter(Driver.status == 'Available').count()
    pending_requests = Ride.query.filter(Ride.status == 'Requested').count()
    return jsonify({ 'total_revenue': round(total_revenue, 2), 'total_rides': total_rides, 'drivers_online': drivers_online, 'pending_requests': pending_requests, 'active_rides': Ride.query.filter(Ride.status.in_(['Assigned', 'On Trip'])).count() })

# --- Analytics and Reporting ---
def _get_previous_period(start_date, end_date):
    if not start_date or not end_date: return None, None
    delta = end_date - start_date
    prev_end_date = start_date - timedelta(microseconds=1)
    prev_start_date = prev_end_date - delta
    return prev_start_date, prev_end_date

def _calculate_kpis_for_period(start, end):
    query = Ride.query
    if start and end: query = query.filter(Ride.request_time.between(start, end))
    completed_sq = query.filter(Ride.status == 'Completed').subquery()
    revenue = db.session.query(func.sum(completed_sq.c.fare)).scalar() or 0
    completed_rides = db.session.query(func.count(completed_sq.c.id)).scalar()
    return revenue, completed_rides

def _calculate_trend(current, previous):
    if previous == 0: return 100 if current > 0 else 0
    return round(((current - previous) / previous) * 100)
    
def _get_date_range_from_request():
    """Parses date filter arguments from the request and returns timezone-aware start and end datetimes (UTC)."""
    period = request.args.get('period')
    start_date_str = request.args.get('start_date')
    end_date_str = request.args.get('end_date')

    if period == 'all' or not period:
        return None, None

    now = datetime.now(timezone.utc)

    if period == 'today':
        start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end_date = now
    elif period == 'week':
        start_date = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
        end_date = now
    elif period == 'month':
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        end_date = now
    elif start_date_str and end_date_str:
        try:
            start_date = datetime.strptime(start_date_str, '%Y-%m-%d').replace(tzinfo=timezone.utc)
            end_date = datetime.strptime(end_date_str, '%Y-%m-%d').replace(hour=23, minute=59, second=59, tzinfo=timezone.utc)
        except (ValueError, TypeError):
            # invalid date format -> no filter
            return None, None
    else:
        # invalid period or missing explicit dates
        return None, None

    return start_date, end_date

@app.route('/api/analytics-data')
@login_required
def get_analytics_data():
    start_date, end_date = _get_date_range_from_request()
    now = datetime.now(timezone.utc)
    base_query = Ride.query
    if start_date and end_date:
        base_query = base_query.filter(Ride.request_time.between(start_date, end_date))

    completed_rides_sq = base_query.filter(Ride.status == 'Completed').subquery()
    completed_rides_in_period = db.session.query(func.count(completed_rides_sq.c.id)).scalar() or 0
    revenue_in_period = db.session.query(func.sum(completed_rides_sq.c.fare)).scalar() or 0
    prev_start_date, prev_end_date = _get_previous_period(start_date, end_date)
    prev_revenue, prev_completed_rides = (0, 0) if not (prev_start_date and prev_end_date) else _calculate_kpis_for_period(prev_start_date, prev_end_date)
    
    now_week_start = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    
    top_drivers_query = db.session.query(
        Driver.name,
        Driver.profile_picture,
        func.count(Ride.id).label('completed_rides'),
        func.avg(Feedback.rating).label('avg_rating')
    ).join(Ride, Driver.id == Ride.driver_id).outerjoin(Feedback, Ride.id == Feedback.ride_id).filter(
        Ride.status == 'Completed',
        Ride.request_time >= now_week_start
    ).group_by(Driver.id).order_by(
        func.count(Ride.id).desc()
    ).limit(5).all()

    return jsonify({
        'kpis': { 'rides_completed': completed_rides_in_period, 'rides_canceled': base_query.filter(Ride.status == 'Canceled').count(), 'total_revenue': round(revenue_in_period, 2), 'avg_fare': round(db.session.query(func.avg(completed_rides_sq.c.fare)).scalar() or 0, 2), 'active_rides_now': Ride.query.filter(Ride.status.in_(['Assigned', 'On Trip'])).count(), 'trends': { 'revenue': _calculate_trend(revenue_in_period, prev_revenue), 'rides': _calculate_trend(completed_rides_in_period, prev_completed_rides) } },
        'charts': { 'revenue_over_time': { 'labels': [i[0] for i in db.session.query(func.date(completed_rides_sq.c.request_time).label('d'), func.sum(completed_rides_sq.c.fare)).group_by('d').order_by('d').all()], 'data': [float(i[1] or 0) for i in db.session.query(func.date(completed_rides_sq.c.request_time).label('d'), func.sum(completed_rides_sq.c.fare)).group_by('d').order_by('d').all()] }, 'vehicle_distribution': dict(base_query.with_entities(Ride.vehicle_type, func.count(Ride.id)).group_by(Ride.vehicle_type).all()), 'payment_method_distribution': dict(base_query.with_entities(Ride.payment_method, func.count(Ride.id)).group_by(Ride.payment_method).all()), },
        'performance': { 'top_drivers': [{'name': d.name, 'avatar': d.profile_picture, 'completed_rides': d.completed_rides, 'avg_rating': round(d.avg_rating or 0, 2)} for d in top_drivers_query] }
    })

@app.route('/api/export-report')
@login_required
def export_report():
    file_format = request.args.get('format', 'pdf')
    start_date, end_date = _get_date_range_from_request()
    
    ride_query = Ride.query.options(db.joinedload(Ride.user), db.joinedload(Ride.driver)).order_by(Ride.request_time.desc())
    if start_date and end_date:
        ride_query = ride_query.filter(Ride.request_time.between(start_date, end_date))
    
    all_rides_in_period = ride_query.all()
    all_drivers = Driver.query.all()
    
    # Create a new request context to call the analytics endpoint internally
    with app.test_request_context(f'/api/analytics-data?{request.query_string.decode("utf-8")}'):
        kpis_response = get_analytics_data()
        kpis = kpis_response.get_json().get('kpis', {}) if kpis_response.get_json() else {}

    report_title = f"Analytics Report ({start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')})" if start_date and end_date else "Analytics Report (All Time)"

    if file_format == 'pdf':
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=landscape(letter))
        styles = getSampleStyleSheet()
        elements = [ Paragraph("Ride App - Dispatcher Analytics", styles['h1']), Paragraph(report_title, styles['h2']), Spacer(1, 24) ]
        kpi_data = [ ["Metric", "Value", "Trend"], ["Rides Completed", f"{kpis['rides_completed']}", f"{kpis['trends']['rides']}%"], ["Total Revenue", f"{kpis['total_revenue']} ETB", f"{kpis['trends']['revenue']}%"], ["Rides Canceled", kpis['rides_canceled'], ""], ["Average Fare", f"{kpis['avg_fare']} ETB", ""], ]
        kpi_table = Table(kpi_data, colWidths=[200, 150, 100]); kpi_table.setStyle(TableStyle([ ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#4A5568')), ('TEXTCOLOR',(0,0),(-1,0),colors.whitesmoke), ('ALIGN', (0,0), (-1,-1), 'CENTER'), ('VALIGN', (0,0), (-1,-1), 'MIDDLE'), ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'), ('GRID', (0,0), (-1,-1), 1, colors.black) ])); elements.extend([Paragraph("Key Metrics Summary", styles['h3']), kpi_table, Spacer(1, 24)])
        ride_data_for_table = [["ID", "Date", "Passenger", "Driver", "Fare", "Status"]]
        for ride in all_rides_in_period: ride_data_for_table.append([ ride.id, ride.request_time.strftime('%Y-%m-%d %H:%M'), ride.user.name, ride.driver.name if ride.driver else 'N/A', f"{ride.fare} ETB", ride.status ])
        ride_table = Table(ride_data_for_table, colWidths=[40, 120, 120, 120, 80, 80]); ride_table.setStyle(TableStyle([ ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#2D3748')), ('TEXTCOLOR',(0,0),(-1,0),colors.whitesmoke), ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'), ('GRID', (0,0), (-1,-1), 1, colors.black), ('ALIGN', (0,0), (-1,-1), 'CENTER'), ])); elements.extend([Paragraph("All Rides in Period", styles['h3']), ride_table]); doc.build(elements); buffer.seek(0)
        return buffer.getvalue(), 200, { 'Content-Type': 'application/pdf', 'Content-Disposition': 'attachment; filename="analytics_report.pdf"' }

    elif file_format == 'excel':
        wb = openpyxl.Workbook()
        ws_summary = wb.active
        ws_summary.title = "Summary Report"
        ws_summary.append([report_title])
        ws_summary['A1'].font = Font(bold=True, size=16)
        ws_summary.append([])
        ws_summary.append(["Key Metrics"])
        ws_summary['A3'].font = Font(bold=True, size=14)
        ws_summary.append(["Metric", "Value"])
        for cell in ws_summary[4]:
            cell.font = Font(bold=True)
        ws_summary.append(["Rides Completed", kpis.get('rides_completed', 'N/A')])
        ws_summary.append(["Rides Canceled", kpis.get('rides_canceled', 'N/A')])
        ws_summary.append(["Total Revenue (ETB)", kpis.get('total_revenue', 'N/A')])
        ws_summary.append(["Average Fare (ETB)", kpis.get('avg_fare', 'N/A')])
        ws_summary['D4'] = "Rides Trend"; ws_summary['D4'].font = Font(bold=True)
        ws_summary['E4'] = f"{kpis.get('trends', {}).get('rides', 'N/A')}%"
        ws_summary['D5'] = "Revenue Trend"; ws_summary['D5'].font = Font(bold=True)
        ws_summary['E5'] = f"{kpis.get('trends', {}).get('revenue', 'N/A')}%"
        
        ws_drivers = wb.create_sheet("Driver Performance")
        ws_drivers.append(["Driver ID", "Name", "Rides in Period", "Revenue in Period (ETB)", "Average Rating"])
        for cell in ws_drivers[1]:
            cell.font = Font(bold=True)
        for driver in all_drivers:
            rides_in_period_query = Ride.query.filter(Ride.driver_id == driver.id, Ride.status == 'Completed')
            if start_date and end_date: 
                rides_in_period_query = rides_in_period_query.filter(Ride.request_time.between(start_date, end_date))
            
            rides_in_period_count = rides_in_period_query.count()
            total_revenue = rides_in_period_query.with_entities(func.sum(Ride.fare)).scalar() or 0
            avg_rating = db.session.query(func.avg(Feedback.rating)).join(Ride).filter(Ride.driver_id == driver.id, Feedback.rating.isnot(None)).scalar() or 0
            ws_drivers.append([ driver.driver_uid, driver.name, rides_in_period_count, round(total_revenue, 2), round(avg_rating, 2) if avg_rating else 0 ])

        ws_raw = wb.create_sheet("Raw Ride Data")
        ws_raw.append(["Ride ID", "Request Time", "Status", "Passenger Name", "Passenger Phone", "Driver Name", "Fare", "Vehicle", "Payment", "Rating"])
        for cell in ws_raw[1]:
            cell.font = Font(bold=True)
        for ride in all_rides_in_period: ws_raw.append([ ride.id, ride.request_time.strftime('%Y-%m-%d %H:%M'), ride.status, ride.user.name, ride.user.phone_number, ride.driver.name if ride.driver else 'N/A', ride.fare, ride.vehicle_type, ride.payment_method, ride.feedback.rating if ride.feedback else None ])
        
        for ws in wb.worksheets:
            for col in ws.columns:
                max_length = 0
                column_letter = get_column_letter(col[0].column)
                for cell in col:
                    try: 
                        if len(str(cell.value)) > max_length: max_length = len(str(cell.value))
                    except: pass
                ws.column_dimensions[column_letter].width = (max_length + 2) if max_length < 50 else 50
        buffer = io.BytesIO()
        wb.save(buffer)
        buffer.seek(0)
        return buffer.getvalue(), 200, { 'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'Content-Disposition': 'attachment; filename="analytics_report.xlsx"' }
    return jsonify({"error": "Invalid format"}), 400


@app.route('/api/settings', methods=['GET', 'POST'])
@login_required
def handle_settings():
    if request.method == 'POST':
        for key, value in request.json.items():
            setting = Setting.query.filter_by(key=key).first();
            if setting: setting.value = str(value)
            else: db.session.add(Setting(key=key, value=str(value)))
        db.session.commit(); return jsonify({'message': 'Settings saved successfully!'})
    else: return jsonify({s.key: s.value for s in Setting.query.all()})

# --- Admin Management API ---
@app.route('/api/admins', methods=['GET'])
@login_required
def get_admins():
    admins = Admin.query.all()
    return jsonify([{'id': admin.id, 'username': admin.username} for admin in admins])

@app.route('/api/admins/add', methods=['POST'])
@login_required
def add_admin():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': 'Username and password are required'}), 400
    
    if Admin.query.filter_by(username=username).first():
        return jsonify({'error': 'Username already exists'}), 409

    new_admin = Admin(username=username)
    new_admin.set_password(password)
    db.session.add(new_admin)
    db.session.commit()
    return jsonify({'message': 'Admin added successfully', 'admin': {'id': new_admin.id, 'username': new_admin.username}}), 201

@app.route('/api/admins/delete', methods=['POST'])
@login_required
def delete_admin():
    data = request.json
    admin_id = data.get('admin_id')
    
    if admin_id == current_user.id:
        return jsonify({'error': 'You cannot delete your own account'}), 403

    if Admin.query.count() <= 1:
        return jsonify({'error': 'Cannot delete the last admin account'}), 403

    admin_to_delete = Admin.query.get(admin_id)
    if not admin_to_delete:
        return jsonify({'error': 'Admin not found'}), 404
        
    db.session.delete(admin_to_delete)
    db.session.commit()
    return jsonify({'message': 'Admin deleted successfully'})

@app.route('/api/admins/update-profile', methods=['POST'])
@login_required
def update_profile():
    new_username = request.form.get('username')
    current_password = request.form.get('current_password')
    new_password = request.form.get('new_password')
    profile_picture = request.files.get('profile_picture')

    if not current_user.check_password(current_password):
        return jsonify({'error': 'Your current password is not correct'}), 403
    
    if new_username and new_username != current_user.username:
        if Admin.query.filter_by(username=new_username).first():
            return jsonify({'error': 'New username is already taken'}), 409
        current_user.username = new_username
    
    if new_password:
        current_user.set_password(new_password)
    
    if profile_picture:
        current_user.profile_picture = _handle_file_upload(profile_picture, current_user.profile_picture)

    db.session.commit()
    return jsonify({'message': 'Profile updated successfully', 'profile_picture': current_user.profile_picture})


# --- Main Execution ---
if __name__ == '__main__':
    with app.app_context():
        os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
        db.create_all()
        
        # Create a default admin user if none exists
        if not Admin.query.first():
            default_admin = Admin(username='admin')
            default_admin.set_password('password') # You should change this password
            db.session.add(default_admin)
            db.session.commit()
            print("Default admin 'admin' with password 'password' created.")

        if Driver.query.filter(Driver.driver_uid == None).first():
            for driver in Driver.query.filter(Driver.driver_uid == None).all(): driver.driver_uid = f"DRV-{driver.id:04d}"
            db.session.commit()
        if not Setting.query.first():
            db.session.add(Setting(key='base_fare', value='25')); db.session.add(Setting(key='per_km_bajaj', value='8')); db.session.add(Setting(key='per_km_car', value='12')); db.session.commit()
    app.run(debug=True)