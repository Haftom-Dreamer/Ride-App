"""
Migration script to add new fields to Ride model and create EmergencyAlert table
"""

import os
import sys
from sqlalchemy import text

# Add the project root to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.models import db

def migrate_ride_fields():
    """Add new fields to Ride table and create EmergencyAlert table"""
    app = create_app()
    
    with app.app_context():
        try:
            # Check if start_time column already exists
            try:
                result = db.session.execute(text("SELECT start_time FROM ride LIMIT 1"))
                print("✅ Ride table already has new fields")
            except Exception:
                # Columns don't exist, add them
                print("🔄 Adding new fields to Ride table...")
                
                db.session.execute(text("ALTER TABLE ride ADD COLUMN start_time DATETIME"))
                db.session.execute(text("ALTER TABLE ride ADD COLUMN end_time DATETIME"))
                db.session.execute(text("ALTER TABLE ride ADD COLUMN rating INTEGER"))
                db.session.execute(text("ALTER TABLE ride ADD COLUMN feedback VARCHAR(500)"))
                
                db.session.commit()
                print("✅ Successfully added new fields to Ride table")
            
            # Check if emergency_alert table exists
            try:
                result = db.session.execute(text("SELECT * FROM emergency_alert LIMIT 1"))
                print("✅ EmergencyAlert table already exists")
            except Exception:
                # Table doesn't exist, create it
                print("🔄 Creating EmergencyAlert table...")
                
                db.session.execute(text("""
                    CREATE TABLE emergency_alert (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        passenger_id INTEGER NOT NULL,
                        ride_id INTEGER,
                        latitude REAL,
                        longitude REAL,
                        message VARCHAR(500),
                        alert_time DATETIME DEFAULT CURRENT_TIMESTAMP,
                        is_resolved BOOLEAN DEFAULT 0 NOT NULL,
                        resolved_at DATETIME,
                        FOREIGN KEY (passenger_id) REFERENCES passenger(id),
                        FOREIGN KEY (ride_id) REFERENCES ride(id)
                    )
                """))
                
                # Create indexes
                db.session.execute(text("CREATE INDEX ix_emergency_alert_passenger_id ON emergency_alert (passenger_id)"))
                db.session.execute(text("CREATE INDEX ix_emergency_alert_ride_id ON emergency_alert (ride_id)"))
                db.session.execute(text("CREATE INDEX ix_emergency_alert_alert_time ON emergency_alert (alert_time)"))
                
                db.session.commit()
                print("✅ Successfully created EmergencyAlert table")
                
        except Exception as e:
            print(f"❌ Error during migration: {e}")
            db.session.rollback()
            raise

if __name__ == '__main__':
    migrate_ride_fields()



