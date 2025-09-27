import 'dart:io';
import '../features/trips/domain/trip_models.dart';

class TimezoneUtils {
  /// Get the current timezone offset in minutes
  static int getCurrentTimezoneOffsetMinutes() {
    final now = DateTime.now();
    return now.timeZoneOffset.inMinutes;
  }

  /// Create a UTC DateTime with timezone offset information
  static DateTime createUtcDateTime(DateTime localDateTime) {
    // Convert local time to UTC
    return localDateTime.toUtc();
  }

  /// Convert UTC DateTime back to local time using stored offset
  static DateTime utcToLocal(DateTime utcDateTime, int timezoneOffsetMinutes) {
    return utcDateTime.add(Duration(minutes: timezoneOffsetMinutes));
  }

  /// Get timezone name (e.g., "America/New_York")
  static String getCurrentTimezoneName() {
    final now = DateTime.now();
    return now.timeZoneName;
  }

  /// Check if daylight saving time is currently active
  static bool isDaylightSavingTime() {
    final now = DateTime.now();
    final january = DateTime(now.year, 1, 1);
    final july = DateTime(now.year, 7, 1);
    
    // Compare timezone offsets in January and July
    // If they're different, DST is in effect
    return january.timeZoneOffset != july.timeZoneOffset;
  }

  /// Format timestamp for display with timezone info
  static String formatTimestampWithTimezone(DateTime utcDateTime, int timezoneOffsetMinutes) {
    final localDateTime = utcToLocal(utcDateTime, timezoneOffsetMinutes);
    final offsetHours = timezoneOffsetMinutes ~/ 60;
    final offsetMinutes = timezoneOffsetMinutes % 60;
    final offsetSign = timezoneOffsetMinutes >= 0 ? '+' : '-';
    
    return '${localDateTime.toIso8601String()} (UTC${offsetSign}${offsetHours.toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')})';
  }

  /// Create a TripPoint with proper timezone handling
  static TripPoint createTripPoint({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) {
    final utcTimestamp = timestamp.toUtc();
    final timezoneOffset = timestamp.timeZoneOffset.inMinutes;
    
    return TripPoint(
      latitude: latitude,
      longitude: longitude,
      timestamp: utcTimestamp,
      timezoneOffsetMinutes: timezoneOffset,
    );
  }

  /// Create a TripSummary with proper timezone handling
  static TripSummary createTripSummary({
    required String id,
    required DateTime startedAt,
    required DateTime? endedAt,
    required double distanceMeters,
    required TripMode mode,
    required TripPurpose purpose,
    required Companions companions,
    bool isRecurring = false,
    String? destinationRegion,
    String? originRegion,
    String? tripNumber,
    String? chainId,
  }) {
    final timezoneOffset = startedAt.timeZoneOffset.inMinutes;
    
    return TripSummary(
      id: id,
      startedAt: startedAt.toUtc(),
      endedAt: endedAt?.toUtc(),
      distanceMeters: distanceMeters,
      mode: mode,
      purpose: purpose,
      companions: companions,
      isRecurring: isRecurring,
      destinationRegion: destinationRegion,
      originRegion: originRegion,
      tripNumber: tripNumber,
      chainId: chainId,
      timezoneOffsetMinutes: timezoneOffset,
    );
  }
}

