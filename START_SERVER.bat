@echo off
echo.
echo ============================================================
echo STARTING FLASK SERVER WITH EMAIL DEBUG ENABLED
echo ============================================================
echo.
echo Setting up adb reverse connection...
adb reverse tcp:5000 tcp:5000
echo.
echo Starting Flask server...
echo Press CTRL+C to stop the server
echo.

python run.py

pause

