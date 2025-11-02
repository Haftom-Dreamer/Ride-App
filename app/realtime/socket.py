"""
Realtime Socket handlers and helpers
"""

from flask import request
from flask_socketio import emit, join_room, leave_room
from app import socketio
from app.models import db, ChatMessage
from app.services.assigner import accept_offer


@socketio.on('join_dispatcher_room')
def handle_join_dispatcher_room():
    """Dispatcher joins dispatchers room to receive notifications"""
    join_room('dispatchers')
    emit('joined_room', {'room': 'dispatchers'})
    print(f"✅ Dispatcher joined dispatchers room")


@socketio.on('driver_join')
def handle_driver_join(data):
    """Driver joins personal room to receive offers and updates"""
    try:
        driver_id = int(data.get('driver_id'))
    except Exception:
        emit('error', {'error': 'driver_id required'})
        return
    join_room(f'driver:{driver_id}')
    emit('joined', {'room': f'driver:{driver_id}'})


@socketio.on('join_ride_room')
def handle_join_ride_room(data):
    try:
        ride_id = int(data.get('ride_id'))
    except Exception:
        emit('error', {'error': 'ride_id required'})
        return
    join_room(f'ride:{ride_id}')
    emit('joined', {'room': f'ride:{ride_id}'})


@socketio.on('leave_ride_room')
def handle_leave_ride_room(data):
    try:
        ride_id = int(data.get('ride_id'))
    except Exception:
        emit('error', {'error': 'ride_id required'})
        return
    leave_room(f'ride:{ride_id}')
    emit('left', {'room': f'ride:{ride_id}'})


@socketio.on('chat_message')
def handle_chat_message(data):
    """Persist and broadcast chat messages in a ride room"""
    try:
        ride_id = int(data.get('ride_id'))
        sender_role = str(data.get('sender_role') or 'passenger')
        sender_id = int(data.get('sender_id'))
        message = (data.get('message') or '').strip()
        if not message:
            emit('error', {'error': 'message is required'})
            return
        chat = ChatMessage(
            ride_id=ride_id,
            sender_role=sender_role,
            sender_id=sender_id,
            message=message,
        )
        db.session.add(chat)
        db.session.commit()
        payload = {
            'id': chat.id,
            'ride_id': chat.ride_id,
            'sender_role': chat.sender_role,
            'sender_id': chat.sender_id,
            'message': chat.message,
            'created_at': chat.created_at.isoformat() if chat.created_at else None,
        }
        emit('chat_message', payload, room=f'ride:{ride_id}')
    except Exception as e:
        db.session.rollback()
        emit('error', {'error': str(e)})


def emit_ride_offer(driver_id: int, offer: dict):
    """Helper: emit a ride offer to a specific driver room"""
    try:
        socketio.emit('ride_offer', offer, room=f'driver:{driver_id}')
    except Exception:
        # swallow emit errors; logs handled by SocketIO
        pass


@socketio.on('accept_offer')
def handle_accept_offer(data):
    """Driver accepts an offer: try atomic assignment"""
    try:
        ride_id = int(data.get('ride_id'))
        driver_id = int(data.get('driver_id'))
    except Exception:
        emit('accept_offer_result', {'ok': False, 'error': 'ride_id and driver_id required'})
        return
    try:
        ok = accept_offer(ride_id, driver_id)
        emit('accept_offer_result', {'ok': ok, 'ride_id': ride_id})
        if not ok:
            emit('offer_taken', {'ride_id': ride_id}, room=f'driver:{driver_id}')
    except Exception as e:
        emit('accept_offer_result', {'ok': False, 'error': str(e)})


