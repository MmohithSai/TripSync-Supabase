"""
Configuration settings for the Location Tracker API
"""

import os
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Supabase Configuration
    SUPABASE_URL: str = "https://ixlgntiqgfmsvuqahbnd.supabase.co"
    SUPABASE_SERVICE_ROLE_KEY: str = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGdudGlxZ2Ztc3Z1cWFoYm5kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODk4NzM0MCwiZXhwIjoyMDc0NTYzMzQwfQ.v9pAc3ax0E0zAZMTq2yEmRjEnHlVk-ryTil4PkFzn7o"
    SUPABASE_ANON_KEY: str = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4bGdudGlxZ2Ztc3Z1cWFoYm5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5ODczNDAsImV4cCI6MjA3NDU2MzM0MH0.qJjPMJNhfWECdHKJCNJGqjGmhQIlqJjPMJNhfWECdHK"

    # API Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    DEBUG: bool = True

    # Security
    JWT_SECRET_KEY: str = "your-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_HOURS: int = 24

    # External APIs
    GOOGLE_MAPS_API_KEY: Optional[str] = None

    # Processing Configuration
    BATCH_SIZE: int = 1000
    MAX_WORKERS: int = 4

    model_config = {"env_file": ".env", "extra": "allow"}


# Global settings instance
settings = Settings()
