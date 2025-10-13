"""
Data retrieval and analytics API endpoints
"""

import io
import openpyxl
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.utils import get_column_letter
from reportlab.lib.pagesizes import letter, landscape
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib import colors
from datetime import datetime, timezone, timedelta
from decimal import Decimal

from flask import request, jsonify, current_app
from sqlalchemy import func, case
from app.models import db, Driver, Ride, Passenger, Feedback, Setting, Admin
from app.api import api, admin_required, passenger_required, get_setting
from app.utils import to_eat

# --- Dashboard Stats ---
@api.route('/dashboard-stats')
@admin_required
def get_dashboard_stats():
    """Get dashboard statistics"""
    total_revenue = db.session.query(func.sum(Ride.fare)).filter(Ride.status == 'Completed').scalar() or 0
    total_rides = Ride.query.count()
    drivers_online = Driver.query.filter(Driver.status == 'Available').count()
    pending_requests = Ride.query.filter(Ride.status == 'Requested').count()
    active_rides = Ride.query.filter(Ride.status.in_(['Assigned', 'On Trip'])).count()
    
    return jsonify({
        'total_revenue': round(float(total_revenue), 2),
        'total_rides': total_rides,
        'drivers_online': drivers_online,
        'pending_requests': pending_requests,
        'active_rides': active_rides
    })

# --- Ride Data ---
@api.route('/pending-rides')
@admin_required
def get_pending_rides():
    """Get pending ride requests"""
    rides = Ride.query.filter_by(status='Requested').options(
        db.joinedload(Ride.passenger)
    ).order_by(Ride.request_time.desc()).all()
    
    rides_data = []
    for ride in rides:
        rides_data.append({
            'id': ride.id,
            'user_name': ride.passenger.username,
            'user_phone': ride.passenger.phone_number,
            'pickup_address': ride.pickup_address,
            'pickup_lat': ride.pickup_lat,
            'pickup_lon': ride.pickup_lon,
            'dest_address': ride.dest_address,
            'dest_lat': ride.dest_lat,
            'dest_lon': ride.dest_lon,
            'fare': float(ride.fare),
            'vehicle_type': ride.vehicle_type,
            'note': ride.note,
            'request_time': to_eat(ride.request_time).strftime('%I:%M %p')
        })
    
    return jsonify(rides_data)

@api.route('/active-rides')
@admin_required
def get_active_rides():
    """Get active rides (assigned or in progress)"""
    rides = Ride.query.filter(
        Ride.status.in_(['Assigned', 'On Trip'])
    ).options(
        db.joinedload(Ride.passenger),
        db.joinedload(Ride.driver)
    ).order_by(Ride.request_time.desc()).all()
    
    rides_data = []
    for ride in rides:
        rides_data.append({
            'id': ride.id,
            'user_name': ride.passenger.username,
            'driver_name': ride.driver.name if ride.driver else "N/A",
            'dest_address': ride.dest_address,
            'status': ride.status,
            'request_time': to_eat(ride.request_time).strftime('%Y-%m-%d %H:%M'),
            'pickup_lat': ride.pickup_lat,
            'pickup_lon': ride.pickup_lon,
            'dest_lat': ride.dest_lat,
            'dest_lon': ride.dest_lon
        })
    
    return jsonify(rides_data)

@api.route('/all-rides-data')
@admin_required
def get_all_rides_data():
    """Get all ride data for management"""
    rides = Ride.query.options(
        db.joinedload(Ride.passenger),
        db.joinedload(Ride.driver),
        db.joinedload(Ride.feedback)
    ).order_by(Ride.request_time.desc()).all()
    
    rides_data = []
    for ride in rides:
        rides_data.append({
            'id': ride.id,
            'user_name': ride.passenger.username,
            'user_phone': ride.passenger.phone_number,
            'driver_name': ride.driver.name if ride.driver else "N/A",
            'fare': float(ride.fare),
            'status': ride.status,
            'rating': ride.feedback.rating if ride.feedback else None,
            'request_time': to_eat(ride.request_time).strftime('%Y-%m-%d %H:%M')
        })
    
    return jsonify(rides_data)

@api.route('/ride-details/<int:ride_id>')
@admin_required
def get_ride_details(ride_id):
    """Get detailed information about a specific ride"""
    ride = Ride.query.options(
        db.joinedload(Ride.passenger),
        db.joinedload(Ride.driver),
        db.joinedload(Ride.feedback)
    ).get_or_404(ride_id)

    return jsonify({
        'trip_info': {
            'id': ride.id,
            'status': ride.status,
            'fare': float(ride.fare),
            'distance': float(ride.distance_km),
            'payment_method': ride.payment_method,
            'vehicle_type': ride.vehicle_type,
            'pickup_address': ride.pickup_address,
            'dest_address': ride.dest_address,
            'pickup_coords': {'lat': ride.pickup_lat, 'lon': ride.pickup_lon},
            'dest_coords': {'lat': ride.dest_lat, 'lon': ride.dest_lon},
        },
        'passenger': {
            'name': ride.passenger.username,
            'avatar': ride.passenger.profile_picture,
            'phone': ride.passenger.phone_number
        },
        'driver': {
            'name': ride.driver.name if ride.driver else 'N/A',
            'avatar': ride.driver.profile_picture if ride.driver else 'static/img/default_user.svg',
            'phone': ride.driver.phone_number if ride.driver else 'N/A',
            'vehicle': ride.driver.vehicle_details if ride.driver else 'N/A'
        },
        'timestamps': {
            'requested': to_eat(ride.request_time).strftime('%b %d, %Y at %I:%M %p'),
            'assigned': to_eat(ride.assigned_time).strftime('%I:%M %p') if ride.assigned_time else 'N/A',
        },
        'feedback': {
            'rating': ride.feedback.rating if ride.feedback else None,
            'comment': ride.feedback.comment if ride.feedback else None
        }
    })

# --- Passenger Data ---
@api.route('/passengers')
@admin_required
def get_passengers():
    """Get all passengers"""
    passengers = Passenger.query.options(db.selectinload(Passenger.rides)).all()
    
    passengers_data = []
    for passenger in passengers:
        passengers_data.append({
            "id": passenger.id,
            "username": passenger.username,
            "phone_number": passenger.phone_number,
            "profile_picture": passenger.profile_picture,
            "rides_taken": len(passenger.rides),
            "join_date": passenger.join_date.strftime('%Y-%m-%d') if passenger.join_date else None
        })
    
    return jsonify(passengers_data)

@api.route('/passenger-details/<int:passenger_id>')
@admin_required
def get_passenger_details(passenger_id):
    """Get detailed passenger information"""
    passenger = Passenger.query.get_or_404(passenger_id)

    # Calculate statistics
    total_spent = db.session.query(func.sum(Ride.fare)).filter(
        Ride.passenger_id == passenger_id,
        Ride.status == 'Completed'
    ).scalar() or 0

    avg_rating_given = db.session.query(func.avg(Feedback.rating)).join(Ride).filter(
        Ride.passenger_id == passenger_id,
        Feedback.rating.isnot(None)
    ).scalar() or 0

    stats = {
        'total_rides': len(passenger.rides),
        'total_spent': float(total_spent),
        'avg_rating_given': round(float(avg_rating_given), 2) if avg_rating_given else 0
    }

    # Get ride history
    history = Ride.query.filter_by(passenger_id=passenger_id)\
        .options(db.joinedload(Ride.driver), db.joinedload(Ride.feedback))\
        .order_by(Ride.request_time.desc()).limit(20).all()

    return jsonify({
        'profile': {
            'name': passenger.username,
            'passenger_uid': passenger.passenger_uid,
            'phone_number': passenger.phone_number,
            'avatar': passenger.profile_picture,
            'join_date': passenger.join_date.strftime('%b %d, %Y') if passenger.join_date else None
        },
        'stats': stats,
        'history': [{
            'id': ride.id,
            'status': ride.status,
            'fare': float(ride.fare),
            'date': to_eat(ride.request_time).strftime('%Y-%m-%d %H:%M'),
            'driver_name': ride.driver.name if ride.driver else 'N/A',
            'pickup_address': ride.pickup_address,
            'dest_address': ride.dest_address,
            'rating_given': ride.feedback.rating if ride.feedback and ride.feedback.rating is not None else 'N/A'
        } for ride in history]
    })

@api.route('/passenger/ride-history')
@passenger_required
def api_passenger_history():
    """Get ride history for logged-in passenger"""
    from flask_login import current_user
    
    rides = Ride.query.filter_by(passenger_id=current_user.id)\
        .options(db.joinedload(Ride.feedback), db.joinedload(Ride.driver))\
        .order_by(Ride.request_time.desc()).all()
    
    rides_data = []
    for ride in rides:
        rides_data.append({
            'id': ride.id,
            'driver_name': ride.driver.name if ride.driver else "N/A",
            'dest_address': ride.dest_address,
            'fare': float(ride.fare),
            'status': ride.status,
            'request_time': to_eat(ride.request_time).strftime('%b %d, %Y at %I:%M %p'),
            'rating': ride.feedback.rating if ride.feedback else None,
            'comment': ride.feedback.comment if ride.feedback else None
        })
    
    return jsonify(rides_data)
