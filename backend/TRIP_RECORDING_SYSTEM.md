# Trip Recording System Architecture

A comprehensive, scalable backend system for mobile trip recording with automatic trip detection and route tracking.

## 🏗️ System Overview

The Trip Recording System consists of two main independent modules working together:

1. **Trip State Machine** (Brain) - Manages trip lifecycle and state transitions
2. **Route Recorder** (Engine) - Handles GPS data collection and route processing

## 📋 System Components

### 1. Trip State Machine (`trip_state_machine.py`)

**Responsibility**: Detect and manage trip lifecycle (Idle → Active → Idle)

**Key Features**:

- **States**: `IDLE` (no trip) and `ACTIVE` (trip in progress)
- **Manual Control**: User can start/stop trips via button press
- **Automatic Detection**: Speed and duration thresholds trigger state changes
- **Configurable Thresholds**: Speed (3 km/h), duration (60s), stop duration (60s)
- **Per-User State Management**: Each user has their own state machine instance

**State Transitions**:

```
IDLE → ACTIVE: Speed > 3 km/h for 60 seconds (or manual start)
ACTIVE → IDLE: Speed < 3 km/h for 60 seconds (or manual stop)
```

**Outputs**: Controls Route Recorder via callbacks:

- `RouteRecorder.start(tripId)` - When trip starts
- `RouteRecorder.stop(tripId)` - When trip ends

### 2. Route Recorder (`route_recorder.py`)

**Responsibility**: Track and store route data during active trips

**Key Features**:

- **GPS Collection**: Collects GPS points every 45 seconds during active trips
- **Data Validation**: Filters invalid GPS data (accuracy, coordinate bounds)
- **Distance Filtering**: Only stores points with meaningful movement (10m threshold)
- **Batch Processing**: Saves GPS points in batches for efficiency
- **Post-Processing**: Calculates distance, optionally snaps to roads
- **Concurrent Recording**: Handles multiple simultaneous trip recordings

**Data Collected**:

- Latitude, Longitude, Accuracy
- Speed, Altitude, Bearing
- Timestamps (client and server)
- Trip metadata (start/end times, distance, duration)

### 3. Sensor Processor (`sensor_processor.py`)

**Responsibility**: Process and validate mobile sensor data

**Key Features**:

- **Multi-Platform Support**: Android Activity Recognition API, iOS Core Motion
- **Data Validation**: GPS bounds, accuracy thresholds, speed limits
- **Activity Recognition**: Walking, in_vehicle, cycling, still, etc.
- **Motion Analysis**: Accelerometer data processing for stationary detection
- **Data Smoothing**: Moving averages for speed and location data
- **Quality Assessment**: Location quality scoring (excellent/good/fair/poor)

**Supported Activities**:

- `STILL`, `WALKING`, `RUNNING`, `IN_VEHICLE`, `ON_BICYCLE`, `ON_FOOT`, `TILTING`, `UNKNOWN`

### 4. ML Backend (`ml_backend.py`)

**Responsibility**: Enhanced trip detection and transport mode classification

**Key Features**:

- **Feature Extraction**: Speed patterns, acceleration, movement analysis
- **Transport Mode Classification**: Walking, cycling, car, bus, train detection
- **Trip Quality Scoring**: GPS accuracy, data completeness, consistency
- **User Pattern Learning**: Learns individual travel patterns over time
- **Rule-Based Classification**: Simple classifier (can be replaced with trained models)

**ML Features Extracted**:

- Speed statistics (avg, max, variance, percentiles)
- Acceleration patterns
- Stop frequency and direction changes
- Time patterns (time of day, day of week)
- GPS quality metrics

## 🔌 API Endpoints

### Core Trip Recording Endpoints

#### 1. Process Sensor Data

```http
POST /api/v1/trip-recording/sensor-data
```

**Purpose**: Main endpoint for processing mobile sensor data
**Pipeline**: Sensor Processing → State Machine → Route Recording → Response

**Request Body**:

```json
{
  "latitude": 17.385,
  "longitude": 78.4867,
  "accuracy": 5.0,
  "speed_mps": 2.5,
  "activity_type": "in_vehicle",
  "activity_confidence": 0.8,
  "accelerometer_x": 0.1,
  "accelerometer_y": 0.2,
  "accelerometer_z": 9.8,
  "timestamp": 1640995200
}
```

**Response**:

```json
{
  "success": true,
  "state_machine": {
    "current_state": "active",
    "trip_id": "auto_20241002_143022_123",
    "state_duration_seconds": 120.5,
    "speed_kmh": 9.0,
    "state_changed": true
  },
  "processed_sensor_data": {
    "speed_kmh": 9.0,
    "activity_type": "in_vehicle",
    "is_moving": true,
    "movement_confidence": 0.85,
    "location_quality": "good"
  }
}
```

#### 2. Manual Trip Control

```http
POST /api/v1/trip-recording/trip/start
POST /api/v1/trip-recording/trip/stop
```

#### 3. Get Trip State

```http
GET /api/v1/trip-recording/trip/state
```

#### 4. Add GPS Point

```http
POST /api/v1/trip-recording/gps-point
```

#### 5. Update Configuration

```http
PUT /api/v1/trip-recording/config
```

#### 6. Trip Analysis

```http
GET /api/v1/trip-recording/analytics/trip/{trip_id}
```

#### 7. System Status

```http
GET /api/v1/trip-recording/status/all
```

## 🔄 System Integration

### Module Interaction Flow

```
[Mobile App]
    ↓ (sensor data)
[Sensor Processor]
    ↓ (validated data)
[Trip State Machine]
    ↓ (start/stop commands)
[Route Recorder]
    ↓ (trip data)
[Database]
    ↓ (analysis request)
[ML Backend]
```

### Data Flow Pipeline

1. **Mobile Device** sends sensor data (GPS, activity, motion)
2. **Sensor Processor** validates and processes raw data
3. **Trip State Machine** evaluates state transitions
4. **Route Recorder** collects GPS points during active trips
5. **ML Backend** analyzes completed trips for insights
6. **Database** stores all trip data and metadata

## 🚀 Scalability Features

### 1. Per-User Isolation

- Each user has independent state machine instance
- Concurrent trip recording for multiple users
- User-specific configuration and patterns

### 2. Asynchronous Processing

- Background GPS collection tasks
- Non-blocking sensor data processing
- Batch database operations

### 3. Configurable Thresholds

- Speed thresholds for trip detection
- GPS accuracy filtering
- Collection intervals and batch sizes

### 4. Modular Architecture

- Independent modules with clear interfaces
- Easy to replace/upgrade individual components
- Plugin-style ML model integration

### 5. Resource Management

- Automatic cleanup of inactive users
- Memory-efficient data structures
- Connection pooling for database operations

## 📊 Database Schema Integration

The system integrates with existing Supabase schema:

### Tables Used:

- `trips` - Trip metadata and summary
- `locations` - Individual GPS points
- `users` - User profiles and preferences

### Data Relationships:

```sql
users (1) → (many) trips
trips (1) → (many) locations
```

## 🔧 Configuration Options

### Trip Detection Config

```python
TripConfig(
    speed_threshold_kmh=3.0,           # Speed to trigger trip start
    duration_threshold_seconds=60,      # Time above speed to start trip
    stop_duration_threshold_seconds=60, # Time below speed to stop trip
    gps_collection_interval_seconds=45  # GPS collection frequency
)
```

### Sensor Processing Config

```python
{
    "max_accuracy_threshold": 100,    # Max GPS accuracy (meters)
    "max_speed_kmh": 200,            # Max realistic speed
    "min_confidence_threshold": 0.3,  # Min activity confidence
    "speed_smoothing_window": 5,     # Speed averaging window
    "location_smoothing_window": 3   # Location averaging window
}
```

### Route Recording Config

```python
{
    "gps_collection_interval": 45,    # GPS collection interval (seconds)
    "max_accuracy_threshold": 50,     # GPS accuracy filter (meters)
    "min_distance_filter": 10,        # Minimum distance between points (meters)
    "enable_snap_to_roads": True,     # Enable road snapping
    "batch_size": 100                 # GPS points per batch save
}
```

## 🧪 Testing and Validation

### Unit Tests

- State machine transitions
- Sensor data validation
- GPS distance calculations
- ML feature extraction

### Integration Tests

- End-to-end sensor processing pipeline
- Database operations
- API endpoint functionality

### Performance Tests

- Concurrent user handling
- Memory usage under load
- Database query performance

## 🔐 Security Considerations

### Authentication

- JWT token validation for all endpoints
- User-scoped data access
- Rate limiting on sensor data endpoints

### Data Privacy

- User data isolation
- Automatic data cleanup options
- Configurable data retention policies

### Input Validation

- GPS coordinate bounds checking
- Speed and accuracy thresholds
- Activity confidence validation

## 📈 Monitoring and Observability

### Metrics to Track

- Active trips count
- Sensor data processing rate
- State transition frequency
- GPS point collection rate
- ML analysis accuracy

### Logging

- State machine transitions
- Route recording start/stop events
- Sensor data validation failures
- ML analysis results

### Health Checks

- System component status
- Database connectivity
- Active user sessions
- Background task status

## 🚀 Deployment Guide

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements-working.txt
```

### 2. Configure Environment

```bash
cp env.example .env
# Update with your Supabase credentials
```

### 3. Initialize System

```python
from app.modules.trip_system_integration import initialize_trip_system
from app.database import db_service

# Initialize the trip recording system
trip_system = initialize_trip_system(db_service)
await trip_system.initialize()
```

### 4. Run API Server

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 5. Test System

```bash
# Check API documentation
curl http://localhost:8000/docs

# Test health endpoint
curl http://localhost:8000/health
```

## 📱 Mobile App Integration

### 1. Authentication

```dart
// Get Supabase JWT token
final token = supabase.auth.currentSession?.accessToken;
```

### 2. Send Sensor Data

```dart
final response = await http.post(
  'http://your-backend:8000/api/v1/trip-recording/sensor-data',
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'latitude': position.latitude,
    'longitude': position.longitude,
    'accuracy': position.accuracy,
    'speed_mps': position.speed,
    'activity_type': activityType,
    'activity_confidence': confidence,
  }),
);
```

### 3. Handle Response

```dart
final data = jsonDecode(response.body);
if (data['success']) {
  final tripState = data['state_machine']['current_state'];
  final tripId = data['state_machine']['trip_id'];

  // Update UI based on trip state
  if (tripState == 'active') {
    showTripActiveUI(tripId);
  } else {
    showTripIdleUI();
  }
}
```

## 🎯 Future Enhancements

### 1. Advanced ML Models

- Replace rule-based classifier with trained models
- LSTM networks for sequence prediction
- Real-time model updates based on user feedback

### 2. Enhanced Sensor Fusion

- Magnetometer for improved bearing detection
- Barometer for altitude-based transport mode detection
- WiFi/Bluetooth beacons for indoor positioning

### 3. Smart Trip Segmentation

- Automatic trip chaining detection
- Multi-modal trip support (walk + bus + walk)
- Purpose prediction based on destinations

### 4. Performance Optimizations

- Redis caching for frequently accessed data
- Message queues for high-volume sensor data
- Horizontal scaling with load balancers

This Trip Recording System provides a robust, scalable foundation for mobile trip tracking with automatic detection and comprehensive route recording capabilities.


