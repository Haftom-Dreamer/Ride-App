#!/usr/bin/env python3
"""
Database migration script to add email field to Passenger table
Run this script to update the existing database schema
"""

import sys
import os
from sqlalchemy import text

# Add the project root to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.models import db

def migrate_add_email():
    """Add email field to Passenger table"""
    app = create_app()
    
    with app.app_context():
        try:
            # Check if email column already exists (SQLite compatible)
            try:
                result = db.session.execute(text("SELECT email FROM passenger LIMIT 1"))
                print("✅ Email column already exists in Passenger table")
                return
            except Exception:
                # Column doesn't exist, proceed with adding it
                pass
            
            print("🔄 Adding email column to Passenger table...")
            
            # Add email column (SQLite compatible)
            db.session.execute(text("""
                ALTER TABLE passenger 
                ADD COLUMN email VARCHAR(120) NOT NULL DEFAULT ''
            """))
            
            # Create index for email
            db.session.execute(text("""
                CREATE INDEX ix_passenger_email ON passenger (email)
            """))
            
            db.session.commit()
            print("✅ Successfully added email column to Passenger table")
            
        except Exception as e:
            print(f"❌ Error during migration: {e}")
            db.session.rollback()
            raise

if __name__ == "__main__":
    migrate_add_email()
