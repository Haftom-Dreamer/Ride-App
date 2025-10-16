"""Add driver earnings and commission tracking tables

Revision ID: 8f7a2b3c4d5e
Revises: 87ea2219f2f5
Create Date: 2025-01-14 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import sqlite

# revision identifiers, used by Alembic.
revision = '8f7a2b3c4d5e'
down_revision = '87ea2219f2f5'
branch_labels = None
depends_on = None


def upgrade():
    # Create driver_earnings table
    op.create_table('driver_earnings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('driver_id', sa.Integer(), nullable=False),
        sa.Column('ride_id', sa.Integer(), nullable=False),
        sa.Column('gross_fare', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('commission_rate', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('commission_amount', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('driver_earnings', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('payment_status', sa.String(length=20), nullable=False),
        sa.Column('payment_date', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['driver_id'], ['driver.id'], ),
        sa.ForeignKeyConstraint(['ride_id'], ['ride.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_driver_earnings_created_at'), 'driver_earnings', ['created_at'], unique=False)
    op.create_index(op.f('ix_driver_earnings_driver_id'), 'driver_earnings', ['driver_id'], unique=False)
    op.create_index(op.f('ix_driver_earnings_payment_status'), 'driver_earnings', ['payment_status'], unique=False)
    op.create_index(op.f('ix_driver_earnings_ride_id'), 'driver_earnings', ['ride_id'], unique=False)

    # Create commission table
    op.create_table('commission',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('vehicle_type', sa.String(length=50), nullable=False),
        sa.Column('commission_rate', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('effective_date', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_commission_vehicle_type'), 'commission', ['vehicle_type'], unique=False)
    op.create_unique_constraint('_vehicle_commission_uc', 'commission', ['vehicle_type', 'effective_date'])


def downgrade():
    op.drop_table('commission')
    op.drop_table('driver_earnings')
