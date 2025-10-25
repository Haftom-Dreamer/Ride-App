#!/usr/bin/env python3
"""
Run database migration to add email field
"""

import subprocess
import sys

def run_migration():
    """Run the email migration"""
    try:
        print("🔄 Running database migration...")
        result = subprocess.run([sys.executable, "migrate_add_email.py"], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Migration completed successfully!")
            print(result.stdout)
        else:
            print("❌ Migration failed!")
            print(result.stderr)
            
    except Exception as e:
        print(f"❌ Error running migration: {e}")

if __name__ == "__main__":
    run_migration()
