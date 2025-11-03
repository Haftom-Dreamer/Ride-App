"""
Storage Service Abstraction
Supports both local filesystem and cloud storage (S3, Cloudinary, etc.)
"""

import os
import uuid
from abc import ABC, abstractmethod
from typing import Optional, Tuple
from werkzeug.datastructures import FileStorage
from werkzeug.utils import secure_filename
from flask import current_app
from config import Config


class StorageService(ABC):
    """Abstract base class for storage services"""
    
    @abstractmethod
    def upload_file(self, file: FileStorage, entity_type: str, entity_id: int, 
                   file_type: str, existing_path: Optional[str] = None) -> str:
        """Upload file and return storage path/URL"""
        pass
    
    @abstractmethod
    def delete_file(self, file_path: str) -> bool:
        """Delete file from storage"""
        pass
    
    @abstractmethod
    def get_file_url(self, file_path: str) -> str:
        """Get public URL for file"""
        pass


def generate_file_path(entity_type: str, entity_id: int, file_type: str, 
                       extension: str) -> Tuple[str, str]:
    """
    Generate organized file path for storage
    
    Args:
        entity_type: 'driver', 'passenger', 'admin'
        entity_id: ID of the entity
        file_type: 'profile', 'license', 'vehicle', 'plate', 'id', etc.
        extension: File extension (e.g., 'jpg', 'pdf')
    
    Returns:
        tuple: (folder_path, filename)
        Example: ('drivers/123/profiles', 'driver_123_profile_a1b2c3d4.jpg')
    """
    # Generate UUID for uniqueness and security
    unique_id = str(uuid.uuid4()).replace('-', '')[:16]  # Shortened UUID
    
    # Build folder structure: {entity_type}s/{entity_id}/{file_type}s
    if file_type == 'profile':
        folder = f"{entity_type}s/{entity_id}/profiles"
    elif file_type in ['license', 'vehicle', 'plate', 'id']:
        folder = f"{entity_type}s/{entity_id}/documents"
    else:
        folder = f"{entity_type}s/{entity_id}/{file_type}s"
    
    # Build filename: {entity_type}_{entity_id}_{file_type}_{uuid}.{ext}
    filename = f"{entity_type}_{entity_id}_{file_type}_{unique_id}.{extension}"
    
    return folder, filename


class LocalStorageService(StorageService):
    """Local filesystem storage implementation"""
    
    def upload_file(self, file: FileStorage, entity_type: str, entity_id: int,
                   file_type: str, existing_path: Optional[str] = None) -> str:
        """Upload file to local filesystem with organized structure"""
        if not file or not file.filename:
            return existing_path or ''
        
        # Validate file extension
        filename = secure_filename(file.filename)
        if not filename:
            return existing_path or ''
        
        if not Config.allowed_file(filename):
            raise ValueError(f"File type not allowed. Allowed types: {Config.ALLOWED_EXTENSIONS}")
        
        # Extract extension
        _, ext = os.path.splitext(filename)
        ext = ext.lstrip('.').lower()
        
        # Generate organized path
        folder, new_filename = generate_file_path(entity_type, entity_id, file_type, ext)
        
        # Build full path
        upload_folder = current_app.config.get('UPLOAD_FOLDER',
                                             os.path.join(current_app.root_path, '..', 'static', 'uploads'))
        full_folder = os.path.join(upload_folder, folder)
        os.makedirs(full_folder, exist_ok=True)
        
        save_path = os.path.join(full_folder, new_filename)
        
        # Save file
        file.save(save_path)
        
        # Delete old file if exists
        if existing_path and 'default_' not in existing_path:
            old_file_path = os.path.join(current_app.root_path, '..', existing_path)
            if os.path.exists(old_file_path):
                try:
                    os.remove(old_file_path)
                except OSError:
                    pass
        
        # Return relative path for database storage
        return os.path.join('static', 'uploads', folder, new_filename).replace('\\', '/')
    
    def delete_file(self, file_path: str) -> bool:
        """Delete file from local filesystem"""
        if not file_path or 'default_' in file_path:
            return False
        
        full_path = os.path.join(current_app.root_path, '..', file_path)
        if os.path.exists(full_path):
            try:
                os.remove(full_path)
                return True
            except OSError:
                return False
        return False
    
    def get_file_url(self, file_path: str) -> str:
        """Get URL for local file"""
        if not file_path:
            return ''
        # Return relative path for local storage
        return f"/{file_path}"


class S3StorageService(StorageService):
    """AWS S3 storage implementation"""
    
    def __init__(self, bucket_name: str, region: str):
        self.bucket_name = bucket_name
        self.region = region
        try:
            import boto3
            self.s3_client = boto3.client(
                's3',
                aws_access_key_id=current_app.config.get('AWS_ACCESS_KEY_ID'),
                aws_secret_access_key=current_app.config.get('AWS_SECRET_ACCESS_KEY'),
                region_name=region
            )
        except ImportError:
            raise ImportError("boto3 is required for S3 storage. Install with: pip install boto3")
    
    def upload_file(self, file: FileStorage, entity_type: str, entity_id: int,
                   file_type: str, existing_path: Optional[str] = None) -> str:
        """Upload file to S3 with organized structure"""
        if not file or not file.filename:
            return existing_path or ''
        
        # Validate file
        filename = secure_filename(file.filename)
        if not filename or not Config.allowed_file(filename):
            raise ValueError(f"File type not allowed. Allowed types: {Config.ALLOWED_EXTENSIONS}")
        
        # Extract extension
        _, ext = os.path.splitext(filename)
        ext = ext.lstrip('.').lower()
        
        # Generate organized path
        folder, new_filename = generate_file_path(entity_type, entity_id, file_type, ext)
        
        # S3 key (path)
        s3_key = f"{folder}/{new_filename}"
        
        # Upload to S3
        self.s3_client.upload_fileobj(
            file.stream,
            self.bucket_name,
            s3_key,
            ExtraArgs={
                'ContentType': file.content_type or 'application/octet-stream',
                'ACL': 'public-read' if current_app.config.get('S3_USE_PUBLIC_URLS') else 'private'
            }
        )
        
        # Delete old file if exists
        if existing_path:
            self.delete_file(existing_path)
        
        # Return S3 key for database storage
        return s3_key
    
    def delete_file(self, file_path: str) -> bool:
        """Delete file from S3"""
        if not file_path:
            return False
        
        try:
            self.s3_client.delete_object(Bucket=self.bucket_name, Key=file_path)
            return True
        except Exception:
            return False
    
    def get_file_url(self, file_path: str) -> str:
        """Get public URL for S3 file"""
        if not file_path:
            return ''
        
        if current_app.config.get('S3_USE_PUBLIC_URLS'):
            # Public URL
            return f"https://{self.bucket_name}.s3.{self.region}.amazonaws.com/{file_path}"
        else:
            # Generate signed URL (expires in 1 hour)
            from datetime import timedelta
            return self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': file_path},
                ExpiresIn=3600
            )


def get_storage_service() -> StorageService:
    """Factory function to get storage service based on configuration"""
    storage_type = current_app.config.get('STORAGE_TYPE', 'local').lower()
    
    if storage_type == 's3':
        return S3StorageService(
            bucket_name=current_app.config.get('S3_BUCKET_NAME'),
            region=current_app.config.get('AWS_REGION', 'us-east-1')
        )
    elif storage_type == 'local':
        return LocalStorageService()
    else:
        raise ValueError(f"Unknown storage type: {storage_type}")


# Updated handle_file_upload function for backward compatibility
def handle_file_upload(file_storage: FileStorage, entity_type: str, entity_id: int,
                      file_type: str, existing_path: Optional[str] = None) -> str:
    """
    Handle file upload with organized structure
    
    Args:
        file_storage: FileStorage object from request
        entity_type: 'driver', 'passenger', 'admin'
        entity_id: ID of the entity
        file_type: 'profile', 'license', 'vehicle', 'plate', 'id'
        existing_path: Path to existing file (for updates)
    
    Returns:
        str: Storage path/URL
    """
    storage_service = get_storage_service()
    return storage_service.upload_file(file_storage, entity_type, entity_id, file_type, existing_path)

