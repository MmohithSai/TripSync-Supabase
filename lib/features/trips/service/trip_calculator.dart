import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/trip_models.dart';

class TripCalculator {
  // CO2 emission factors (kg CO2 per km per person)
  static const Map<TripMode, double> co2Factors = {
    TripMode.walk: 0.0,
    TripMode.bicycle: 0.0,
    TripMode.car: 0.192, // Average car emissions
    TripMode.bus: 0.089, // Public bus emissions
    TripMode.train: 0.041, // Train emissions
    TripMode.metro: 0.041, // Metro/subway emissions
    TripMode.scooter: 0.0, // Electric scooter
    TripMode.unknown: 0.1, // Default assumption
  };

  // Fuel consumption rates (liters per 100km)
  static const Map<TripMode, double> fuelConsumption = {
    TripMode.car: 7.0, // Average car fuel consumption
    TripMode.scooter: 0.0, // Electric
    TripMode.unknown: 0.0,
  };

  // Base fare rates (per km)
  static const Map<TripMode, double> baseFareRates = {
    TripMode.bus: 0.5, // Base bus fare per km
    TripMode.train: 0.3, // Base train fare per km
    TripMode.metro: 0.4, // Base metro fare per km
    TripMode.unknown: 0.0,
  };

  static Future<double> getCurrentFuelPrice() async {
    try {
      // Using a free fuel price API (you may need to replace with a more reliable one)
      final response = await http.get(
        Uri.parse('https://api.collectapi.com/gasPrice/fromCoordinates?lng=77.612441&lat=12.920331'),
        headers: {
          'authorization': 'apikey YOUR_API_KEY', // Replace with actual API key
          'content-type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Extract fuel price from response (adjust based on actual API response)
        return (data['result']?['gasoline'] ?? 100.0).toDouble();
      }
    } catch (e) {
      print('Error fetching fuel price: $e');
    }
    
    // Fallback to average fuel price in India (in INR per liter)
    return 100.0;
  }

  static Future<double> getBusFareRate() async {
    try {
      // Using a public transport API (replace with actual API)
      final response = await http.get(
        Uri.parse('https://api.example.com/transport/fares'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['bus_fare_per_km'] ?? 0.5).toDouble();
      }
    } catch (e) {
      print('Error fetching bus fare: $e');
    }
    
    // Fallback rate
    return 0.5;
  }

  static double calculateCO2Savings(TripSummary trip) {
    final distanceKm = trip.distanceMeters / 1000;
    final co2Factor = co2Factors[trip.mode] ?? 0.1;
    final passengers = 1 + (trip.companions.adults + trip.companions.children + trip.companions.seniors);
    
    // Calculate CO2 emissions for this trip
    final tripCO2 = distanceKm * co2Factor * passengers;
    
    // Compare with car emissions (baseline)
    final carCO2 = distanceKm * co2Factors[TripMode.car]! * passengers;
    
    return (carCO2 - tripCO2).clamp(0.0, double.infinity);
  }

  static Future<double> calculateCost(TripSummary trip) async {
    final distanceKm = trip.distanceMeters / 1000;
    final passengers = 1 + (trip.companions.adults + trip.companions.children + trip.companions.seniors);
    
    switch (trip.mode) {
      case TripMode.car:
        final fuelPrice = await getCurrentFuelPrice();
        final consumption = fuelConsumption[trip.mode] ?? 0.0;
        return distanceKm * (consumption / 100) * fuelPrice;
        
      case TripMode.bus:
        final fareRate = await getBusFareRate();
        return distanceKm * fareRate * passengers;
        
      case TripMode.train:
      case TripMode.metro:
        final fareRate = baseFareRates[trip.mode] ?? 0.0;
        return distanceKm * fareRate * passengers;
        
      case TripMode.walk:
      case TripMode.bicycle:
      case TripMode.scooter:
        return 0.0; // No cost for these modes
        
      case TripMode.unknown:
        return 0.0;
    }
  }

  static String formatCO2(double co2Kg) {
    if (co2Kg < 1) {
      return '${(co2Kg * 1000).toStringAsFixed(0)}g CO₂';
    }
    return '${co2Kg.toStringAsFixed(2)}kg CO₂';
  }

  static String formatCost(double cost) {
    return '₹${cost.toStringAsFixed(2)}';
  }

  static String getEnvironmentalImpact(double co2Savings) {
    if (co2Savings < 0.1) {
      return 'Minimal impact';
    } else if (co2Savings < 1.0) {
      return 'Good choice!';
    } else if (co2Savings < 5.0) {
      return 'Great for the environment!';
    } else {
      return 'Excellent environmental choice! 🌱';
    }
  }
}









