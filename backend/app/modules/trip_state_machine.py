"""
Trip State Machine - The Brain of the Trip Recording System

Manages trip lifecycle: Idle → Active → Idle
Controls the Route Recording module based on state transitions
"""

from enum import Enum
from typing import Dict, Any, Optional, Callable
from datetime import datetime, timedelta
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)


class TripState(Enum):
    """Trip states"""

    IDLE = "idle"
    ACTIVE = "active"


@dataclass
class TripConfig:
    """Configuration for trip detection thresholds"""

    speed_threshold_kmh: float = 3.0  # Speed threshold in km/h
    duration_threshold_seconds: int = 60  # Duration threshold in seconds
    stop_duration_threshold_seconds: int = 60  # Stop duration threshold
    gps_collection_interval_seconds: int = 45  # GPS collection interval


@dataclass
class SensorData:
    """Mobile sensor data input"""

    speed_kmh: float
    latitude: float
    longitude: float
    accuracy: float
    timestamp: datetime
    activity_type: Optional[str] = None  # walking, in_vehicle, still, etc.


@dataclass
class TripContext:
    """Current trip context and state"""

    trip_id: Optional[str] = None
    current_state: TripState = TripState.IDLE
    state_start_time: Optional[datetime] = None
    last_sensor_data: Optional[SensorData] = None
    speed_above_threshold_start: Optional[datetime] = None
    speed_below_threshold_start: Optional[datetime] = None


class TripStateMachine:
    """
    Trip State Machine - Controls trip lifecycle

    The brain of the system that determines when trips start and stop
    based on sensor inputs and user actions.
    """

    def __init__(self, config: TripConfig = None):
        self.config = config or TripConfig()
        self.context = TripContext()

        # Callbacks for route recorder control
        self.on_trip_start: Optional[Callable[[str], None]] = None
        self.on_trip_stop: Optional[Callable[[str], None]] = None

        # State transition handlers
        self._state_handlers = {
            TripState.IDLE: self._handle_idle_state,
            TripState.ACTIVE: self._handle_active_state,
        }

    def set_route_recorder_callbacks(
        self, on_start: Callable[[str], None], on_stop: Callable[[str], None]
    ):
        """Set callbacks to control the Route Recorder"""
        self.on_trip_start = on_start
        self.on_trip_stop = on_stop

    def manual_start_trip(self, user_id: str) -> str:
        """
        Manual trip start triggered by user button press
        Returns trip_id
        """
        if self.context.current_state == TripState.ACTIVE:
            logger.warning("Trip already active, ignoring manual start")
            return self.context.trip_id

        trip_id = self._generate_trip_id(user_id)
        self._transition_to_active(trip_id, trigger="manual")
        return trip_id

    def manual_stop_trip(self) -> bool:
        """
        Manual trip stop triggered by user button press
        Returns True if trip was stopped, False if no active trip
        """
        if self.context.current_state != TripState.ACTIVE:
            logger.warning("No active trip to stop")
            return False

        self._transition_to_idle(trigger="manual")
        return True

    def process_sensor_data(self, sensor_data: SensorData) -> Dict[str, Any]:
        """
        Process incoming sensor data and handle state transitions

        Args:
            sensor_data: Latest sensor readings

        Returns:
            Dict with current state and any state changes
        """
        self.context.last_sensor_data = sensor_data

        # Process current state
        current_handler = self._state_handlers[self.context.current_state]
        result = current_handler(sensor_data)

        return {
            "current_state": self.context.current_state.value,
            "trip_id": self.context.trip_id,
            "state_duration_seconds": self._get_state_duration_seconds(),
            "speed_kmh": sensor_data.speed_kmh,
            "activity_type": sensor_data.activity_type,
            **result,
        }

    def get_current_state(self) -> Dict[str, Any]:
        """Get current trip state information"""
        return {
            "state": self.context.current_state.value,
            "trip_id": self.context.trip_id,
            "state_start_time": self.context.state_start_time.isoformat()
            if self.context.state_start_time
            else None,
            "state_duration_seconds": self._get_state_duration_seconds(),
            "last_sensor_update": self.context.last_sensor_data.timestamp.isoformat()
            if self.context.last_sensor_data
            else None,
        }

    def _handle_idle_state(self, sensor_data: SensorData) -> Dict[str, Any]:
        """Handle sensor data when in IDLE state"""
        result = {"state_changed": False}

        # Check if speed is above threshold
        if sensor_data.speed_kmh >= self.config.speed_threshold_kmh:
            if self.context.speed_above_threshold_start is None:
                self.context.speed_above_threshold_start = sensor_data.timestamp
                logger.info(
                    f"Speed above threshold ({sensor_data.speed_kmh} km/h), starting timer"
                )
            else:
                # Check if duration threshold is met
                duration = (
                    sensor_data.timestamp - self.context.speed_above_threshold_start
                ).total_seconds()
                if duration >= self.config.duration_threshold_seconds:
                    # Transition to ACTIVE
                    trip_id = self._generate_trip_id("auto")
                    self._transition_to_active(trip_id, trigger="automatic")
                    result["state_changed"] = True
                    result["trigger"] = "speed_duration_threshold"
        else:
            # Reset speed above threshold timer
            if self.context.speed_above_threshold_start is not None:
                logger.info("Speed dropped below threshold, resetting timer")
                self.context.speed_above_threshold_start = None

        return result

    def _handle_active_state(self, sensor_data: SensorData) -> Dict[str, Any]:
        """Handle sensor data when in ACTIVE state"""
        result = {"state_changed": False}

        # Check if speed is below threshold
        if sensor_data.speed_kmh < self.config.speed_threshold_kmh:
            if self.context.speed_below_threshold_start is None:
                self.context.speed_below_threshold_start = sensor_data.timestamp
                logger.info(
                    f"Speed below threshold ({sensor_data.speed_kmh} km/h), starting stop timer"
                )
            else:
                # Check if stop duration threshold is met
                duration = (
                    sensor_data.timestamp - self.context.speed_below_threshold_start
                ).total_seconds()
                if duration >= self.config.stop_duration_threshold_seconds:
                    # Transition to IDLE
                    self._transition_to_idle(trigger="automatic")
                    result["state_changed"] = True
                    result["trigger"] = "stop_duration_threshold"
        else:
            # Reset speed below threshold timer
            if self.context.speed_below_threshold_start is not None:
                logger.info("Speed increased above threshold, resetting stop timer")
                self.context.speed_below_threshold_start = None

        return result

    def _transition_to_active(self, trip_id: str, trigger: str):
        """Transition to ACTIVE state"""
        logger.info(
            f"Transitioning to ACTIVE state (trigger: {trigger}), trip_id: {trip_id}"
        )

        self.context.current_state = TripState.ACTIVE
        self.context.trip_id = trip_id
        self.context.state_start_time = datetime.now()
        self.context.speed_above_threshold_start = None
        self.context.speed_below_threshold_start = None

        # Notify Route Recorder to start
        if self.on_trip_start:
            try:
                self.on_trip_start(trip_id)
                logger.info(f"Route recording started for trip {trip_id}")
            except Exception as e:
                logger.error(f"Failed to start route recording: {e}")

    def _transition_to_idle(self, trigger: str):
        """Transition to IDLE state"""
        trip_id = self.context.trip_id
        logger.info(
            f"Transitioning to IDLE state (trigger: {trigger}), trip_id: {trip_id}"
        )

        # Notify Route Recorder to stop
        if self.on_trip_stop and trip_id:
            try:
                self.on_trip_stop(trip_id)
                logger.info(f"Route recording stopped for trip {trip_id}")
            except Exception as e:
                logger.error(f"Failed to stop route recording: {e}")

        self.context.current_state = TripState.IDLE
        self.context.trip_id = None
        self.context.state_start_time = datetime.now()
        self.context.speed_above_threshold_start = None
        self.context.speed_below_threshold_start = None

    def _generate_trip_id(self, prefix: str) -> str:
        """Generate unique trip ID"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
        return f"{prefix}_{timestamp}"

    def _get_state_duration_seconds(self) -> float:
        """Get duration of current state in seconds"""
        if self.context.state_start_time:
            return (datetime.now() - self.context.state_start_time).total_seconds()
        return 0.0


class TripStateMachineManager:
    """
    Manager for multiple user trip state machines
    Handles per-user state machine instances
    """

    def __init__(self):
        self._user_machines: Dict[str, TripStateMachine] = {}
        self._config = TripConfig()

    def get_machine(self, user_id: str) -> TripStateMachine:
        """Get or create trip state machine for user"""
        if user_id not in self._user_machines:
            machine = TripStateMachine(self._config)
            self._user_machines[user_id] = machine
            logger.info(f"Created new trip state machine for user {user_id}")

        return self._user_machines[user_id]

    def remove_machine(self, user_id: str):
        """Remove trip state machine for user"""
        if user_id in self._user_machines:
            del self._user_machines[user_id]
            logger.info(f"Removed trip state machine for user {user_id}")

    def get_all_active_trips(self) -> Dict[str, Dict[str, Any]]:
        """Get all currently active trips across all users"""
        active_trips = {}
        for user_id, machine in self._user_machines.items():
            if machine.context.current_state == TripState.ACTIVE:
                active_trips[user_id] = machine.get_current_state()
        return active_trips

    def update_config(self, config: TripConfig):
        """Update configuration for all machines"""
        self._config = config
        for machine in self._user_machines.values():
            machine.config = config
        logger.info("Updated configuration for all trip state machines")


# Global instance
trip_state_manager = TripStateMachineManager()


