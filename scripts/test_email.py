"""
Test Email Configuration
Run this script to verify that email sending is working correctly
"""

import os
import sys
from dotenv import load_dotenv

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Load environment variables
load_dotenv()

def test_email_config():
    """Test if email configuration is set up correctly"""
    print("\n" + "="*60)
    print("🧪 TESTING EMAIL CONFIGURATION")
    print("="*60 + "\n")
    
    # Check if environment variables are set
    print("1️⃣ Checking environment variables...")
    
    required_vars = {
        'MAIL_SERVER': os.environ.get('MAIL_SERVER'),
        'MAIL_PORT': os.environ.get('MAIL_PORT'),
        'MAIL_USE_TLS': os.environ.get('MAIL_USE_TLS'),
        'MAIL_USERNAME': os.environ.get('MAIL_USERNAME'),
        'MAIL_PASSWORD': os.environ.get('MAIL_PASSWORD'),
        'MAIL_DEFAULT_SENDER': os.environ.get('MAIL_DEFAULT_SENDER'),
    }
    
    all_set = True
    for key, value in required_vars.items():
        if value:
            # Mask password
            if 'PASSWORD' in key:
                display_value = '*' * len(value) if len(value) > 4 else '****'
            else:
                display_value = value
            print(f"   ✅ {key}: {display_value}")
        else:
            print(f"   ❌ {key}: NOT SET")
            all_set = False
    
    if not all_set:
        print("\n❌ Email configuration is incomplete!")
        print("📖 Please follow the EMAIL_SETUP_GUIDE.md")
        return False
    
    print("\n2️⃣ Testing Flask app initialization...")
    try:
        from app import create_app
        app = create_app()
        print("   ✅ Flask app created successfully")
    except Exception as e:
        print(f"   ❌ Failed to create Flask app: {e}")
        return False
    
    print("\n3️⃣ Testing email service...")
    with app.app_context():
        try:
            from app.utils.email_service import send_verification_email
            
            # Get test email from user
            test_email = input("\n📧 Enter your email address to receive a test verification code: ").strip()
            
            if not test_email or '@' not in test_email:
                print("❌ Invalid email address")
                return False
            
            print(f"\n📤 Sending test email to {test_email}...")
            print("   (This will take a few seconds...)\n")
            
            success, message = send_verification_email(test_email)
            
            if success:
                print("\n" + "="*60)
                print("✅ SUCCESS! Email configuration is working!")
                print("="*60)
                print(f"\nCheck your inbox at {test_email}")
                print("You should receive a verification code email.")
                print("(Don't forget to check spam/junk folder)")
                return True
            else:
                print("\n" + "="*60)
                print("❌ FAILED! Email could not be sent")
                print("="*60)
                print(f"\nError message: {message}")
                print("\n📖 Troubleshooting steps:")
                print("1. Check that MAIL_PASSWORD is a Gmail App Password (not regular password)")
                print("2. Verify 2-Factor Authentication is enabled on your Gmail account")
                print("3. Make sure the App Password has no spaces")
                print("4. Try generating a new App Password")
                print("\nSee EMAIL_SETUP_GUIDE.md for detailed instructions")
                return False
                
        except Exception as e:
            print(f"\n❌ Error during email test: {e}")
            import traceback
            traceback.print_exc()
            return False

if __name__ == '__main__':
    try:
        success = test_email_config()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Test cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

