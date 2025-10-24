"""
Email service for sending verification emails
"""

import random
import string
from datetime import datetime, timedelta
from flask import current_app
from flask_mail import Mail, Message
from app.models import db, EmailVerification

mail = Mail()

def init_mail(app):
    """Initialize Flask-Mail with the app"""
    mail.init_app(app)

def generate_verification_code():
    """Generate a 6-digit verification code"""
    return ''.join(random.choices(string.digits, k=6))

def send_verification_email(email):
    """Send verification email to user"""
    try:
        print(f"\n{'='*60}")
        print(f"📧 EMAIL SENDING DEBUG START")
        print(f"{'='*60}")
        print(f"📧 Attempting to send verification email to: {email}")
        print(f"📧 Mail server: {current_app.config.get('MAIL_SERVER')}")
        print(f"📧 Mail port: {current_app.config.get('MAIL_PORT')}")
        print(f"📧 Mail use TLS: {current_app.config.get('MAIL_USE_TLS')}")
        print(f"📧 Mail username: {current_app.config.get('MAIL_USERNAME')}")
        print(f"📧 Mail password set: {'Yes' if current_app.config.get('MAIL_PASSWORD') else 'NO - THIS IS THE PROBLEM!'}")
        print(f"📧 Mail default sender: {current_app.config.get('MAIL_DEFAULT_SENDER')}")
        
        # Check if mail is configured
        if not current_app.config.get('MAIL_USERNAME'):
            error_msg = "❌ MAIL_USERNAME is not configured in .env file!"
            print(f"📧 ERROR: {error_msg}")
            print(f"{'='*60}\n")
            return False, "Email service not configured. Please contact administrator."
        
        if not current_app.config.get('MAIL_PASSWORD'):
            error_msg = "❌ MAIL_PASSWORD is not configured in .env file!"
            print(f"📧 ERROR: {error_msg}")
            print(f"{'='*60}\n")
            return False, "Email service not configured. Please contact administrator."
        
        # Generate verification code
        verification_code = generate_verification_code()
        print(f"📧 Generated verification code: {verification_code}")
        
        # Set expiration time (10 minutes from now)
        expires_at = datetime.utcnow() + timedelta(minutes=10)
        print(f"📧 Code expires at: {expires_at}")
        
        # Delete any existing verification codes for this email
        existing_count = EmailVerification.query.filter_by(email=email).count()
        if existing_count > 0:
            print(f"📧 Deleting {existing_count} existing verification code(s) for {email}")
            EmailVerification.query.filter_by(email=email).delete()
        
        # Create new verification record
        verification = EmailVerification(
            email=email,
            verification_code=verification_code,
            expires_at=expires_at
        )
        db.session.add(verification)
        db.session.commit()
        print(f"📧 Verification code saved to database")
        
        # Create email message
        print(f"📧 Creating email message...")
        msg = Message(
            subject='Verify Your RIDE Account',
            recipients=[email],
            sender=('Selamawi', 'selamawiride@gmail.com'),
            body=f'''
Hello!

Thank you for signing up for RIDE. Please use the following verification code to complete your registration:

Verification Code: {verification_code}

This code will expire in 10 minutes.

If you didn't request this verification, please ignore this email.

Best regards,
The RIDE Team
            ''',
            html=f'''
            <html>
            <body>
                <h2>Verify Your RIDE Account</h2>
                <p>Hello!</p>
                <p>Thank you for signing up for RIDE. Please use the following verification code to complete your registration:</p>
                <div style="background-color: #f0f0f0; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; margin: 20px 0;">
                    {verification_code}
                </div>
                <p>This code will expire in 10 minutes.</p>
                <p>If you didn't request this verification, please ignore this email.</p>
                <p>Best regards,<br>The RIDE Team</p>
            </body>
            </html>
            '''
        )
        print(f"📧 Email message created successfully")
        
        # Send email
        print(f"📧 Attempting to send email via SMTP...")
        mail.send(msg)
        print(f"✅ Email sent successfully to {email}!")
        print(f"{'='*60}\n")
        return True, "Verification email sent successfully"
        
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        print(f"\n{'='*60}")
        print(f"❌ EMAIL SENDING ERROR")
        print(f"{'='*60}")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {str(e)}")
        print(f"Full traceback:\n{error_trace}")
        print(f"{'='*60}\n")
        current_app.logger.error(f"Failed to send verification email: {str(e)}")
        current_app.logger.error(f"Full trace: {error_trace}")
        return False, f"Failed to send verification email: {str(e)}"

def verify_email_code(email, code):
    """Verify the email code"""
    try:
        verification = EmailVerification.query.filter_by(
            email=email,
            verification_code=code
        ).first()
        
        if not verification:
            return False, "Invalid verification code"
        
        if verification.is_expired():
            return False, "Verification code has expired"
        
        if verification.is_verified:
            return False, "Email already verified"
        
        # Mark as verified
        verification.is_verified = True
        db.session.commit()
        
        return True, "Email verified successfully"
        
    except Exception as e:
        current_app.logger.error(f"Email verification failed: {str(e)}")
        return False, f"Verification failed: {str(e)}"

