"""
Database Models
"""

from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

class Admin(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_user.svg')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Passenger(UserMixin, db.Model):
    __tablename__ = 'passenger'
    id = db.Column(db.Integer, primary_key=True)
    passenger_uid = db.Column(db.String(20), unique=True, nullable=True, index=True)
    username = db.Column(db.String(80), nullable=False)
    phone_number = db.Column(db.String(20), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(200), nullable=False)
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_user.svg')
    join_date = db.Column(db.DateTime, server_default=db.func.now())
    is_blocked = db.Column(db.Boolean, default=False, nullable=False, index=True)
    blocked_reason = db.Column(db.String(255), nullable=True)
    blocked_at = db.Column(db.DateTime, nullable=True)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Driver(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    driver_uid = db.Column(db.String(20), unique=True, nullable=True, index=True)  # User-friendly ID
    name = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False, index=True)
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj', index=True)
    vehicle_details = db.Column(db.String(150), nullable=False)
    vehicle_plate_number = db.Column(db.String(50), nullable=True)
    license_info = db.Column(db.String(100), nullable=True)
    status = db.Column(db.String(20), default='Offline', nullable=False, index=True)
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_user.svg')
    license_document = db.Column(db.String(255), nullable=True)
    vehicle_document = db.Column(db.String(255), nullable=True)
    join_date = db.Column(db.DateTime, server_default=db.func.now())
    current_lat = db.Column(db.Float, nullable=True)
    current_lon = db.Column(db.Float, nullable=True)
    is_blocked = db.Column(db.Boolean, default=False, nullable=False, index=True)
    blocked_reason = db.Column(db.String(255), nullable=True)
    blocked_at = db.Column(db.DateTime, nullable=True)

class Ride(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    passenger_id = db.Column(db.Integer, db.ForeignKey('passenger.id'), nullable=False, index=True)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True, index=True)
    pickup_address = db.Column(db.String(255), nullable=True)
    pickup_lat = db.Column(db.Float, nullable=False)
    pickup_lon = db.Column(db.Float, nullable=False)
    dest_address = db.Column(db.String(255), nullable=False)
    dest_lat = db.Column(db.Float, nullable=True)
    dest_lon = db.Column(db.Float, nullable=True)
    distance_km = db.Column(db.Numeric(10, 2), nullable=False)
    fare = db.Column(db.Numeric(10, 2), nullable=False)  # Changed from Float to Numeric for money
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj', index=True)
    status = db.Column(db.String(20), default='Requested', nullable=False, index=True)
    request_time = db.Column(db.DateTime, server_default=db.func.now(), index=True)
    assigned_time = db.Column(db.DateTime, nullable=True)
    note = db.Column(db.String(255), nullable=True)
    payment_method = db.Column(db.String(20), nullable=False, default='Cash')

    passenger = db.relationship('Passenger', backref=db.backref('rides', lazy=True))
    driver = db.relationship('Driver', backref=db.backref('rides', lazy=True))
    feedback = db.relationship('Feedback', backref='ride', uselist=False, cascade="all, delete-orphan")

class Feedback(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('ride.id'), unique=True, nullable=False)
    rating = db.Column(db.Integer, nullable=True)
    comment = db.Column(db.String(500), nullable=True)
    feedback_type = db.Column(db.String(50), nullable=False, default='Rating')
    details = db.Column(db.Text, nullable=True)
    is_resolved = db.Column(db.Boolean, default=False)
    submitted_at = db.Column(db.DateTime, server_default=db.func.now(db.func.timezone(db.func.utc())))

class Setting(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), unique=True, nullable=False)
    value = db.Column(db.String(255), nullable=False)

class SupportTicket(db.Model):
    """Support tickets for passenger inquiries and issues"""
    __tablename__ = 'support_ticket'
    id = db.Column(db.Integer, primary_key=True)
    passenger_id = db.Column(db.Integer, db.ForeignKey('passenger.id'), nullable=False, index=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('ride.id'), nullable=True, index=True)
    feedback_type = db.Column(db.String(50), nullable=False, index=True)  # Lost Item, Ride Complaint, etc.
    details = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), default='Open', nullable=False, index=True)  # Open, In Progress, Resolved, Closed
    admin_response = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now(), index=True)
    updated_at = db.Column(db.DateTime, onupdate=db.func.now())
    
    passenger = db.relationship('Passenger', backref=db.backref('support_tickets', lazy=True))
    ride = db.relationship('Ride', backref=db.backref('support_tickets', lazy=True))

class SavedPlace(db.Model):
    """Saved locations for quick ride booking"""
    __tablename__ = 'saved_place'
    id = db.Column(db.Integer, primary_key=True)
    passenger_id = db.Column(db.Integer, db.ForeignKey('passenger.id'), nullable=False, index=True)
    label = db.Column(db.String(50), nullable=False)  # Home, Work, Gym, etc.
    address = db.Column(db.String(255), nullable=False)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    
    passenger = db.relationship('Passenger', backref=db.backref('saved_places', lazy=True))
    
    # Ensure unique labels per passenger
    __table_args__ = (db.UniqueConstraint('passenger_id', 'label', name='_passenger_label_uc'),)