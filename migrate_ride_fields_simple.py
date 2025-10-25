"""
Simple migration script to add new fields to Ride model and create EmergencyAlert table
"""

import sqlite3
import os

def migrate_database():
    """Add new fields to Ride table and create EmergencyAlert table"""
    db_path = 'ride_app.db'
    
    if not os.path.exists(db_path):
        print(f"❌ Database not found at {db_path}")
        return
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if start_time column already exists
        cursor.execute("PRAGMA table_info(ride)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'start_time' not in columns:
            print("🔄 Adding new fields to Ride table...")
            
            cursor.execute("ALTER TABLE ride ADD COLUMN start_time DATETIME")
            cursor.execute("ALTER TABLE ride ADD COLUMN end_time DATETIME")
            cursor.execute("ALTER TABLE ride ADD COLUMN rating INTEGER")
            cursor.execute("ALTER TABLE ride ADD COLUMN feedback VARCHAR(500)")
            
            conn.commit()
            print("✅ Successfully added new fields to Ride table")
        else:
            print("✅ Ride table already has new fields")
        
        # Check if emergency_alert table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='emergency_alert'")
        if not cursor.fetchone():
            print("🔄 Creating EmergencyAlert table...")
            
            cursor.execute("""
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
            """)
            
            # Create indexes
            cursor.execute("CREATE INDEX ix_emergency_alert_passenger_id ON emergency_alert (passenger_id)")
            cursor.execute("CREATE INDEX ix_emergency_alert_ride_id ON emergency_alert (ride_id)")
            cursor.execute("CREATE INDEX ix_emergency_alert_alert_time ON emergency_alert (alert_time)")
            
            conn.commit()
            print("✅ Successfully created EmergencyAlert table")
        else:
            print("✅ EmergencyAlert table already exists")
            
        print("\n✅ Migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Error during migration: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == '__main__':
    migrate_database()



