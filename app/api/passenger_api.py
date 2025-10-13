"""
Passenger-specific API endpoints
"""

from flask import request, jsonify
from flask_login import current_user
from app.api import api, passenger_required
from app.models import db, SupportTicket, SavedPlace, Ride


@api.route('/submit-support-ticket', methods=['POST'])
@passenger_required
def submit_support_ticket():
    """Submit a support ticket"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('feedback_type') or not data.get('details'):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Create support ticket
        ticket = SupportTicket(
            passenger_id=current_user.id,
            ride_id=data.get('ride_id'),
            feedback_type=data['feedback_type'],
            details=data['details'],
            status='Open'
        )
        
        db.session.add(ticket)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Support ticket submitted successfully',
            'ticket_id': ticket.id
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@api.route('/saved-places', methods=['GET'])
@passenger_required
def get_saved_places():
    """Get all saved places for current passenger"""
    try:
        places = SavedPlace.query.filter_by(passenger_id=current_user.id).all()
        
        return jsonify([{
            'id': p.id,
            'label': p.label,
            'address': p.address,
            'latitude': p.latitude,
            'longitude': p.longitude
        } for p in places])
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api.route('/saved-places', methods=['POST'])
@passenger_required
def add_saved_place():
    """Add a new saved place"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required = ['label', 'address', 'latitude', 'longitude']
        if not all(data.get(field) for field in required):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Check if label already exists for this passenger
        existing = SavedPlace.query.filter_by(
            passenger_id=current_user.id,
            label=data['label']
        ).first()
        
        if existing:
            return jsonify({'error': 'A place with this label already exists'}), 400
        
        # Create new saved place
        place = SavedPlace(
            passenger_id=current_user.id,
            label=data['label'],
            address=data['address'],
            latitude=float(data['latitude']),
            longitude=float(data['longitude'])
        )
        
        db.session.add(place)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Place saved successfully',
            'place': {
                'id': place.id,
                'label': place.label,
                'address': place.address,
                'latitude': place.latitude,
                'longitude': place.longitude
            }
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@api.route('/saved-places/<int:place_id>', methods=['DELETE'])
@passenger_required
def delete_saved_place(place_id):
    """Delete a saved place"""
    try:
        place = SavedPlace.query.filter_by(
            id=place_id,
            passenger_id=current_user.id
        ).first()
        
        if not place:
            return jsonify({'error': 'Place not found'}), 404
        
        db.session.delete(place)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Place deleted successfully'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@api.route('/saved-places/<int:place_id>', methods=['PUT'])
@passenger_required
def update_saved_place(place_id):
    """Update a saved place"""
    try:
        place = SavedPlace.query.filter_by(
            id=place_id,
            passenger_id=current_user.id
        ).first()
        
        if not place:
            return jsonify({'error': 'Place not found'}), 404
        
        data = request.get_json()
        
        # Update fields if provided
        if 'label' in data:
            # Check if new label conflicts with existing
            existing = SavedPlace.query.filter(
                SavedPlace.passenger_id == current_user.id,
                SavedPlace.label == data['label'],
                SavedPlace.id != place_id
            ).first()
            
            if existing:
                return jsonify({'error': 'A place with this label already exists'}), 400
            
            place.label = data['label']
        
        if 'address' in data:
            place.address = data['address']
        if 'latitude' in data:
            place.latitude = float(data['latitude'])
        if 'longitude' in data:
            place.longitude = float(data['longitude'])
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Place updated successfully',
            'place': {
                'id': place.id,
                'label': place.label,
                'address': place.address,
                'latitude': place.latitude,
                'longitude': place.longitude
            }
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@api.route('/update-phone-number', methods=['POST'])
@passenger_required
def update_phone_number():
    """Update passenger phone number with verification"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('new_phone_number') or not data.get('current_password'):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Verify current password
        if not current_user.check_password(data['current_password']):
            return jsonify({'error': 'Incorrect password'}), 401
        
        # Format phone number
        new_phone = data['new_phone_number'].strip()
        if not new_phone.startswith('+251'):
            new_phone = '+251' + new_phone.lstrip('+')
        
        # Check if phone number is already in use
        from app.models import Passenger
        existing = Passenger.query.filter_by(phone_number=new_phone).first()
        if existing and existing.id != current_user.id:
            return jsonify({'error': 'Phone number already in use'}), 400
        
        # Update phone number
        current_user.phone_number = new_phone
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Phone number updated successfully',
            'new_phone_number': new_phone
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@api.route('/emergency-sos', methods=['POST'])
@passenger_required
def emergency_sos():
    """Handle emergency SOS requests"""
    try:
        data = request.get_json()
        
        # Get current location
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        ride_id = data.get('ride_id')
        
        # Create an urgent support ticket
        ticket = SupportTicket(
            passenger_id=current_user.id,
            ride_id=ride_id,
            feedback_type='EMERGENCY SOS',
            details=f'Emergency SOS activated. Location: {latitude}, {longitude}. Additional info: {data.get("message", "No additional message")}',
            status='Open'
        )
        
        db.session.add(ticket)
        db.session.commit()
        
        # In a production app, this would:
        # 1. Send SMS to emergency contacts
        # 2. Alert the dispatcher
        # 3. Notify local authorities if configured
        # 4. Track the location in real-time
        
        return jsonify({
            'success': True,
            'message': 'Emergency alert sent. Help is on the way.',
            'ticket_id': ticket.id,
            'emergency_contact': '+251-911',  # Replace with actual emergency number
            'support_contact': '+251-XXX-XXXX-XXX'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

