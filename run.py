"""
Application Entry Point
Run this file to start the Flask application

NOTE: The blueprint structure is available in the app/ folder.
For now, we're using the original main.py to ensure compatibility.
To use the blueprint version, uncomment the blueprint code below.
"""

# Use blueprint structure
from app import create_app
app = create_app()

if __name__ == '__main__':
    app.run(debug=True)
