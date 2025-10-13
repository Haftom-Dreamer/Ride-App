#!/usr/bin/env python
"""
Installation Checker for RIDE Application
Verifies that all requirements are met and configuration is correct.
"""

import sys
import os

def check_python_version():
    """Check if Python version is adequate"""
    print("🐍 Checking Python version...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 8:
        print(f"   ✅ Python {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print(f"   ❌ Python {version.major}.{version.minor}.{version.micro} (Need 3.8+)")
        return False

def check_dependencies():
    """Check if all required packages are installed"""
    print("\n📦 Checking dependencies...")
    
    required_packages = {
        'flask': 'Flask',
        'flask_sqlalchemy': 'Flask-SQLAlchemy',
        'flask_cors': 'Flask-CORS',
        'flask_login': 'Flask-Login',
        'flask_migrate': 'Flask-Migrate',
        'flask_marshmallow': 'Flask-Marshmallow',
        'flask_limiter': 'Flask-Limiter',
        'flask_wtf': 'Flask-WTF',
        'dotenv': 'python-dotenv',
        'werkzeug': 'Werkzeug',
        'requests': 'requests',
        'reportlab': 'reportlab',
        'openpyxl': 'openpyxl',
    }
    
    missing = []
    for package, name in required_packages.items():
        try:
            __import__(package)
            print(f"   ✅ {name}")
        except ImportError:
            print(f"   ❌ {name} - NOT INSTALLED")
            missing.append(name)
    
    if missing:
        print(f"\n   ⚠️  Missing packages: {', '.join(missing)}")
        print("   Run: pip install -r requirements.txt")
        return False
    return True

def check_env_file():
    """Check if .env file exists and is configured"""
    print("\n⚙️  Checking configuration...")
    
    if not os.path.exists('.env'):
        print("   ❌ .env file not found")
        print("   Create it from ENV_TEMPLATE.txt")
        return False
    
    print("   ✅ .env file exists")
    
    # Check if it has required variables
    with open('.env', 'r') as f:
        content = f.read()
        
    checks = {
        'SECRET_KEY': 'your-super-secret-key' not in content,
        'FLASK_ENV': 'FLASK_ENV' in content,
    }
    
    all_good = True
    for key, passed in checks.items():
        if passed:
            print(f"   ✅ {key} configured")
        else:
            print(f"   ⚠️  {key} needs configuration")
            all_good = False
    
    return all_good

def check_config_file():
    """Check if config.py exists"""
    print("\n📋 Checking config file...")
    
    if not os.path.exists('config.py'):
        print("   ❌ config.py not found")
        return False
    
    print("   ✅ config.py exists")
    
    try:
        from config import config
        print("   ✅ config.py imports successfully")
        return True
    except Exception as e:
        print(f"   ❌ Error importing config: {e}")
        return False

def check_main_file():
    """Check if main.py exists and imports correctly"""
    print("\n🚀 Checking main application...")
    
    if not os.path.exists('main.py'):
        print("   ❌ main.py not found")
        return False
    
    print("   ✅ main.py exists")
    
    # Try to import (but don't run the app)
    try:
        import main
        print("   ✅ main.py imports successfully")
        print(f"   ✅ Flask app created")
        return True
    except Exception as e:
        print(f"   ❌ Error importing main: {e}")
        return False

def check_database():
    """Check database status"""
    print("\n💾 Checking database...")
    
    if os.path.exists('app.db'):
        size = os.path.getsize('app.db')
        print(f"   ✅ Database exists ({size:,} bytes)")
    else:
        print("   ℹ️  No database yet (will be created on first run)")
    
    if os.path.exists('migrations'):
        print("   ✅ Migrations folder exists")
    else:
        print("   ℹ️  No migrations yet (run 'flask db init')")
    
    return True

def check_uploads_folder():
    """Check if uploads folder exists"""
    print("\n📁 Checking uploads folder...")
    
    upload_path = os.path.join('static', 'uploads')
    if os.path.exists(upload_path):
        print(f"   ✅ {upload_path} exists")
    else:
        print(f"   ℹ️  {upload_path} doesn't exist (will be created automatically)")
    
    return True

def check_templates():
    """Check if templates exist"""
    print("\n🎨 Checking templates...")
    
    if not os.path.exists('templates'):
        print("   ❌ templates folder not found")
        return False
    
    required_templates = [
        'base.html',
        'dashboard.html',
        'login.html',
        'passenger.html',
        'passenger_login.html',
        'passenger_signup.html',
    ]
    
    missing = []
    for template in required_templates:
        path = os.path.join('templates', template)
        if os.path.exists(path):
            print(f"   ✅ {template}")
        else:
            print(f"   ❌ {template} - NOT FOUND")
            missing.append(template)
    
    return len(missing) == 0

def check_static_files():
    """Check if static files exist"""
    print("\n🎭 Checking static files...")
    
    if not os.path.exists('static'):
        print("   ❌ static folder not found")
        return False
    
    print("   ✅ static folder exists")
    
    if os.path.exists(os.path.join('static', 'img')):
        print("   ✅ static/img folder exists")
    else:
        print("   ⚠️  static/img folder not found")
    
    return True

def main():
    """Run all checks"""
    print("=" * 60)
    print("RIDE Application - Installation Checker")
    print("=" * 60)
    
    checks = [
        ("Python Version", check_python_version),
        ("Dependencies", check_dependencies),
        ("Environment File", check_env_file),
        ("Config File", check_config_file),
        ("Main Application", check_main_file),
        ("Database", check_database),
        ("Uploads Folder", check_uploads_folder),
        ("Templates", check_templates),
        ("Static Files", check_static_files),
    ]
    
    results = {}
    for name, check_func in checks:
        try:
            results[name] = check_func()
        except Exception as e:
            print(f"\n❌ Error during {name} check: {e}")
            results[name] = False
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    passed = sum(results.values())
    total = len(results)
    
    for name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {name}")
    
    print(f"\nScore: {passed}/{total} checks passed")
    
    if passed == total:
        print("\n🎉 All checks passed! Your installation looks good.")
        print("\nNext steps:")
        print("1. Review .env configuration")
        print("2. Run: python migrate_database.py (if migrating)")
        print("3. Run: python main.py")
    else:
        print("\n⚠️  Some checks failed. Please fix the issues above.")
        print("\nFor help, see:")
        print("- SETUP_GUIDE.md for detailed instructions")
        print("- ENV_TEMPLATE.txt for configuration reference")
    
    print("=" * 60)
    return passed == total

if __name__ == '__main__':
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Check cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

