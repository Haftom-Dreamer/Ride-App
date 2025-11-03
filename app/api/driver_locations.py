"""
Driver Locations API
Get driver location data for map display
"""

from flask import Blueprint, jsonify
from app.models import db, DriverLocation
from app.api import admin_required

driver_locations = Blueprint('driver_locations', __name__, url_prefix='/api')

@driver_locations.route('/driver-locations', methods=['GET'])
@admin_required
def get_driver_locations():
    """Get all driver locations"""
    try:
        locations = DriverLocation.query.all()
        
        # Convert to dictionary keyed by driver_id
        locations_dict = {}
        for loc in locations:
            locations_dict[loc.driver_id] = {
                'lat': float(loc.lat),
                'lon': float(loc.lon),
                'heading': float(loc.heading) if loc.heading else None,
                'updated_at': loc.updated_at.isoformat() if loc.updated_at else None,
            }
        
        return jsonify(locations_dict), 200
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error getting driver locations: {e}")
        return jsonify({'error': str(e)}), 500

