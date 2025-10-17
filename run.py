"""
Application Entry Point
Run this file to start the Flask application with SocketIO support
"""

# Use blueprint structure
from app import create_app, socketio
app = create_app()

if __name__ == '__main__':
    # Run with SocketIO support
    socketio.run(app, debug=True, host='127.0.0.1', port=5000)
