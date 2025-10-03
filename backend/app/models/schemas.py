"""
Pydantic models for API request/response schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum


class TripMode(str, Enum):
    WALK = "walk"
    BICYCLE = "bicycle"
    SCOOTER = "scooter"
    CAR = "car"
    BUS = "bus"
    TRAIN = "train"
    METRO = "metro"
    UNKNOWN = "unknown"


class TripPurpose(str, Enum):
    WORK = "work"
    HOME = "home"
    SHOPPING = "shopping"
    LEISURE = "leisure"
    EDUCATION = "education"
    HEALTHCARE = "healthcare"
    OTHER = "other"
    UNKNOWN = "unknown"


# Location Models
class LocationPoint(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy: Optional[float] = None
    timestamp_ms: int
    user_id: str


class LocationBatch(BaseModel):
    locations: List[LocationPoint]


# Trip Models
class TripCreate(BaseModel):
    start_location: Dict[str, float]  # {"lat": float, "lng": float}
    end_location: Optional[Dict[str, float]] = None
    distance_km: Optional[float] = 0.0
    duration_min: Optional[int] = 0
    mode: TripMode = TripMode.UNKNOWN
    purpose: TripPurpose = TripPurpose.UNKNOWN
    companions: Optional[Dict[str, int]] = Field(
        default_factory=lambda: {"adults": 0, "children": 0, "seniors": 0}
    )
    is_recurring: bool = False
    destination_region: Optional[str] = None
    origin_region: Optional[str] = None
    trip_number: Optional[str] = None
    chain_id: Optional[str] = None
    notes: Optional[str] = None


class TripUpdate(BaseModel):
    end_location: Optional[Dict[str, float]] = None
    distance_km: Optional[float] = None
    duration_min: Optional[int] = None
    mode: Optional[TripMode] = None
    purpose: Optional[TripPurpose] = None
    companions: Optional[Dict[str, int]] = None
    is_recurring: Optional[bool] = None
    destination_region: Optional[str] = None
    notes: Optional[str] = None


class TripResponse(BaseModel):
    id: str
    user_id: str
    start_location: Dict[str, float]
    end_location: Optional[Dict[str, float]]
    distance_km: float
    duration_min: int
    mode: str
    purpose: str
    companions: Dict[str, int]
    is_recurring: bool
    destination_region: Optional[str]
    origin_region: Optional[str]
    trip_number: Optional[str]
    chain_id: Optional[str]
    notes: Optional[str]
    timestamp: datetime
    created_at: datetime
    updated_at: datetime


# Analytics Models
class AnalyticsRequest(BaseModel):
    start_date: str  # ISO format date
    end_date: str  # ISO format date
    region: Optional[str] = None


class TripStats(BaseModel):
    total_trips: int
    total_distance_km: float
    total_duration_min: int
    avg_distance_km: float
    avg_duration_min: float
    mode_distribution: Dict[str, int]


class AnalyticsResponse(BaseModel):
    stats: TripStats
    trips: List[TripResponse]
    date_range: Dict[str, str]


# User Models
class UserProfile(BaseModel):
    id: str
    email: Optional[str]
    created_at: datetime
    updated_at: datetime


class UserStats(BaseModel):
    total_trips: int
    total_distance_km: float
    total_duration_hours: float
    most_common_mode: str
    account_age_days: int


# Response Models
class APIResponse(BaseModel):
    success: bool
    message: str
    data: Optional[Any] = None


class ErrorResponse(BaseModel):
    success: bool = False
    error: str
    detail: Optional[str] = None


