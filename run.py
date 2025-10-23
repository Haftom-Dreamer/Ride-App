"""
Application Entry Point
Run this file to start the Flask application with SocketIO support
"""

from app import create_app, socketio
app = create_app()

if __name__ == '__main__':
    # Run with SocketIO support
    socketio.run(app, debug=True, host='0.0.0.0', port=5000)
