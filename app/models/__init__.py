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
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
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
    password_hash = db.Column(db.String(255), nullable=True)  # For driver authentication
    email = db.Column(db.String(120), nullable=True, index=True)
    vehicle_type = db.Column(db.String(50), nullable=False, default='Bajaj', index=True)
    vehicle_details = db.Column(db.String(150), nullable=False)
    vehicle_plate_number = db.Column(db.String(50), nullable=True)
    license_info = db.Column(db.String(100), nullable=True)
    status = db.Column(db.String(20), default='Pending', nullable=False, index=True)  # Pending, Offline, Available, On Trip
    profile_picture = db.Column(db.String(255), nullable=True, default='static/img/default_user.svg')
    license_document = db.Column(db.String(255), nullable=True)  # License photo/document
    vehicle_document = db.Column(db.String(255), nullable=True)  # Vehicle registration
    plate_photo = db.Column(db.String(255), nullable=True)  # Plate photo
    id_document = db.Column(db.String(255), nullable=True)  # ID card photo
    join_date = db.Column(db.DateTime, server_default=db.func.now())
    current_lat = db.Column(db.Float, nullable=True)
    current_lon = db.Column(db.Float, nullable=True)
    is_blocked = db.Column(db.Boolean, default=False, nullable=False, index=True)
    blocked_reason = db.Column(db.String(255), nullable=True)
    blocked_at = db.Column(db.DateTime, nullable=True)
    
    def check_password(self, password):
        """Check if provided password matches"""
        if not self.password_hash:
            return False
        from werkzeug.security import check_password_hash
        return check_password_hash(self.password_hash, password)

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
    start_time = db.Column(db.DateTime, nullable=True)  # When driver starts the trip
    end_time = db.Column(db.DateTime, nullable=True)  # When trip is completed
    note = db.Column(db.String(255), nullable=True)
    payment_method = db.Column(db.String(20), nullable=False, default='Cash')
    rating = db.Column(db.Integer, nullable=True)  # Passenger rating (1-5)
    feedback = db.Column(db.String(500), nullable=True)  # Passenger feedback text

    passenger = db.relationship('Passenger', backref=db.backref('rides', lazy=True))
    driver = db.relationship('Driver', backref=db.backref('rides', lazy=True))

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

class DriverEarnings(db.Model):
    """Driver earnings tracking for completed rides"""
    __tablename__ = 'driver_earnings'
    id = db.Column(db.Integer, primary_key=True)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=False, index=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('ride.id'), nullable=False, index=True)
    gross_fare = db.Column(db.Numeric(10, 2), nullable=False)  # Total fare from ride
    commission_rate = db.Column(db.Numeric(5, 2), nullable=False)  # Commission percentage (e.g., 20.00 for 20%)
    commission_amount = db.Column(db.Numeric(10, 2), nullable=False)  # Amount taken as commission
    driver_earnings = db.Column(db.Numeric(10, 2), nullable=False)  # Amount driver receives
    payment_status = db.Column(db.String(20), default='Pending', nullable=False, index=True)  # Pending, Paid, Disputed
    payment_date = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now(), index=True)
    
    driver = db.relationship('Driver', backref=db.backref('earnings', lazy=True))
    ride = db.relationship('Ride', backref=db.backref('driver_earnings', lazy=True))

class Commission(db.Model):
    """Commission settings and rates"""
    __tablename__ = 'commission'
    id = db.Column(db.Integer, primary_key=True)
    vehicle_type = db.Column(db.String(50), nullable=False, index=True)  # Bajaj, Car
    commission_rate = db.Column(db.Numeric(5, 2), nullable=False)  # Commission percentage
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    effective_date = db.Column(db.DateTime, server_default=db.func.now(), nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, onupdate=db.func.now())
    
    # Ensure one active commission rate per vehicle type
    __table_args__ = (db.UniqueConstraint('vehicle_type', 'effective_date', name='_vehicle_commission_uc'),)

class Vehicle(db.Model):
    """Optional vehicle registry separate from Driver fields"""
    __tablename__ = 'vehicle'
    id = db.Column(db.Integer, primary_key=True)
    make_model = db.Column(db.String(100), nullable=False)
    plate_no = db.Column(db.String(50), nullable=False, index=True)
    color = db.Column(db.String(50), nullable=True)
    capacity = db.Column(db.Integer, nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

class DriverLocation(db.Model):
    """Latest known location per driver for nearby search and assignment"""
    __tablename__ = 'driver_location'
    id = db.Column(db.Integer, primary_key=True)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=False, index=True)
    lat = db.Column(db.Float, nullable=False)
    lon = db.Column(db.Float, nullable=False)
    heading = db.Column(db.Float, nullable=True)
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now(), index=True)

    driver = db.relationship('Driver', backref=db.backref('location', uselist=False))

class RideOffer(db.Model):
    """Broadcast offers to drivers; first acceptance wins"""
    __tablename__ = 'ride_offer'
    id = db.Column(db.Integer, primary_key=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('ride.id'), nullable=False, index=True)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=False, index=True)
    status = db.Column(db.String(20), nullable=False, default='pending', index=True)  # pending, accepted, expired
    created_at = db.Column(db.DateTime, server_default=db.func.now(), index=True)
    expires_at = db.Column(db.DateTime, nullable=True, index=True)
    accepted_at = db.Column(db.DateTime, nullable=True)

    __table_args__ = (db.UniqueConstraint('ride_id', 'driver_id', name='_ride_driver_offer_uc'),)

    ride = db.relationship('Ride', backref=db.backref('offers', lazy=True))
    driver = db.relationship('Driver', backref=db.backref('offers', lazy=True))

class ChatMessage(db.Model):
    """Per-ride chat between passenger and driver"""
    __tablename__ = 'chat_message'
    id = db.Column(db.Integer, primary_key=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('ride.id'), nullable=False, index=True)
    sender_role = db.Column(db.String(20), nullable=False, index=True)  # passenger or driver
    sender_id = db.Column(db.Integer, nullable=False, index=True)
    message = db.Column(db.Text, nullable=False)
    attachment_url = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now(), index=True)
    is_read = db.Column(db.Boolean, default=False, nullable=False, index=True)

    ride = db.relationship('Ride', backref=db.backref('chat_messages', lazy=True))

class DeviceToken(db.Model):
    """Push notification device tokens per user"""
    __tablename__ = 'device_token'
    id = db.Column(db.Integer, primary_key=True)
    user_type = db.Column(db.String(20), nullable=False, index=True)  # passenger, driver, admin
    user_id = db.Column(db.Integer, nullable=False, index=True)
    fcm_token = db.Column(db.String(255), unique=True, nullable=False)
    platform = db.Column(db.String(20), nullable=True)  # android, ios, web
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, onupdate=db.func.now())

class EmailVerification(db.Model):
    """Email verification codes for passenger signup"""
    __tablename__ = 'email_verification'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), nullable=False, index=True)
    verification_code = db.Column(db.String(6), nullable=False)  # 6-digit code
    is_verified = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now(), index=True)
    expires_at = db.Column(db.DateTime, nullable=False, index=True)
    
    def is_expired(self):
        from datetime import datetime
        return datetime.utcnow() > self.expires_at

class EmergencyAlert(db.Model):
    """Emergency SOS alerts from passengers"""
    __tablename__ = 'emergency_alert'
    id = db.Column(db.Integer, primary_key=True)
    passenger_id = db.Column(db.Integer, db.ForeignKey('passenger.id'), nullable=False, index=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('ride.id'), nullable=True, index=True)
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    message = db.Column(db.String(500), nullable=True)
    alert_time = db.Column(db.DateTime, server_default=db.func.now(), index=True)
    is_resolved = db.Column(db.Boolean, default=False, nullable=False)
    resolved_at = db.Column(db.DateTime, nullable=True)
    
    passenger = db.relationship('Passenger', backref=db.backref('emergency_alerts', lazy=True))
    ride = db.relationship('Ride', backref=db.backref('emergency_alerts', lazy=True))

class PasswordReset(db.Model):
    """Password reset codes for passengers"""
    __tablename__ = 'password_resets'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), nullable=False, index=True)
    reset_code = db.Column(db.String(10), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False, index=True)
    is_used = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    
    def is_expired(self):
        from datetime import datetime
        return datetime.utcnow() > self.expires_at