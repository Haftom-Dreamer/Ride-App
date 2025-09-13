from flask import Flask, render_template, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import os
import requests
from sqlalchemy import func, case
from datetime import datetime, timedelta
from werkzeug.utils import secure_filename
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
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj')
    vehicle_details = db.Column(db.String(150), nullable=False)
    vehicle_plate_number = db.Column(db.String(50), nullable=True)
    license_info = db.Column(db.String(100), nullable=True)
    status = db.Column(db.String(20), default='Offline', nullable=False)
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_avatar.png')
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
    request_time = db.Column(db.DateTime, server_default=db.func.now())
    assigned_time = db.Column(db.DateTime, nullable=True)
    note = db.Column(db.String(255), nullable=True)
    rating = db.Column(db.Integer, nullable=True)
    comment = db.Column(db.String(500), nullable=True)
    payment_method = db.Column(db.String(20), nullable=False, default='Cash')


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
        payment_method=data.get('payment_method', 'Cash')
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
    ride.assigned_time = datetime.utcnow()
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
def add_driver():
    name = request.form.get('name')
    phone_number = request.form.get('phone_number')
    vehicle_type = request.form.get('vehicle_type')
    vehicle_details = request.form.get('vehicle_details')
    vehicle_plate_number = request.form.get('vehicle_plate_number')
    license_info = request.form.get('license_info')
    
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
        vehicle_type=vehicle_type,
        vehicle_details=vehicle_details,
        vehicle_plate_number=vehicle_plate_number,
        license_info=license_info,
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
    driver.vehicle_type = request.form.get('vehicle_type', driver.vehicle_type)
    driver.vehicle_details = request.form.get('vehicle_details', driver.vehicle_details)
    driver.vehicle_plate_number = request.form.get('vehicle_plate_number', driver.vehicle_plate_number)
    driver.license_info = request.form.get('license_info', driver.license_info)
    
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
            'pickup_address': r.pickup_address,
            'pickup_lat': r.pickup_lat,
            'pickup_lon': r.pickup_lon,
            'dest_address': r.dest_address,
            'dest_lat': r.dest_lat,
            'dest_lon': r.dest_lon,
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
    drivers_data = []
    for d in drivers:
        avg_rating = db.session.query(func.avg(Ride.rating)).filter(Ride.driver_id == d.id, Ride.rating.isnot(None)).scalar() or 0
        drivers_data.append({
            "id": d.id,
            "name": d.name,
            "phone_number": d.phone_number,
            "vehicle_type": d.vehicle_type,
            "vehicle_details": d.vehicle_details,
            "status": d.status,
            "join_date": d.join_date.strftime('%Y-%m-%d'),
            "profile_picture": d.profile_picture,
            "lat": d.current_lat,
            "lon": d.current_lon,
            "avg_rating": avg_rating
        })
    return jsonify(drivers_data)


@app.route('/api/driver/<int:driver_id>')
def get_driver(driver_id):
    driver = Driver.query.get_or_404(driver_id)
    return jsonify({
        "id": driver.id,
        "name": driver.name,
        "phone_number": driver.phone_number,
        "vehicle_type": driver.vehicle_type,
        "vehicle_details": driver.vehicle_details,
        "vehicle_plate_number": driver.vehicle_plate_number,
        "license_info": driver.license_info,
        "profile_picture": driver.profile_picture
    })


@app.route('/api/available-drivers')
def get_available_drivers():
    vehicle_type = request.args.get('vehicle_type')
    query = Driver.query.filter_by(status='Available')
    if vehicle_type:
        query = query.filter_by(vehicle_type=vehicle_type)
    
    drivers = query.all()
    return jsonify([{'id': d.id, 'name': d.name, 'vehicle_type': d.vehicle_type, 'status': d.status} for d in drivers])


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
    
    now = datetime.utcnow()
    week_start = now - timedelta(days=now.weekday())

    avg_assignment_time_seconds = db.session.query(
        func.avg(func.julianday(Ride.assigned_time) - func.julianday(Ride.request_time)) * 86400.0
    ).filter(Ride.driver_id == driver_id, Ride.assigned_time.isnot(None)).scalar() or 0

    stats = {
        'completed_rides': Ride.query.filter_by(driver_id=driver_id, status='Completed').count(),
        'total_earnings': db.session.query(func.sum(Ride.fare)).filter(
            Ride.driver_id == driver_id, 
            Ride.status == 'Completed',
            Ride.request_time >= week_start
        ).scalar() or 0,
        'avg_rating': db.session.query(func.avg(Ride.rating)).filter(Ride.driver_id == driver_id, Ride.rating.isnot(None)).scalar() or 0,
        'avg_assignment_time': f"{avg_assignment_time_seconds:.2f}s"
    }
    history = Ride.query.filter_by(driver_id=driver_id).order_by(Ride.request_time.desc()).limit(10).all()
    return jsonify({
        'profile': {
            'name': driver.name, 'status': driver.status, 'avatar': driver.profile_picture, 'phone_number': driver.phone_number,
            'vehicle_type': driver.vehicle_type, 'vehicle_details': driver.vehicle_details,
            'plate_number': driver.vehicle_plate_number, 'license': driver.license_info
        },
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

def _get_previous_period(start_date, end_date):
    if not start_date or not end_date:
        return None, None
    delta = end_date - start_date
    prev_end_date = start_date - timedelta(microseconds=1)
    prev_start_date = prev_end_date - delta
    return prev_start_date, prev_end_date

def _calculate_kpis_for_period(start, end):
    query = Ride.query
    if start and end:
        query = query.filter(Ride.request_time.between(start, end))
    
    completed_sq = query.filter(Ride.status == 'Completed').subquery()
    
    revenue = db.session.query(func.sum(completed_sq.c.fare)).scalar() or 0
    completed_rides = db.session.query(func.count(completed_sq.c.id)).scalar()
    
    return revenue, completed_rides

def _calculate_trend(current, previous):
    if previous == 0:
        return 100 if current > 0 else 0
    return round(((current - previous) / previous) * 100)
    
def _get_date_range_from_request():
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
    
    return start_date, end_date

@app.route('/api/analytics-data')
def get_analytics_data():
    start_date, end_date = _get_date_range_from_request()
    now = datetime.utcnow()
            
    base_query = Ride.query
    if start_date:
        base_query = base_query.filter(Ride.request_time.between(start_date, end_date))

    completed_rides_sq = base_query.filter(Ride.status == 'Completed').subquery()
    canceled_rides_sq = base_query.filter(Ride.status == 'Canceled').subquery()

    completed_rides_in_period = db.session.query(func.count(completed_rides_sq.c.id)).scalar()
    canceled_rides_in_period = db.session.query(func.count(canceled_rides_sq.c.id)).scalar()
    revenue_in_period = db.session.query(func.sum(completed_rides_sq.c.fare)).scalar() or 0
    avg_fare_in_period = db.session.query(func.avg(completed_rides_sq.c.fare)).scalar() or 0
    active_rides_now = Ride.query.filter(Ride.status.in_(['Assigned', 'On Trip'])).count()

    prev_start_date, prev_end_date = _get_previous_period(start_date, end_date)
    prev_revenue, prev_completed_rides = 0, 0
    if prev_start_date:
        prev_revenue, prev_completed_rides = _calculate_kpis_for_period(prev_start_date, prev_end_date)
    
    revenue_trend = _calculate_trend(revenue_in_period, prev_revenue)
    rides_trend = _calculate_trend(completed_rides_in_period, prev_completed_rides)

    revenue_by_day_query = db.session.query(
        func.date(completed_rides_sq.c.request_time).label('day'),
        func.sum(completed_rides_sq.c.fare)
    ).group_by('day').order_by('day').all()

    vehicle_dist = dict(base_query.with_entities(Ride.vehicle_type, func.count(Ride.id)).group_by(Ride.vehicle_type).all())
    payment_dist = dict(base_query.with_entities(Ride.payment_method, func.count(Ride.id)).group_by(Ride.payment_method).all())
    
    now_week_start = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    top_drivers_query = db.session.query(
        Driver.name,
        Driver.profile_picture,
        func.count(Ride.id).label('completed_rides'),
        func.avg(Ride.rating).label('avg_rating')
    ).join(Ride, Driver.id == Ride.driver_id).filter(
        Ride.status == 'Completed',
        Ride.request_time >= now_week_start
    ).group_by(Driver.id).order_by(
        func.count(Ride.id).desc()
    ).limit(5).all()

    top_drivers = [{
        'name': d.name,
        'avatar': d.profile_picture,
        'completed_rides': d.completed_rides,
        'avg_rating': round(d.avg_rating or 0, 2)
    } for d in top_drivers_query]


    return jsonify({
        'kpis': {
            'rides_completed': completed_rides_in_period,
            'rides_canceled': canceled_rides_in_period,
            'total_revenue': round(revenue_in_period, 2),
            'avg_fare': round(avg_fare_in_period or 0, 2),
            'active_rides_now': active_rides_now,
            'trends': {
                'revenue': revenue_trend,
                'rides': rides_trend
            }
        },
        'charts': {
            'revenue_over_time': {
                'labels': [item[0] for item in revenue_by_day_query],
                'data': [float(item[1]) if item[1] is not None else 0 for item in revenue_by_day_query]
            },
            'vehicle_distribution': vehicle_dist,
            'payment_method_distribution': payment_dist,
        },
        'performance': {
            'top_drivers': top_drivers
        }
    })

@app.route('/api/export-report')
def export_report():
    file_format = request.args.get('format', 'pdf')
    start_date, end_date = _get_date_range_from_request()
    
    base_query = Ride.query.options(db.joinedload(Ride.user), db.joinedload(Ride.driver)).order_by(Ride.request_time.desc())
    if start_date:
        base_query = base_query.filter(Ride.request_time.between(start_date, end_date))

    all_rides_in_period = base_query.all()
    
    analytics_data = get_analytics_data().get_json()
    kpis = analytics_data['kpis']

    report_title = f"Analytics Report ({start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')})" if start_date else "Analytics Report (All Time)"

    if file_format == 'pdf':
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=landscape(letter))
        styles = getSampleStyleSheet()
        elements = [
            Paragraph("Ride App - Dispatcher Analytics", styles['h1']),
            Paragraph(report_title, styles['h2']),
            Spacer(1, 24)
        ]

        kpi_data = [
            ["Metric", "Value", "Trend"],
            ["Rides Completed", f"{kpis['rides_completed']}", f"{kpis['trends']['rides']}%"],
            ["Total Revenue", f"{kpis['total_revenue']} ETB", f"{kpis['trends']['revenue']}%"],
            ["Rides Canceled", kpis['rides_canceled'], ""],
            ["Average Fare", f"{kpis['avg_fare']} ETB", ""],
        ]
        
        kpi_table = Table(kpi_data, colWidths=[200, 150, 100])
        kpi_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#4A5568')),
            ('TEXTCOLOR',(0,0),(-1,0),colors.whitesmoke),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
            ('GRID', (0,0), (-1,-1), 1, colors.black)
        ]))
        elements.append(Paragraph("Key Metrics Summary", styles['h3']))
        elements.append(kpi_table)
        elements.append(Spacer(1, 24))

        elements.append(Paragraph("All Rides in Period", styles['h3']))
        ride_data_for_table = [["ID", "Date", "Passenger", "Driver", "Fare", "Status"]]
        for ride in all_rides_in_period:
            ride_data_for_table.append([
                ride.id,
                ride.request_time.strftime('%Y-%m-%d %H:%M'),
                ride.user.name,
                ride.driver.name if ride.driver else 'N/A',
                f"{ride.fare} ETB",
                ride.status
            ])
        
        ride_table = Table(ride_data_for_table, colWidths=[40, 120, 120, 120, 80, 80])
        ride_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#2D3748')),
            ('TEXTCOLOR',(0,0),(-1,0),colors.whitesmoke),
            ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
            ('GRID', (0,0), (-1,-1), 1, colors.black),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ]))
        elements.append(ride_table)
        
        doc.build(elements)
        buffer.seek(0)
        return buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': 'attachment; filename="analytics_report.pdf"'
        }

    elif file_format == 'excel':
        wb = openpyxl.Workbook()
        
        # Summary Sheet
        ws_summary = wb.active
        ws_summary.title = "Summary Report"
        ws_summary.append([report_title])
        ws_summary['A1'].font = Font(bold=True, size=16)
        ws_summary.append([]) # Spacer
        ws_summary.append(["Key Metrics"])
        ws_summary['A3'].font = Font(bold=True, size=14)

        ws_summary.append(["Metric", "Value"])
        ws_summary.append(["Rides Completed", kpis['rides_completed']])
        ws_summary.append(["Rides Canceled", kpis['rides_canceled']])
        ws_summary.append(["Total Revenue", kpis['total_revenue']])
        ws_summary.append(["Average Fare", kpis['avg_fare']])
        ws_summary['D3'] = "Rides Completed Trend"
        ws_summary['E3'] = f"{kpis['trends']['rides']}%"
        ws_summary['D4'] = "Revenue Trend"
        ws_summary['E4'] = f"{kpis['trends']['revenue']}%"

        # Raw Data Sheet
        ws_raw = wb.create_sheet("Raw Data")
        headers = ["Ride ID", "Request Time", "Status", "Passenger Name", "Passenger Phone", "Driver Name", "Fare", "Vehicle", "Payment", "Rating"]
        ws_raw.append(headers)
        for ride in all_rides_in_period:
            ws_raw.append([
                ride.id, ride.request_time, ride.status, ride.user.name, ride.user.phone_number,
                ride.driver.name if ride.driver else 'N/A', ride.fare, ride.vehicle_type, ride.payment_method, ride.rating
            ])

        for ws in [ws_summary, ws_raw]:
            for col in ws.columns:
                max_length = 0
                column = col[0].column_letter
                for cell in col:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = (max_length + 2)
                ws.column_dimensions[column].width = adjusted_width

        buffer = io.BytesIO()
        wb.save(buffer)
        buffer.seek(0)
        return buffer.getvalue(), 200, {
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition': 'attachment; filename="analytics_report.xlsx"'
        }

    return jsonify({"error": "Invalid format"}), 400

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
