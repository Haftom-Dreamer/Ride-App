#!/usr/bin/env python
"""
Add missing columns to the driver table
This script adds password_hash, email, plate_photo, id_document, is_blocked, blocked_reason, blocked_at
"""

import os
import sys

# Add the parent directory to the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app
from app.models import db
from sqlalchemy import inspect, text

print("=" * 60)
print("RIDE Application - Driver Table Migration")
print("=" * 60)

# Create app
app = create_app()

with app.app_context():
    try:
        inspector = inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns('driver')]
        
        print(f"\n📋 Current driver table columns: {', '.join(columns)}")
        
        missing_columns = []
        
        # Check and add missing columns
        if 'password_hash' not in columns:
            missing_columns.append('password_hash')
            print("\n➕ Adding password_hash column...")
            db.session.execute(text("ALTER TABLE driver ADD COLUMN password_hash VARCHAR(255)"))
        
        if 'email' not in columns:
            missing_columns.append('email')
            print("➕ Adding email column...")
            db.session.execute(text("ALTER TABLE driver ADD COLUMN email VARCHAR(120)"))
        
        if 'plate_photo' not in columns:
            missing_columns.append('plate_photo')
            print("➕ Adding plate_photo column...")
            db.session.execute(text("ALTER TABLE driver ADD COLUMN plate_photo VARCHAR(255)"))
        
        if 'id_document' not in columns:
            missing_columns.append('id_document')
            print("➕ Adding id_document column...")
            db.session.execute(text("ALTER TABLE driver ADD COLUMN id_document VARCHAR(255)"))
        
        if 'is_blocked' not in columns:
            missing_columns.append('is_blocked')
            print("➕ Adding is_blocked column...")
            db.session.execute(text("ALTER TABLE driver ADD COLUMN is_blocked BOOLEAN DEFAULT 0"))
        
        if 'blocked_reason' not in columns:
            missing_columns.append('blocked_reason')
            print("➕ Adding blocked_reason column...")
            db.session.execute(text("ALTER TABLE driver ADD COLUMN blocked_reason VARCHAR(255)"))
        
        if 'blocked_at' not in columns:
            missing_columns.append('blocked_at')
            print("➕ Adding blocked_at column...")
            db.session.execute(text("ALTER TABLE driver ADD COLUMN blocked_at DATETIME"))
        
        if missing_columns:
            db.session.commit()
            print(f"\n✅ Successfully added {len(missing_columns)} column(s): {', '.join(missing_columns)}")
        else:
            print("\n✅ All columns already exist. No changes needed.")
        
        # Verify columns
        inspector = inspect(db.engine)
        columns_after = [col['name'] for col in inspector.get_columns('driver')]
        print(f"\n📋 Updated driver table columns: {', '.join(columns_after)}")
        
    except Exception as e:
        db.session.rollback()
        print(f"\n❌ Error adding columns: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

print("\n" + "=" * 60)
print("🎉 Migration completed successfully!")
print("=" * 60)

