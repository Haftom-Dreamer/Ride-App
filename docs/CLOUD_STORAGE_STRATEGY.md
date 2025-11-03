# Cloud Storage File Organization Strategy

## Overview
This document outlines the recommended file organization and naming strategy for migrating uploaded files to cloud storage (AWS S3, Google Cloud Storage, Azure Blob, etc.) in production.

## Folder Structure

### Recommended Structure
```
uploads/
├── drivers/
│   ├── {driver_id}/
│   │   ├── profile/
│   │   │   └── profile_picture.{ext}
│   │   ├── documents/
│   │   │   ├── license_document_{timestamp}.{ext}
│   │   │   ├── vehicle_document_{timestamp}.{ext}
│   │   │   ├── plate_photo_{timestamp}.{ext}
│   │   │   └── id_document_{timestamp}.{ext}
│   │   └── vehicles/
│   │       └── vehicle_photo_{timestamp}.{ext}
├── passengers/
│   ├── {passenger_id}/
│   │   ├── profile/
│   │   │   └── profile_picture.{ext}
│   │   └── documents/
│   │       └── id_document_{timestamp}.{ext}
├── admins/
│   ├── {admin_id}/
│   │   └── profile/
│   │       └── profile_picture.{ext}
└── rides/
    ├── {ride_id}/
    │   ├── chat/
    │   │   └── attachments/
    │   └── receipts/
```

## File Naming Convention

### Option 1: UUID-Based (Recommended)
- **Format**: `{uuid4}.{extension}`
- **Example**: `a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg`
- **Pros**: 
  - Guaranteed unique
  - No collisions
  - No guessing of original filename
  - Security through obscurity
- **Cons**: 
  - Not human-readable
  - Harder to debug

### Option 2: Hashed Naming (Alternative)
- **Format**: `{hash}_{timestamp}.{extension}`
- **Example**: `sha256hash_1633024800.jpg`
- **Pros**: 
  - Deterministic (same file = same hash)
  - Can detect duplicates
  - Moderate security
- **Cons**: 
  - Longer filenames
  - Hash collision risk (minimal)

### Option 3: Structured Naming (Recommended for Production)
- **Format**: `{entity_type}_{entity_id}_{file_type}_{uuid4}.{extension}`
- **Example**: `driver_123_profile_a1b2c3d4.jpg`
- **Pros**: 
  - Human-readable
  - Easy to identify file purpose
  - Good for debugging
  - Still unique via UUID
- **Cons**: 
  - Longer filenames
  - Slightly less secure (reveals entity ID)

## Implementation Recommendation

### Recommended Approach: **Option 3 (Structured + UUID)**

```
driver_123_profile_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg
driver_123_license_a1b2c3d4-e5f6-7890-abcd-ef1234567890.pdf
passenger_456_profile_b2c3d4e5-f6g7-8901-bcde-f12345678901.jpg
admin_1_profile_c3d4e5f6-g7h8-9012-cdef-1234567890123.jpg
```

## Cloud Storage Service Abstraction

### Proposed Service Interface

```python
# app/services/storage.py

from abc import ABC, abstractmethod
import uuid
import os
from typing import Optional
from werkzeug.datastructures import FileStorage

class StorageService(ABC):
    """Abstract base class for storage services"""
    
    @abstractmethod
    def upload_file(self, file: FileStorage, folder: str, filename: str) -> str:
        """Upload file and return public URL"""
        pass
    
    @abstractmethod
    def delete_file(self, file_path: str) -> bool:
        """Delete file from storage"""
        pass
    
    @abstractmethod
    def get_file_url(self, file_path: str) -> str:
        """Get public URL for file"""
        pass

class LocalStorageService(StorageService):
    """Local filesystem storage (current implementation)"""
    
    def upload_file(self, file: FileStorage, folder: str, filename: str) -> str:
        # Current implementation
        pass
    
    def delete_file(self, file_path: str) -> bool:
        # Delete from local filesystem
        pass
    
    def get_file_url(self, file_path: str) -> str:
        # Return relative path for local
        pass

class S3StorageService(StorageService):
    """AWS S3 storage implementation"""
    
    def __init__(self, bucket_name: str, region: str):
        self.bucket_name = bucket_name
        self.region = region
        # Initialize boto3 client
        
    def upload_file(self, file: FileStorage, folder: str, filename: str) -> str:
        # Upload to S3
        # Return S3 key or public URL
        pass
    
    def delete_file(self, file_path: str) -> bool:
        # Delete from S3
        pass
    
    def get_file_url(self, file_path: str) -> str:
        # Return S3 public URL or signed URL
        pass
```

## File Path Generation Function

```python
def generate_file_path(entity_type: str, entity_id: int, file_type: str, extension: str) -> tuple:
    """
    Generate organized file path for cloud storage
    
    Args:
        entity_type: 'driver', 'passenger', 'admin'
        entity_id: ID of the entity
        file_type: 'profile', 'license', 'vehicle', 'plate', 'id', etc.
        extension: File extension (e.g., 'jpg', 'pdf')
    
    Returns:
        tuple: (folder_path, filename)
        Example: ('drivers/123/profile', 'driver_123_profile_a1b2c3d4.jpg')
    """
    # Generate UUID for uniqueness
    unique_id = str(uuid.uuid4())
    
    # Build folder structure
    folder = f"{entity_type}s/{entity_id}/{file_type}s"
    
    # Build filename
    filename = f"{entity_type}_{entity_id}_{file_type}_{unique_id}.{extension}"
    
    return folder, filename
```

## Migration Strategy

### Phase 1: Refactor Current Code
1. Create storage service abstraction
2. Implement local storage service (wrap current code)
3. Update `handle_file_upload` to use new structure
4. Test locally with new folder structure

### Phase 2: Database Update
1. Update database to store full cloud paths (not just filenames)
2. Migration script to update existing paths

### Phase 3: Cloud Integration
1. Implement cloud storage service (S3/Cloudinary/etc.)
2. Configuration-based switching between local/cloud
3. Upload new files to cloud
4. Gradually migrate existing files

## Configuration

```python
# config.py additions

class Config:
    # Storage Configuration
    STORAGE_TYPE = os.environ.get('STORAGE_TYPE', 'local')  # 'local' or 's3' or 'cloudinary'
    
    # Local Storage
    UPLOAD_FOLDER = os.path.join(basedir, 'static', 'uploads')
    
    # AWS S3 Configuration
    AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
    AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
    S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
    S3_USE_PUBLIC_URLS = os.environ.get('S3_USE_PUBLIC_URLS', 'false').lower() == 'true'
    
    # Cloudinary Configuration (alternative)
    CLOUDINARY_CLOUD_NAME = os.environ.get('CLOUDINARY_CLOUD_NAME')
    CLOUDINARY_API_KEY = os.environ.get('CLOUDINARY_API_KEY')
    CLOUDINARY_API_SECRET = os.environ.get('CLOUDINARY_API_SECRET')
```

## Benefits of This Approach

1. **Scalability**: Works with any cloud storage provider
2. **Organization**: Easy to find files by entity and type
3. **Security**: UUID prevents filename guessing attacks
4. **Maintainability**: Clear structure for debugging
5. **Migration**: Easy to switch between local and cloud
6. **CDN Ready**: Can easily add CDN URLs later
7. **Backup**: Easier to backup specific entity types
8. **Permissions**: Can set folder-level permissions in cloud

## Example File Paths

```
# Driver Profile Picture
drivers/123/profiles/driver_123_profile_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg

# Driver License Document
drivers/123/documents/driver_123_license_b2c3d4e5-f6g7-8901-bcde-f12345678901.pdf

# Passenger Profile Picture
passengers/456/profiles/passenger_456_profile_c3d4e5f6-g7h8-9012-cdef-1234567890123.jpg

# Admin Profile Picture
admins/1/profiles/admin_1_profile_d4e5f6g7-h8i9-0123-def0-2345678901234.jpg
```

## Next Steps

1. Create storage service interface
2. Refactor `handle_file_upload` function
3. Update all upload endpoints to use new structure
4. Create migration script for existing files
5. Implement cloud storage service when ready for production
