"""
Dispatcher Messaging API
Allows dispatchers to message drivers and passengers
"""

from flask import Blueprint, request, jsonify
from datetime import datetime, timezone
from app.models import db, DispatcherMessage, Driver, Passenger, Ride
from app.api import admin_required

dispatcher_messaging = Blueprint('dispatcher_messaging', __name__, url_prefix='/api/dispatcher')

@dispatcher_messaging.route('/send-to-driver/<int:driver_id>', methods=['POST'])
@admin_required
def send_to_driver(driver_id):
    """Send message from dispatcher to a driver"""
    from flask_login import current_user
    
    data = request.get_json() or {}
    message = (data.get('message') or '').strip()
    
    if not message:
        return jsonify({'error': 'Message is required'}), 400
    
    driver = Driver.query.get(driver_id)
    if not driver:
        return jsonify({'error': 'Driver not found'}), 404
    
    try:
        msg = DispatcherMessage(
            recipient_type='driver',
            recipient_id=driver.id,
            sender_type='admin',
            sender_id=current_user.id,
            sender_admin_id=current_user.id,
            message=message,
        )
        db.session.add(msg)
        db.session.commit()
        
        # Send push notification
        try:
            from app.services.push import send_push_to_user
            send_push_to_user(
                'driver',
                driver.id,
                'Message from Dispatcher',
                message,
                {
                    'type': 'dispatcher_message',
                    'message_id': msg.id,
                }
            )
        except Exception as e:
            from flask import current_app
            current_app.logger.error(f"Failed to send push notification: {e}")
        
        return jsonify({
            'id': msg.id,
            'message': msg.message,
            'created_at': msg.created_at.isoformat() if msg.created_at else None,
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@dispatcher_messaging.route('/send-to-passenger/<int:passenger_id>', methods=['POST'])
@admin_required
def send_to_passenger(passenger_id):
    """Send message from dispatcher to a passenger"""
    from flask_login import current_user
    
    data = request.get_json() or {}
    message = (data.get('message') or '').strip()
    
    if not message:
        return jsonify({'error': 'Message is required'}), 400
    
    passenger = Passenger.query.get(passenger_id)
    if not passenger:
        return jsonify({'error': 'Passenger not found'}), 404
    
    try:
        msg = DispatcherMessage(
            recipient_type='passenger',
            recipient_id=passenger.id,
            sender_type='admin',
            sender_id=current_user.id,
            sender_admin_id=current_user.id,
            message=message,
        )
        db.session.add(msg)
        db.session.commit()
        
        # Send push notification
        try:
            from app.services.push import send_push_to_user
            send_push_to_user(
                'passenger',
                passenger.id,
                'Message from Dispatcher',
                message,
                {
                    'type': 'dispatcher_message',
                    'message_id': msg.id,
                }
            )
        except Exception as e:
            from flask import current_app
            current_app.logger.error(f"Failed to send push notification: {e}")
        
        return jsonify({
            'id': msg.id,
            'message': msg.message,
            'created_at': msg.created_at.isoformat() if msg.created_at else None,
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@dispatcher_messaging.route('/get-messages/<string:recipient_type>/<int:recipient_id>', methods=['GET'])
@admin_required
def get_messages(recipient_type, recipient_id):
    """Get conversation history between dispatcher and driver/passenger (two-way)"""
    from flask_login import current_user
    
    # Get messages TO recipient from dispatcher
    from_dispatcher = DispatcherMessage.query.filter(
        (DispatcherMessage.recipient_type == recipient_type) &
        (DispatcherMessage.recipient_id == recipient_id) &
        (DispatcherMessage.sender_type == 'admin')
    ).all()
    
    # Get messages FROM recipient to dispatcher
    to_dispatcher = DispatcherMessage.query.filter(
        (DispatcherMessage.recipient_type == 'dispatcher') &
        (DispatcherMessage.recipient_id == 0) &
        (DispatcherMessage.sender_type == recipient_type) &
        (DispatcherMessage.sender_id == recipient_id)
    ).all()
    
    # Combine and sort by created_at
    from datetime import datetime, timezone
    all_messages = from_dispatcher + to_dispatcher
    all_messages.sort(key=lambda m: m.created_at if m.created_at else datetime.min.replace(tzinfo=timezone.utc))
    
    messages_data = []
    for m in all_messages:
        sender_name = 'Dispatcher'
        is_from_recipient = m.sender_type == recipient_type and m.sender_id == recipient_id
        
        if not is_from_recipient:
            if m.sender_admin:
                sender_name = m.sender_admin.username
        else:
            # Get sender name based on type
            if recipient_type == 'driver':
                from app.models import Driver
                sender_driver = Driver.query.get(recipient_id)
                sender_name = sender_driver.name if sender_driver else f'Driver {recipient_id}'
            else:
                from app.models import Passenger
                sender_passenger = Passenger.query.get(recipient_id)
                sender_name = sender_passenger.username if sender_passenger else f'Passenger {recipient_id}'
        
        messages_data.append({
            'id': m.id,
            'sender_admin_id': m.sender_admin_id,
            'sender_type': m.sender_type,
            'sender_name': sender_name,
            'message': m.message,
            'is_read': m.is_read,
            'created_at': m.created_at.isoformat() if m.created_at else None,
            'is_from_recipient': is_from_recipient,
        })
    
    return jsonify(messages_data), 200

@dispatcher_messaging.route('/mark-read/<int:message_id>', methods=['POST'])
@admin_required
def mark_read(message_id):
    """Mark a message as read"""
    msg = DispatcherMessage.query.get(message_id)
    if not msg:
        return jsonify({'error': 'Message not found'}), 404
    
    msg.is_read = True
    db.session.commit()
    return jsonify({'success': True}), 200

