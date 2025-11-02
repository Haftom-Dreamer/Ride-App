"""
SocketIO utility functions for real-time notifications
"""

from app import socketio

def emit_new_ride_notification(ride_data):
    """
    Emit a new ride notification to all connected dispatchers
    
    Args:
        ride_data (dict): Ride information including passenger_name, fare, etc.
    """
    try:
        socketio.emit('new_ride_notification', ride_data, room='dispatchers')
        print(f"✅ Emitted new ride notification: {ride_data.get('passenger_name', 'Unknown')}")
    except Exception as e:
        print(f"❌ Error emitting ride notification: {e}")

def emit_driver_status_change(driver_data):
    """
    Emit driver status change notification
    
    Args:
        driver_data (dict): Driver information including name, status, etc.
    """
    try:
        socketio.emit('driver_status_change', driver_data, room='dispatchers')
        print(f"✅ Emitted driver status change: {driver_data.get('name', 'Unknown')}")
    except Exception as e:
        print(f"❌ Error emitting driver status change: {e}")

def emit_ride_assignment(assignment_data):
    """
    Emit ride assignment notification
    
    Args:
        assignment_data (dict): Assignment information
    """
    try:
        socketio.emit('ride_assigned', assignment_data, room='dispatchers')
        print(f"✅ Emitted ride assignment: {assignment_data.get('ride_id', 'Unknown')}")
    except Exception as e:
        print(f"❌ Error emitting ride assignment: {e}")

def emit_driver_registration_notification(driver_data):
    """
    Emit new driver registration notification to dispatchers
    
    Args:
        driver_data (dict): Driver information including name, phone, etc.
    """
    try:
        socketio.emit('new_driver_registration', driver_data, room='dispatchers')
        print(f"✅ Emitted new driver registration: {driver_data.get('name', 'Unknown')}")
    except Exception as e:
        print(f"❌ Error emitting driver registration notification: {e}")

def emit_passenger_registration_notification(passenger_data):
    """
    Emit new passenger registration notification to dispatchers
    
    Args:
        passenger_data (dict): Passenger information including name, phone, etc.
    """
    try:
        socketio.emit('new_passenger_registration', passenger_data, room='dispatchers')
        print(f"✅ Emitted new passenger registration: {passenger_data.get('username', 'Unknown')}")
    except Exception as e:
        print(f"❌ Error emitting passenger registration notification: {e}")