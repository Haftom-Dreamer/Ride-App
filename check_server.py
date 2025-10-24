"""
Check Flask Server Status and Configuration
"""

import os
import sys
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

print("\n" + "="*60)
print("🔍 FLASK SERVER DIAGNOSTIC CHECK")
print("="*60 + "\n")

# 1. Check if .env file exists
print("1️⃣ Checking .env file...")
if os.path.exists('.env'):
    print("   ✅ .env file exists")
    
    # Check email config
    with open('.env', 'r') as f:
        env_content = f.read()
        
    has_mail_username = 'MAIL_USERNAME=' in env_content and 'selamawiride@gmail.com' in env_content
    has_mail_password = 'MAIL_PASSWORD=' in env_content and 'your-app-password-here' not in env_content
    
    if has_mail_username:
        print("   ✅ MAIL_USERNAME is configured")
    else:
        print("   ❌ MAIL_USERNAME is not configured")
    
    if has_mail_password:
        print("   ✅ MAIL_PASSWORD is configured")
    else:
        print("   ❌ MAIL_PASSWORD is not configured or still has default value")
else:
    print("   ❌ .env file NOT found!")

print("\n2️⃣ Checking if Flask server is running...")
try:
    response = requests.get('http://localhost:5000/', timeout=2)
    print("   ✅ Flask server IS running on port 5000")
    print(f"   Server responded with status: {response.status_code}")
except requests.exceptions.ConnectionError:
    print("   ❌ Flask server is NOT running on port 5000")
    print("   👉 You need to start the server with: python run.py")
    sys.exit(1)
except Exception as e:
    print(f"   ⚠️ Error checking server: {e}")

print("\n3️⃣ Testing signup endpoint...")
try:
    test_data = {
        'username': 'TestUser',
        'email': 'test@example.com',
        'phone_number': '123456789',
        'password': 'testpass123'
    }
    
    response = requests.post(
        'http://localhost:5000/auth/passenger/signup',
        data=test_data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'},
        timeout=5
    )
    
    print(f"   Response status: {response.status_code}")
    print(f"   Response content-type: {response.headers.get('content-type', 'unknown')}")
    
    if response.status_code == 302:
        print("   ⚠️ Got 302 REDIRECT - This means the server code hasn't been updated!")
        print("   👉 The server is running OLD CODE")
        print("\n" + "="*60)
        print("🔧 SOLUTION:")
        print("="*60)
        print("1. Find the terminal window running the Flask server")
        print("2. Press Ctrl+C to stop it")
        print("3. Run: python run.py")
        print("4. Look for these lines when starting:")
        print("   * Running on http://0.0.0.0:5000")
        print("5. Try signup again from the Flutter app")
        print("="*60)
    elif response.status_code == 200:
        print("   ✅ Got JSON response - Server code is updated!")
        try:
            json_data = response.json()
            print(f"   Response: {json_data}")
        except:
            print(f"   Response text: {response.text[:200]}")
    elif response.status_code == 400:
        print("   ℹ️ Got 400 error - This is expected for test data")
        try:
            json_data = response.json()
            print(f"   Response: {json_data}")
        except:
            print(f"   Response text: {response.text[:200]}")
    else:
        print(f"   ⚠️ Unexpected status code: {response.status_code}")
        print(f"   Response: {response.text[:200]}")
        
except Exception as e:
    print(f"   ❌ Error testing endpoint: {e}")

print("\n4️⃣ Checking if multiple servers might be running...")
try:
    # Try different ports
    ports = [5000, 8000, 5001, 8080]
    running_servers = []
    
    for port in ports:
        try:
            response = requests.get(f'http://localhost:{port}/', timeout=1)
            running_servers.append(port)
        except:
            pass
    
    if len(running_servers) > 1:
        print(f"   ⚠️ Multiple servers detected on ports: {running_servers}")
        print("   👉 You might have multiple Flask servers running!")
        print("   👉 Stop all of them and start only ONE with: python run.py")
    elif len(running_servers) == 1:
        print(f"   ✅ Only one server running on port {running_servers[0]}")
    else:
        print("   ❌ No servers found running")
        
except Exception as e:
    print(f"   ⚠️ Error checking ports: {e}")

print("\n" + "="*60)
print("📋 NEXT STEPS:")
print("="*60)
print("1. Look at the Flask server terminal (not the Flutter terminal)")
print("2. When you signup, you should see lines like:")
print("   🚀 API SIGNUP REQUEST RECEIVED")
print("   📧 EMAIL SENDING DEBUG START")
print("3. If you DON'T see these, the server needs to be restarted")
print("="*60 + "\n")

