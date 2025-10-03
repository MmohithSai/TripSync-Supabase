# Location Tracker Backend API

A Python FastAPI backend for the Location Tracker mobile app, using Supabase for data storage and authentication.

## Features

- **FastAPI** - Modern, fast web framework for building APIs
- **Supabase Integration** - PostgreSQL database with real-time capabilities
- **JWT Authentication** - Secure authentication using Supabase JWT tokens
- **RESTful API** - Clean, well-documented API endpoints
- **Data Analytics** - Trip analysis, carbon footprint calculation, and reporting
- **Batch Processing** - Efficient handling of location data batches

## Project Structure

```
backend/
├── app/
│   ├── middleware/          # Authentication middleware
│   ├── models/             # Pydantic schemas
│   ├── routers/            # API route handlers
│   ├── services/           # Business logic services
│   ├── config.py           # Configuration settings
│   └── database.py         # Supabase client setup
├── main.py                 # FastAPI application entry point
├── requirements.txt        # Python dependencies
└── README.md              # This file
```

## Setup

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Environment Configuration

Copy `env.example` to `.env` and update with your values:

```bash
cp env.example .env
```

Required environment variables:

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key (for admin operations)
- `SUPABASE_ANON_KEY` - Supabase anonymous key (for client operations)

### 3. Run the API

```bash
# Development mode with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

## API Documentation

Once running, visit:

- **Interactive API docs**: `http://localhost:8000/docs`
- **ReDoc documentation**: `http://localhost:8000/redoc`

## API Endpoints

### Authentication

All endpoints (except health checks) require a valid Supabase JWT token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Core Endpoints

#### Trips

- `POST /api/v1/trips/` - Create a new trip
- `GET /api/v1/trips/` - Get user's trips (with pagination)
- `GET /api/v1/trips/{trip_id}` - Get specific trip
- `PUT /api/v1/trips/{trip_id}` - Update trip
- `DELETE /api/v1/trips/{trip_id}` - Delete trip
- `POST /api/v1/trips/batch` - Create multiple trips

#### Locations

- `POST /api/v1/locations/` - Save location point
- `POST /api/v1/locations/batch` - Save location batch
- `GET /api/v1/locations/recent` - Get recent locations
- `DELETE /api/v1/locations/cleanup` - Clean up old locations

#### Analytics

- `GET /api/v1/analytics/dashboard` - Dashboard analytics
- `GET /api/v1/analytics/mode-distribution` - Transportation mode analysis
- `GET /api/v1/analytics/carbon-footprint` - Carbon footprint calculation
- `GET /api/v1/analytics/heatmap` - Location heatmap data
- `GET /api/v1/analytics/export` - Export trip data

#### Users

- `GET /api/v1/users/profile` - Get user profile
- `PUT /api/v1/users/profile` - Update user profile
- `GET /api/v1/users/stats` - Get user statistics
- `DELETE /api/v1/users/account` - Delete user account

## Data Models

### Trip

```json
{
  "start_location": { "lat": 17.385, "lng": 78.4867 },
  "end_location": { "lat": 17.4474, "lng": 78.3569 },
  "distance_km": 12.5,
  "duration_min": 25,
  "mode": "car",
  "purpose": "work",
  "companions": { "adults": 1, "children": 0, "seniors": 0 },
  "notes": "Traffic was heavy"
}
```

### Location Point

```json
{
  "latitude": 17.385,
  "longitude": 78.4867,
  "accuracy": 5.0,
  "timestamp_ms": 1640995200000
}
```

## Integration with Flutter App

The Flutter app should:

1. **Authenticate** with Supabase to get JWT token
2. **Include JWT token** in all API requests
3. **Use batch endpoints** for efficient data sync
4. **Handle offline scenarios** by queuing requests

### Example Flutter Integration

```dart
// Configure API client
final apiClient = ApiClient(
  baseUrl: 'http://your-backend-url/api/v1',
  token: supabaseToken,
);

// Save trip
await apiClient.post('/trips/', data: tripData);

// Get analytics
final analytics = await apiClient.get('/analytics/dashboard',
  params: {'start_date': '2024-01-01', 'end_date': '2024-01-31'});
```

## Deployment

### Docker Deployment

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Environment Variables for Production

```bash
# Production settings
DEBUG=False
API_HOST=0.0.0.0
API_PORT=8000

# Security
JWT_SECRET_KEY=your-production-secret-key

# Database
SUPABASE_URL=your-production-supabase-url
SUPABASE_SERVICE_ROLE_KEY=your-production-service-key
```

## Development

### Adding New Endpoints

1. Create route handler in `app/routers/`
2. Add business logic in `app/services/`
3. Define Pydantic models in `app/models/schemas.py`
4. Include router in `main.py`

### Testing

```bash
# Install test dependencies
pip install pytest httpx

# Run tests
pytest
```

## Contributing

1. Follow PEP 8 style guidelines
2. Add type hints to all functions
3. Include docstrings for classes and methods
4. Update API documentation for new endpoints
5. Add appropriate error handling and logging


