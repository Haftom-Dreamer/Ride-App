#!/usr/bin/env python
"""
Generate a secure SECRET_KEY for Flask application
"""

import secrets

def generate_key(length=32):
    """Generate a secure random key"""
    return secrets.token_hex(length)

if __name__ == '__main__':
    print("=" * 60)
    print("Secure SECRET_KEY Generator")
    print("=" * 60)
    print("\nGenerated SECRET_KEY:")
    print("-" * 60)
    key = generate_key()
    print(key)
    print("-" * 60)
    print("\nCopy this key to your .env file:")
    print(f"SECRET_KEY={key}")
    print("\nKeep this key secret and never commit it to version control!")
    print("=" * 60)

