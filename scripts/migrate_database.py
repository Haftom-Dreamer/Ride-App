#!/usr/bin/env python
"""
Database Migration Helper Script
This script helps migrate your existing database to the new schema with indexes and Decimal types.
"""

import os
import sys
from datetime import datetime

def backup_database():
    """Create a backup of the current database"""
    if os.path.exists('app.db'):
        backup_name = f'app.db.backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
        try:
            import shutil
            shutil.copy2('app.db', backup_name)
            print(f"✅ Database backed up to: {backup_name}")
            return True
        except Exception as e:
            print(f"❌ Failed to backup database: {e}")
            return False
    else:
        print("ℹ️  No existing database found. Will create a new one.")
        return True

def check_env_file():
    """Check if .env file exists"""
    if not os.path.exists('.env'):
        print("⚠️  Warning: .env file not found!")
        print("📄 Creating .env file from template...")
        
        if os.path.exists('ENV_TEMPLATE.txt'):
            import shutil
            shutil.copy2('ENV_TEMPLATE.txt', '.env')
            print("✅ .env file created. Please edit it with your settings.")
            print("   Especially set a secure SECRET_KEY!")
            return False
        else:
            print("❌ ENV_TEMPLATE.txt not found. Please create .env manually.")
            return False
    return True

def run_migrations():
    """Run Flask-Migrate to update the database schema"""
    print("\n🔄 Running database migrations...")
    
    try:
        # Check if migrations folder exists
        if not os.path.exists('migrations'):
            print("Initializing migrations...")
            os.system('flask db init')
        
        # Create migration
        print("Creating migration...")
        result = os.system('flask db migrate -m "Add indexes and change fare to Numeric"')
        
        if result != 0:
            print("⚠️  Migration creation had issues. Review the output above.")
            response = input("Continue with upgrade? (yes/no): ")
            if response.lower() not in ['yes', 'y']:
                return False
        
        # Apply migration
        print("Applying migration...")
        result = os.system('flask db upgrade')
        
        if result == 0:
            print("✅ Database migration completed successfully!")
            return True
        else:
            print("❌ Migration failed. Check the error messages above.")
            return False
            
    except Exception as e:
        print(f"❌ Migration error: {e}")
        return False

def verify_admin_exists():
    """Check if an admin user exists"""
    print("\n👤 Checking for admin user...")
    
    try:
        from main import app, Admin
        with app.app_context():
            admin = Admin.query.first()
            if admin:
                print(f"✅ Admin user exists: {admin.username}")
                return True
            else:
                print("⚠️  No admin user found!")
                response = input("Create an admin user now? (yes/no): ")
                if response.lower() in ['yes', 'y']:
                    os.system('python create_admin.py')
                return True
    except Exception as e:
        print(f"⚠️  Could not verify admin: {e}")
        return True

def main():
    """Main migration process"""
    print("=" * 60)
    print("RIDE Application - Database Migration Tool")
    print("=" * 60)
    
    # Step 1: Check environment
    if not check_env_file():
        print("\n⚠️  Please configure .env file first, then run this script again.")
        sys.exit(1)
    
    # Step 2: Backup database
    print("\n📦 Step 1: Backing up database...")
    if not backup_database():
        response = input("Continue without backup? (yes/no): ")
        if response.lower() not in ['yes', 'y']:
            print("Migration cancelled.")
            sys.exit(1)
    
    # Step 3: Run migrations
    print("\n🔄 Step 2: Updating database schema...")
    if not run_migrations():
        print("\n❌ Migration failed. Your backup is safe.")
        print("   Review the errors and try again.")
        sys.exit(1)
    
    # Step 4: Verify admin
    verify_admin_exists()
    
    # Success!
    print("\n" + "=" * 60)
    print("🎉 Migration completed successfully!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Review your .env file and update any settings")
    print("2. Test the application: python main.py")
    print("3. Check that everything works as expected")
    print("4. Keep your database backup safe")
    print("\nFor more information, see SETUP_GUIDE.md")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Migration cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

