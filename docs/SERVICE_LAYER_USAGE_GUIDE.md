# Service Layer Usage Guide

This guide provides examples and best practices for using the service layer in the RIDE application.

## Quick Reference

### Available Services

```python
# Import is already done in main.py after model definitions
passenger_service = PassengerService(db, Passenger)
driver_service = DriverService(db, Driver)
ride_service = RideService(db, Ride)
feedback_service = FeedbackService(db, Feedback)
setting_service = SettingService(db, Setting)
admin_service = AdminService(db, Admin)
analytics_service = AnalyticsService(db, Ride, Driver, Passenger, Feedback)
```

## Common Usage Patterns

### 1. Simple Query Operations

#### Getting a record by ID
```python
# Before
ride = Ride.query.get(ride_id)

# After
ride = ride_service.get_by_id(ride_id)
```

#### Getting all records with filters
```python
# Before
rides = Ride.query.filter_by(status='Completed').all()

# After
rides = ride_service.get_all(status='Completed')
```

### 2. Creating Records

```python
# Before
new_ride = Ride(
    passenger_id=current_user.id,
    pickup_address=pickup_address,
    fare=fare,
    # ... other fields
)
db.session.add(new_ride)
db.session.commit()

# After
new_ride = ride_service.create_ride(
    passenger_id=current_user.id,
    pickup_address=pickup_address,
    fare=fare,
    # ... other fields
)
ride_service.commit()
```

### 3. Updating Records

```python
# Before
ride = Ride.query.get(ride_id)
ride.status = 'Completed'
ride.completed_at = datetime.now(timezone.utc)
db.session.commit()

# After
ride = ride_service.get_by_id(ride_id)
ride_service.update_ride_status(ride, 'Completed')
ride_service.commit()
```

### 4. Complex Queries

```python
# Before
rides = Ride.query.filter(
    and_(
        Ride.status == 'Completed',
        Ride.request_time >= start_date,
        Ride.request_time <= end_date
    )
).order_by(Ride.request_time.desc()).all()

# After
rides = ride_service.get_rides_by_date_range(start_date, end_date)
# Note: The service method handles the filtering and ordering
```

## Real-World Examples

### Example 1: Complete Ride Endpoint

**Original Code:**
```python
@app.route('/api/complete-ride', methods=['POST'])
@admin_required
def complete_ride():
    ride = Ride.query.get(request.json.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    
    ride.status = 'Completed'
    driver = Driver.query.get(ride.driver_id)
    if driver:
        driver.status = 'Available'
    
    db.session.commit()
    return jsonify({'message': 'Ride completed successfully'})
```

**Refactored Code:**
```python
@app.route('/api/complete-ride', methods=['POST'])
@admin_required
def complete_ride():
    ride = ride_service.get_by_id(request.json.get('ride_id'))
    if not ride:
        return jsonify({'error': 'Ride not found'}), 404
    
    # Update ride status
    ride_service.update_ride_status(ride, 'Completed')
    
    # Update driver status
    if ride.driver_id:
        driver = driver_service.get_by_id(ride.driver_id)
        if driver:
            driver_service.update_driver_status(driver, 'Available')
    
    ride_service.commit()
    return jsonify({'message': 'Ride completed successfully'})
```

### Example 2: Get Passenger Ride History

**Original Code:**
```python
@app.route('/api/passenger/rides')
@passenger_required
def get_passenger_rides():
    rides = Ride.query.filter_by(
        passenger_id=current_user.id
    ).order_by(Ride.request_time.desc()).all()
    
    return jsonify([{
        'id': r.id,
        'destination': r.dest_address,
        'fare': float(r.fare),
        'status': r.status,
        'date': r.request_time.strftime('%Y-%m-%d')
    } for r in rides])
```

**Refactored Code:**
```python
@app.route('/api/passenger/rides')
@passenger_required
def get_passenger_rides():
    # Service layer handles the query and ordering
    rides = ride_service.get_passenger_rides(current_user.id)
    
    return jsonify([{
        'id': r.id,
        'destination': r.dest_address,
        'fare': float(r.fare),
        'status': r.status,
        'date': r.request_time.strftime('%Y-%m-%d')
    } for r in rides])
```

### Example 3: Dashboard Statistics

**Original Code:**
```python
@app.route('/api/dashboard-stats')
@admin_required
def get_dashboard_stats():
    total_rides = Ride.query.count()
    active_rides = Ride.query.filter(
        Ride.status.in_(['Assigned', 'In Progress'])
    ).count()
    available_drivers = Driver.query.filter_by(status='Available').count()
    
    today = datetime.now(timezone.utc).date()
    today_start = datetime.combine(today, datetime.min.time()).replace(tzinfo=timezone.utc)
    today_revenue = Ride.query.filter(
        and_(
            Ride.status == 'Completed',
            Ride.request_time >= today_start
        )
    ).with_entities(func.sum(Ride.fare)).scalar() or Decimal('0.0')
    
    return jsonify({
        'total_rides': total_rides,
        'active_rides': active_rides,
        'available_drivers': available_drivers,
        'today_revenue': float(today_revenue)
    })
```

**Refactored Code:**
```python
@app.route('/api/dashboard-stats')
@admin_required
def get_dashboard_stats():
    # Service layer handles all complex queries
    stats = analytics_service.get_dashboard_stats()
    return jsonify(stats)
```

## Best Practices

### 1. Always Use Services for Database Operations

❌ **Bad:**
```python
ride = Ride.query.filter_by(id=ride_id, passenger_id=current_user.id).first()
```

✅ **Good:**
```python
ride = ride_service.get_by_id(ride_id)
# Then check: if ride.passenger_id != current_user.id: ...
```

### 2. Let Services Handle Transactions

❌ **Bad:**
```python
new_passenger = passenger_service.create(username=username, phone_number=phone)
db.session.commit()  # Don't use db.session directly
```

✅ **Good:**
```python
new_passenger = passenger_service.create(username=username, phone_number=phone)
passenger_service.commit()  # Use service's commit method
```

### 3. Use Service Methods for Common Operations

❌ **Bad:**
```python
rides = Ride.query.filter_by(status='Requested').order_by(Ride.request_time).all()
```

✅ **Good:**
```python
rides = ride_service.get_pending_rides()  # Method already exists
```

### 4. Keep Routes Thin

Routes should:
- Validate request data
- Call service methods
- Format responses
- Handle HTTP concerns (status codes, headers, etc.)

Routes should NOT:
- Execute database queries
- Implement business logic
- Handle complex data transformations

### 5. Handle Errors Appropriately

```python
@app.route('/api/some-endpoint')
def some_endpoint():
    try:
        result = service.some_method()
        service.commit()
        return jsonify(result), 200
    except Exception as e:
        service.rollback()
        app.logger.error(f"Error: {e}")
        return jsonify({'error': 'An error occurred'}), 500
```

## Adding New Service Methods

When you need a new database operation, add it to the appropriate service:

```python
# In services.py
class RideService(BaseService):
    # ... existing methods ...
    
    def get_rides_by_driver_and_status(self, driver_id: int, status: str):
        """Get rides for a specific driver with a specific status"""
        return self.model.query.filter_by(
            driver_id=driver_id,
            status=status
        ).order_by(self.model.request_time.desc()).all()
```

Then use it in your route:

```python
@app.route('/api/driver/<int:driver_id>/rides/<status>')
@admin_required
def get_driver_rides_by_status(driver_id, status):
    rides = ride_service.get_rides_by_driver_and_status(driver_id, status)
    return jsonify(rides_schema.dump(rides))
```

## Testing Services

Services are easy to test in isolation:

```python
# test_services.py
import unittest
from services import RideService

class TestRideService(unittest.TestCase):
    def setUp(self):
        # Set up test database
        self.ride_service = RideService(test_db, Ride)
    
    def test_create_ride(self):
        ride = self.ride_service.create_ride(
            passenger_id=1,
            pickup_address="Test St",
            # ... other fields
        )
        self.ride_service.commit()
        
        self.assertIsNotNone(ride.id)
        self.assertEqual(ride.status, 'Requested')
```

## Migration Checklist

When refactoring an endpoint to use services:

- [ ] Identify all database queries in the endpoint
- [ ] Check if service methods exist for those operations
- [ ] If not, add methods to the appropriate service
- [ ] Replace direct queries with service method calls
- [ ] Replace `db.session.commit()` with `service.commit()`
- [ ] Replace `db.session.rollback()` with `service.rollback()`
- [ ] Test the endpoint thoroughly
- [ ] Check for linter errors

## Common Pitfalls

### 1. Forgetting to Commit

```python
# This creates the ride but doesn't save it!
ride = ride_service.create_ride(...)
# Missing: ride_service.commit()
```

### 2. Mixing Direct Queries and Services

```python
# Bad - mixing patterns
ride = ride_service.get_by_id(ride_id)
driver = Driver.query.get(driver_id)  # Should use driver_service

# Good - consistent pattern
ride = ride_service.get_by_id(ride_id)
driver = driver_service.get_by_id(driver_id)
```

### 3. Not Using Existing Service Methods

Before adding a new service method, check if one already exists:

```python
# services.py already has get_available_drivers()
# Don't rewrite this query in your route!
drivers = driver_service.get_available_drivers(vehicle_type)
```

## Performance Tips

1. **Use service methods that return only needed data**
   ```python
   # Better
   revenue = ride_service.get_revenue_stats()
   
   # Worse - loads all ride objects
   rides = ride_service.get_all(status='Completed')
   revenue = sum(r.fare for r in rides)
   ```

2. **Batch operations when possible**
   ```python
   # Create multiple records before committing
   for data in passenger_list:
       passenger_service.create(**data)
   passenger_service.commit()  # Single commit
   ```

3. **Use specialized query methods**
   ```python
   # The service can optimize this query
   stats = analytics_service.get_dashboard_stats()
   ```

---

For questions or suggestions, please refer to `REFACTORING_SUMMARY.md` or consult the team.

