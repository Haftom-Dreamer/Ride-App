"""
Driver assignment service: nearby search, broadcast offers, atomic accept
"""

from datetime import datetime, timedelta
from sqlalchemy import and_
from app.models import db, DriverLocation, Driver, Ride, RideOffer
from app.realtime.socket import emit_ride_offer


def haversine_km(lat1, lon1, lat2, lon2):
    from math import radians, sin, cos, asin, sqrt
    R = 6371.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    c = 2 * asin(sqrt(a))
    return R * c


def find_nearby_drivers(lat: float, lon: float, radius_km: float = 5.0, limit: int = 5):
    """Return top-N nearby online drivers from DriverLocation and Driver.status"""
    # Simple approach: fetch recent locations and filter in Python by distance
    # For production, move to geospatial index or query
    q = db.session.query(DriverLocation, Driver).join(Driver, Driver.id == DriverLocation.driver_id)
    q = q.filter(Driver.status == 'Online')
    candidates = []
    for loc, driver in q.all():
        dist = haversine_km(lat, lon, loc.lat, loc.lon)
        if dist <= radius_km:
            candidates.append((dist, driver))
    candidates.sort(key=lambda x: x[0])
    return [drv for _, drv in candidates[:limit]]


def broadcast_offers(ride: Ride, radius_km: float = 5.0, limit: int = 5, ttl_seconds: int = 25):
    """Create RideOffer rows and emit offers to drivers"""
    expires_at = datetime.utcnow() + timedelta(seconds=ttl_seconds)
    drivers = find_nearby_drivers(ride.pickup_lat, ride.pickup_lon, radius_km, limit)
    for d in drivers:
        offer = RideOffer(ride_id=ride.id, driver_id=d.id, status='pending', expires_at=expires_at)
        db.session.add(offer)
    db.session.commit()
    # Emit to each driver
    for d in drivers:
        emit_ride_offer(d.id, {
            'ride_id': ride.id,
            'pickup_address': ride.pickup_address,
            'pickup_lat': float(ride.pickup_lat),
            'pickup_lon': float(ride.pickup_lon),
            'dest_address': ride.dest_address,
            'dest_lat': float(ride.dest_lat or 0),
            'dest_lon': float(ride.dest_lon or 0),
            'fare': float(ride.fare),
            'vehicle_type': ride.vehicle_type,
            'expires_at': expires_at.isoformat(),
        })


def accept_offer(ride_id: int, driver_id: int) -> bool:
    """Atomic accept: assign ride if still unassigned and mark offers"""
    # Step 1: ensure ride exists and is assignable
    ride: Ride = Ride.query.filter(Ride.id == ride_id).with_for_update().first()
    if not ride or ride.status not in ['Requested', 'pending_offer'] or (ride.driver_id is not None):
        return False
    # Step 2: set driver and status
    ride.driver_id = driver_id
    ride.status = 'Assigned'
    ride.assigned_time = datetime.utcnow()
    # Step 3: mark offers
    offer = RideOffer.query.filter_by(ride_id=ride_id, driver_id=driver_id).first()
    if offer:
        offer.status = 'accepted'
        offer.accepted_at = datetime.utcnow()
    # Expire others
    RideOffer.query.filter(and_(RideOffer.ride_id == ride_id, RideOffer.driver_id != driver_id)).update({
        RideOffer.status: 'expired'
    })
    db.session.commit()
    return True




