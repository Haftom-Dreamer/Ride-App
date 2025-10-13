"""
Service/Repository Layer for Database Operations
This module abstracts database logic away from API routes and provides
a clean interface for data access operations.
"""

from sqlalchemy import func, case, and_, or_
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional, List, Dict, Any, Tuple


class BaseService:
    """Base service class with common database operations"""
    
    def __init__(self, db, model):
        self.db = db
        self.model = model
    
    def get_by_id(self, id: int):
        """Get a record by ID"""
        return self.model.query.get(id)
    
    def get_all(self, **filters):
        """Get all records with optional filters"""
        query = self.model.query
        if filters:
            query = query.filter_by(**filters)
        return query.all()
    
    def create(self, **data):
        """Create a new record"""
        obj = self.model(**data)
        self.db.session.add(obj)
        return obj
    
    def update(self, obj, **data):
        """Update an existing record"""
        for key, value in data.items():
            setattr(obj, key, value)
        return obj
    
    def delete(self, obj):
        """Delete a record"""
        self.db.session.delete(obj)
    
    def commit(self):
        """Commit the current transaction"""
        self.db.session.commit()
    
    def rollback(self):
        """Rollback the current transaction"""
        self.db.session.rollback()


class PassengerService(BaseService):
    """Service for Passenger-related database operations"""
    
    def __init__(self, db, Passenger):
        super().__init__(db, Passenger)
    
    def get_by_phone(self, phone_number: str):
        """Get passenger by phone number"""
        return self.model.query.filter_by(phone_number=phone_number).first()
    
    def get_by_username(self, username: str):
        """Get passenger by username"""
        return self.model.query.filter_by(username=username).first()
    
    def create_passenger(self, username: str, phone_number: str, password_hash: str, 
                        profile_picture: str = 'static/img/default_avatar.png'):
        """Create a new passenger"""
        return self.create(
            username=username,
            phone_number=phone_number,
            password_hash=password_hash,
            profile_picture=profile_picture
        )
    
    def update_profile(self, passenger, username: str = None, 
                      profile_picture: str = None, new_password_hash: str = None):
        """Update passenger profile"""
        data = {}
        if username:
            data['username'] = username
        if profile_picture:
            data['profile_picture'] = profile_picture
        if new_password_hash:
            data['password_hash'] = new_password_hash
        return self.update(passenger, **data)


class DriverService(BaseService):
    """Service for Driver-related database operations"""
    
    def __init__(self, db, Driver):
        super().__init__(db, Driver)
    
    def get_by_name(self, name: str):
        """Get driver by name"""
        return self.model.query.filter_by(name=name).first()
    
    def get_by_phone(self, phone_number: str):
        """Get driver by phone number"""
        return self.model.query.filter_by(phone_number=phone_number).first()
    
    def get_available_drivers(self, vehicle_type: str = None):
        """Get all available drivers, optionally filtered by vehicle type"""
        query = self.model.query.filter_by(status='Available')
        if vehicle_type:
            query = query.filter_by(vehicle_type=vehicle_type)
        return query.all()
    
    def create_driver(self, name: str, phone_number: str, vehicle_type: str, 
                     plate_number: str, status: str = 'Available'):
        """Create a new driver"""
        return self.create(
            name=name,
            phone_number=phone_number,
            vehicle_type=vehicle_type,
            plate_number=plate_number,
            status=status
        )
    
    def update_driver_status(self, driver, status: str):
        """Update driver status"""
        return self.update(driver, status=status)


class RideService(BaseService):
    """Service for Ride-related database operations"""
    
    def __init__(self, db, Ride):
        super().__init__(db, Ride)
    
    def get_passenger_rides(self, passenger_id: int, status: str = None):
        """Get all rides for a passenger, optionally filtered by status"""
        query = self.model.query.filter_by(passenger_id=passenger_id)
        if status:
            query = query.filter_by(status=status)
        return query.order_by(self.model.request_time.desc()).all()
    
    def get_driver_rides(self, driver_id: int, status: str = None):
        """Get all rides for a driver, optionally filtered by status"""
        query = self.model.query.filter_by(driver_id=driver_id)
        if status:
            query = query.filter_by(status=status)
        return query.order_by(self.model.request_time.desc()).all()
    
    def get_recent_rides(self, limit: int = 10):
        """Get recent rides"""
        return self.model.query.order_by(self.model.request_time.desc()).limit(limit).all()
    
    def get_pending_rides(self):
        """Get all pending (Requested) rides"""
        return self.model.query.filter_by(status='Requested').order_by(self.model.request_time).all()
    
    def get_active_rides(self):
        """Get all active rides (Assigned, In Progress)"""
        return self.model.query.filter(
            self.model.status.in_(['Assigned', 'In Progress'])
        ).order_by(self.model.request_time.desc()).all()
    
    def create_ride(self, passenger_id: int, pickup_address: str, pickup_lat: float,
                   pickup_lon: float, dest_address: str, dest_lat: float, dest_lon: float,
                   distance_km: Decimal, fare: Decimal, vehicle_type: str,
                   payment_method: str = 'Cash', note: str = None):
        """Create a new ride request"""
        return self.create(
            passenger_id=passenger_id,
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
            note=note,
            status='Requested'
        )
    
    def assign_driver(self, ride, driver_id: int):
        """Assign a driver to a ride"""
        return self.update(
            ride,
            driver_id=driver_id,
            status='Assigned',
            assigned_time=datetime.now(timezone.utc)
        )
    
    def update_ride_status(self, ride, status: str):
        """Update ride status"""
        return self.update(ride, status=status)
    
    def cancel_ride(self, ride):
        """Cancel a ride and clear driver assignment"""
        return self.update(ride, status='Cancelled', driver_id=None)
    
    def get_rides_by_date_range(self, start_date: datetime, end_date: datetime):
        """Get rides within a date range"""
        return self.model.query.filter(
            and_(
                self.model.request_time >= start_date,
                self.model.request_time <= end_date
            )
        ).order_by(self.model.request_time.desc()).all()
    
    def get_revenue_stats(self, start_date: datetime = None, end_date: datetime = None):
        """Calculate revenue statistics"""
        query = self.model.query.filter_by(status='Completed')
        
        if start_date:
            query = query.filter(self.model.request_time >= start_date)
        if end_date:
            query = query.filter(self.model.request_time <= end_date)
        
        total_revenue = query.with_entities(
            func.sum(self.model.fare)
        ).scalar() or Decimal('0.0')
        
        ride_count = query.count()
        
        return {
            'total_revenue': float(total_revenue),
            'ride_count': ride_count,
            'average_fare': float(total_revenue / ride_count) if ride_count > 0 else 0.0
        }


class FeedbackService(BaseService):
    """Service for Feedback-related database operations"""
    
    def __init__(self, db, Feedback):
        super().__init__(db, Feedback)
    
    def get_by_ride_id(self, ride_id: int):
        """Get feedback by ride ID"""
        return self.model.query.filter_by(ride_id=ride_id).first()
    
    def get_unresolved_feedback(self):
        """Get all unresolved feedback"""
        return self.model.query.filter_by(is_resolved=False).order_by(
            self.model.submitted_at.desc()
        ).all()
    
    def create_or_update_feedback(self, ride_id: int, feedback_type: str = None,
                                  rating: int = None, comment: str = None,
                                  details: str = None, is_resolved: bool = False):
        """Create new feedback or update existing feedback for a ride"""
        feedback = self.get_by_ride_id(ride_id)
        
        if feedback:
            # Update existing feedback
            update_data = {}
            if feedback_type:
                # Append new feedback type
                update_data['feedback_type'] = f"{feedback.feedback_type}/{feedback_type}"
            if rating is not None:
                update_data['rating'] = rating
            if comment is not None:
                update_data['comment'] = comment
            if details is not None:
                # Append new details to existing
                existing = feedback.details or feedback.comment or ''
                update_data['details'] = f"{details}\n\nPrevious: {existing}"
            if is_resolved is not None:
                update_data['is_resolved'] = is_resolved
            
            return self.update(feedback, **update_data)
        else:
            # Create new feedback
            return self.create(
                ride_id=ride_id,
                feedback_type=feedback_type or 'General',
                rating=rating,
                comment=comment,
                details=details,
                is_resolved=is_resolved
            )
    
    def mark_as_resolved(self, feedback):
        """Mark feedback as resolved"""
        return self.update(feedback, is_resolved=True)
    
    def get_average_rating(self):
        """Get average rating from all feedback"""
        avg = self.model.query.filter(
            self.model.rating.isnot(None)
        ).with_entities(func.avg(self.model.rating)).scalar()
        return float(avg) if avg else 0.0


class SettingService(BaseService):
    """Service for Setting-related database operations"""
    
    def __init__(self, db, Setting):
        super().__init__(db, Setting)
    
    def get_setting(self, key: str, default=None):
        """Get a setting by key"""
        setting = self.model.query.filter_by(key=key).first()
        return setting.value if setting else default
    
    def set_setting(self, key: str, value: str):
        """Set a setting value (create or update)"""
        setting = self.model.query.filter_by(key=key).first()
        if setting:
            return self.update(setting, value=value)
        else:
            return self.create(key=key, value=value)
    
    def get_fare_settings(self):
        """Get all fare-related settings"""
        base_fare = self.get_setting('base_fare', '20.0')
        per_km = self.get_setting('per_km', '10.0')
        
        return {
            'base_fare': Decimal(base_fare),
            'per_km': Decimal(per_km)
        }
    
    def calculate_fare(self, distance_km: float) -> Decimal:
        """Calculate fare based on distance and current settings"""
        settings = self.get_fare_settings()
        base_fare = settings['base_fare']
        per_km = settings['per_km']
        
        distance = Decimal(str(distance_km))
        fare = base_fare + (per_km * distance)
        return fare.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


class AdminService(BaseService):
    """Service for Admin-related database operations"""
    
    def __init__(self, db, Admin):
        super().__init__(db, Admin)
    
    def get_by_username(self, username: str):
        """Get admin by username"""
        return self.model.query.filter_by(username=username).first()
    
    def create_admin(self, username: str, password_hash: str, role: str = 'admin'):
        """Create a new admin user"""
        return self.create(
            username=username,
            password_hash=password_hash,
            role=role
        )
    
    def update_password(self, admin, new_password_hash: str):
        """Update admin password"""
        return self.update(admin, password_hash=new_password_hash)


class AnalyticsService:
    """Service for analytics and reporting operations"""
    
    def __init__(self, db, Ride, Driver, Passenger, Feedback):
        self.db = db
        self.Ride = Ride
        self.Driver = Driver
        self.Passenger = Passenger
        self.Feedback = Feedback
    
    def get_dashboard_stats(self):
        """Get statistics for the dispatcher dashboard"""
        total_rides = self.Ride.query.count()
        completed_rides = self.Ride.query.filter_by(status='Completed').count()
        active_rides = self.Ride.query.filter(
            self.Ride.status.in_(['Assigned', 'In Progress'])
        ).count()
        pending_rides = self.Ride.query.filter_by(status='Requested').count()
        
        total_drivers = self.Driver.query.count()
        available_drivers = self.Driver.query.filter_by(status='Available').count()
        
        total_passengers = self.Passenger.query.count()
        
        # Calculate today's revenue
        today = datetime.now(timezone.utc).date()
        today_start = datetime.combine(today, datetime.min.time()).replace(tzinfo=timezone.utc)
        today_end = datetime.combine(today, datetime.max.time()).replace(tzinfo=timezone.utc)
        
        today_revenue = self.Ride.query.filter(
            and_(
                self.Ride.status == 'Completed',
                self.Ride.request_time >= today_start,
                self.Ride.request_time <= today_end
            )
        ).with_entities(func.sum(self.Ride.fare)).scalar() or Decimal('0.0')
        
        # Average rating
        avg_rating = self.Feedback.query.filter(
            self.Feedback.rating.isnot(None)
        ).with_entities(func.avg(self.Feedback.rating)).scalar() or 0.0
        
        return {
            'total_rides': total_rides,
            'completed_rides': completed_rides,
            'active_rides': active_rides,
            'pending_rides': pending_rides,
            'total_drivers': total_drivers,
            'available_drivers': available_drivers,
            'total_passengers': total_passengers,
            'today_revenue': float(today_revenue),
            'average_rating': float(avg_rating)
        }
    
    def get_rides_by_vehicle_type(self, start_date: datetime = None, end_date: datetime = None):
        """Get ride counts grouped by vehicle type"""
        query = self.Ride.query
        
        if start_date:
            query = query.filter(self.Ride.request_time >= start_date)
        if end_date:
            query = query.filter(self.Ride.request_time <= end_date)
        
        results = query.with_entities(
            self.Ride.vehicle_type,
            func.count(self.Ride.id).label('count')
        ).group_by(self.Ride.vehicle_type).all()
        
        return {row.vehicle_type: row.count for row in results}
    
    def get_driver_performance(self, driver_id: int):
        """Get performance metrics for a specific driver"""
        rides = self.Ride.query.filter_by(driver_id=driver_id)
        
        total_rides = rides.count()
        completed_rides = rides.filter_by(status='Completed').count()
        
        total_earnings = rides.filter_by(status='Completed').with_entities(
            func.sum(self.Ride.fare)
        ).scalar() or Decimal('0.0')
        
        return {
            'total_rides': total_rides,
            'completed_rides': completed_rides,
            'total_earnings': float(total_earnings),
            'completion_rate': (completed_rides / total_rides * 100) if total_rides > 0 else 0.0
        }

