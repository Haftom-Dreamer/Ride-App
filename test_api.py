"""
Test script to check if API routes are registered
"""

import requests
import json

def test_api():
    base_url = "http://localhost:5000"
    
    print("Testing Flask server...")
    
    # Test 1: Basic server response
    try:
        response = requests.get(f"{base_url}/")
        print(f"✅ Server is running: {response.status_code}")
    except Exception as e:
        print(f"❌ Server not running: {e}")
        return
    
    # Test 2: Check if API routes exist
    try:
        response = requests.get(f"{base_url}/api/")
        print(f"API root: {response.status_code}")
        print(f"Response: {response.text[:200]}...")
    except Exception as e:
        print(f"❌ API root error: {e}")
    
    # Test 3: Test fare estimate endpoint
    try:
        data = {
            "pickup_lat": 9.0192,
            "pickup_lon": 38.7525,
            "dest_lat": 9.0192,
            "dest_lon": 38.7525,
            "vehicle_type": "Bajaj"
        }
        response = requests.post(
            f"{base_url}/api/fare-estimate",
            json=data,
            headers={"Content-Type": "application/json"}
        )
        print(f"Fare estimate: {response.status_code}")
        print(f"Response: {response.text[:200]}...")
    except Exception as e:
        print(f"❌ Fare estimate error: {e}")

if __name__ == "__main__":
    test_api()


