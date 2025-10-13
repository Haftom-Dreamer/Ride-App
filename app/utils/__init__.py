"""
Utility Functions
"""

import os
from datetime import datetime, timedelta, timezone
from werkzeug.utils import secure_filename
from flask import current_app
from config import Config

def to_eat(utc_dt):
    """Converts a UTC datetime object to East Africa Time (EAT)."""
    if utc_dt is None:
        return None
    return utc_dt.replace(tzinfo=timezone.utc).astimezone(timezone(timedelta(hours=3)))

def handle_file_upload(file_storage, existing_path=None):
    """Handle file upload with security checks"""
    if not file_storage or not file_storage.filename:
        return existing_path
    
    filename = secure_filename(file_storage.filename)
    if not filename:
        return existing_path
    
    # Check file extension using Config class method
    if not Config.allowed_file(filename):
        raise ValueError(f"File type not allowed. Allowed types: {current_app.config['ALLOWED_EXTENSIONS']}")
    
    # Create upload directory if it doesn't exist
    upload_folder = current_app.config.get('UPLOAD_FOLDER', 
                                         os.path.join(current_app.root_path, '..', 'static', 'uploads'))
    os.makedirs(upload_folder, exist_ok=True)
    
    # Generate unique filename if file already exists
    name, ext = os.path.splitext(filename)
    save_path = os.path.join(upload_folder, filename)
    if os.path.exists(save_path):
        timestamp = int(datetime.now(timezone.utc).timestamp())
        filename = f"{name}_{timestamp}{ext}"
        save_path = os.path.join(upload_folder, filename)
    
    # Save file
    file_storage.save(save_path)
    
    # Delete old file if it exists and is not the default
    if existing_path and 'default_' not in existing_path:
        old_file_path = os.path.join(current_app.root_path, '..', existing_path)
        if os.path.exists(old_file_path):
            try:
                os.remove(old_file_path)
            except OSError:
                pass  # Ignore errors if file can't be deleted
    
    rel_path = os.path.join('static', 'uploads', filename).replace('\\', '/')
    return rel_path
