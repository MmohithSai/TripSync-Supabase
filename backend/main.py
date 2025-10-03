"""
FastAPI Backend for Location Tracker App
Uses Supabase for data storage and authentication
"""

import os
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import uvicorn
from dotenv import load_dotenv

from app.config import settings
from app.database import supabase_client
from app.routers import trips, locations, analytics, users, trip_recording
from app.middleware.auth import verify_token

# Load environment variables
load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    # Startup
    print("Starting Location Tracker API...")
    print(f"Connected to Supabase: {settings.SUPABASE_URL}")
    yield
    # Shutdown
    print("Shutting down Location Tracker API...")


# Create FastAPI app
app = FastAPI(
    title="Location Tracker API",
    description="Python backend for Location Tracker App using Supabase",
    version="1.0.0",
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

# Include routers
app.include_router(trips.router, prefix="/api/v1/trips", tags=["trips"])
app.include_router(locations.router, prefix="/api/v1/locations", tags=["locations"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["analytics"])
app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
app.include_router(
    trip_recording.router, prefix="/api/v1/trip-recording", tags=["trip-recording"]
)


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "Location Tracker API is running",
        "version": "1.0.0",
        "status": "healthy",
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    try:
        # Test Supabase connection
        response = (
            supabase_client.table("users").select("count", count="exact").execute()
        )

        return {
            "status": "healthy",
            "database": "connected",
            "users_count": response.count,
            "version": "1.0.0",
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Service unhealthy: {str(e)}",
        )


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.DEBUG,
    )
