#!/usr/bin/env python
"""
Simple Database Initialization Script
Creates all database tables directly using SQLAlchemy
"""

import os
import sys

print("=" * 60)
print("RIDE Application - Database Initialization")
print("=" * 60)

# Check if .env exists
if not os.path.exists('.env'):
    print("❌ Error: .env file not found!")
    print("   Please create .env file first.")
    sys.exit(1)

print("\n✅ .env file found")

# Import the Flask app and database
try:
    from main import app, db
    print("✅ Flask application loaded successfully")
except Exception as e:
    print(f"❌ Error loading Flask application: {e}")
    sys.exit(1)

# Create all tables
print("\n🔄 Creating database tables...")
try:
    with app.app_context():
        # Create instance directory if it doesn't exist
        instance_path = os.path.join(os.path.dirname(__file__), 'instance')
        os.makedirs(instance_path, exist_ok=True)
        print(f"✅ Instance directory ready: {instance_path}")
        
        # Create all tables
        db.create_all()
        print("✅ All database tables created successfully!")
        
        # List the tables created
        from sqlalchemy import inspect
        inspector = inspect(db.engine)
        tables = inspector.get_table_names()
        print(f"\n📊 Created {len(tables)} tables:")
        for table in sorted(tables):
            print(f"   - {table}")
        
except Exception as e:
    print(f"❌ Error creating database tables: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\n" + "=" * 60)
print("🎉 Database initialization completed successfully!")
print("=" * 60)
print("\nNext steps:")
print("1. Create an admin user: python create_admin.py")
print("2. Run the application: python main.py")
print("\n")

