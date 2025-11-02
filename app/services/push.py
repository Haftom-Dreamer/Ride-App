"""
Push notification service (FCM)
This is a placeholder implementation; wire real FCM credentials to send.
"""

from typing import Optional
from app.models import db, DeviceToken


def register_device_token(user_type: str, user_id: int, token: str, platform: Optional[str] = None):
    """Create or update device token for a user"""
    existing = DeviceToken.query.filter_by(fcm_token=token).first()
    if existing:
        existing.user_type = user_type
        existing.user_id = user_id
        existing.platform = platform
    else:
        db.session.add(DeviceToken(
            user_type=user_type,
            user_id=user_id,
            fcm_token=token,
            platform=platform,
        ))
    db.session.commit()


def send_push_to_user(user_type: str, user_id: int, title: str, body: str, data: Optional[dict] = None):
    """Send push to all tokens registered for a user. Placeholder no-op."""
    # TODO: integrate firebase_admin SDK and send message to tokens
    tokens = DeviceToken.query.filter_by(user_type=user_type, user_id=user_id).all()
    # For now, just return count
    return len(tokens)




