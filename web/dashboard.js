// Configuration
const API_BASE_URL = 'https://us-central1-location-tracker-b045b.cloudfunctions.net';

// Global variables
let tripData = [];
let map;
let tripChart;
let modeChart;

// Initialize the dashboard
document.addEventListener('DOMContentLoaded', function () {
    // Set default date range (last 7 days)
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 7);

    document.getElementById('endDate').value = endDate.toISOString().split('T')[0];
    document.getElementById('startDate').value = startDate.toISOString().split('T')[0];

    // Initialize map
    initMap();

    // Load initial data
    loadData();
});

function initMap() {
    map = L.map('map').setView([40.7128, -74.0060], 10);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
    }).addTo(map);
}

async function loadData() {
    const startDate = document.getElementById('startDate').value;
    const endDate = document.getElementById('endDate').value;

    if (!startDate || !endDate) {
        showError('Please select both start and end dates');
        return;
    }

    showLoading(true);
    hideError();

    try {
        const response = await fetch(`${API_BASE_URL}/exportTripsManual`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                startDate: startDate,
                endDate: endDate
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();

        if (data.success) {
            tripData = data.trips || [];
            updateDashboard();
            showContent(true);
        } else {
            throw new Error(data.error || 'Failed to load data');
        }
    } catch (error) {
        console.error('Error loading data:', error);
        showError(`Failed to load data: ${error.message}`);
    } finally {
        showLoading(false);
    }
}

function updateDashboard() {
    updateStats();
    updateTripChart();
    updateModeChart();
    updateMap();
}

function updateStats() {
    const totalTrips = tripData.length;
    const totalDistance = tripData.reduce((sum, trip) => sum + (trip.distanceMeters || 0), 0) / 1000;
    const avgDistance = totalTrips > 0 ? totalDistance / totalTrips : 0;

    // Calculate CO2 savings (simplified calculation)
    const co2Saved = tripData.reduce((sum, trip) => {
        const co2PerKm = {
            'car': 0.2,
            'bus': 0.05,
            'train': 0.03,
            'metro': 0.03,
            'scooter': 0.01,
            'bicycle': 0,
            'walk': 0
        };
        return sum + ((trip.distanceMeters || 0) / 1000) * (co2PerKm[trip.mode] || 0);
    }, 0);

    document.getElementById('totalTrips').textContent = totalTrips;
    document.getElementById('totalDistance').textContent = totalDistance.toFixed(1) + ' km';
    document.getElementById('avgDistance').textContent = avgDistance.toFixed(1) + ' km';
    document.getElementById('co2Saved').textContent = co2Saved.toFixed(1) + ' kg';
}

function updateTripChart() {
    const ctx = document.getElementById('tripChart').getContext('2d');

    // Group trips by date
    const tripsByDate = {};
    tripData.forEach(trip => {
        const date = new Date(trip.startTimeUTC).toISOString().split('T')[0];
        tripsByDate[date] = (tripsByDate[date] || 0) + 1;
    });

    const dates = Object.keys(tripsByDate).sort();
    const counts = dates.map(date => tripsByDate[date]);

    if (tripChart) {
        tripChart.destroy();
    }

    tripChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: dates,
            datasets: [{
                label: 'Trips',
                data: counts,
                borderColor: '#1976d2',
                backgroundColor: 'rgba(25, 118, 210, 0.1)',
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });
}

function updateModeChart() {
    const ctx = document.getElementById('modeChart').getContext('2d');

    // Count trips by mode
    const modeCounts = {};
    tripData.forEach(trip => {
        modeCounts[trip.mode] = (modeCounts[trip.mode] || 0) + 1;
    });

    const modes = Object.keys(modeCounts);
    const counts = Object.values(modeCounts);
    const colors = [
        '#1976d2', '#388e3c', '#f57c00', '#d32f2f',
        '#7b1fa2', '#00796b', '#5d4037', '#455a64'
    ];

    if (modeChart) {
        modeChart.destroy();
    }

    modeChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: modes,
            datasets: [{
                data: counts,
                backgroundColor: colors.slice(0, modes.length),
                borderWidth: 2,
                borderColor: '#fff'
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: {
                    position: 'bottom'
                }
            }
        }
    });
}

function updateMap() {
    // Clear existing markers
    map.eachLayer(layer => {
        if (layer instanceof L.Marker || layer instanceof L.CircleMarker) {
            map.removeLayer(layer);
        }
    });

    // Add markers for origins and destinations
    const origins = new Map();
    const destinations = new Map();

    tripData.forEach(trip => {
        if (trip.originRegion) {
            const count = origins.get(trip.originRegion) || 0;
            origins.set(trip.originRegion, count + 1);
        }
        if (trip.destinationRegion) {
            const count = destinations.get(trip.destinationRegion) || 0;
            destinations.set(trip.destinationRegion, count + 1);
        }
    });

    // Add origin markers (red)
    origins.forEach((count, region) => {
        const lat = 40.7128 + (Math.random() - 0.5) * 0.1;
        const lng = -74.0060 + (Math.random() - 0.5) * 0.1;

        L.circleMarker([lat, lng], {
            radius: Math.min(count * 2, 20),
            color: '#d32f2f',
            fillColor: '#d32f2f',
            fillOpacity: 0.6
        }).addTo(map).bindPopup(`Origin: ${region} (${count} trips)`);
    });

    // Add destination markers (blue)
    destinations.forEach((count, region) => {
        const lat = 40.7128 + (Math.random() - 0.5) * 0.1;
        const lng = -74.0060 + (Math.random() - 0.5) * 0.1;

        L.circleMarker([lat, lng], {
            radius: Math.min(count * 2, 20),
            color: '#1976d2',
            fillColor: '#1976d2',
            fillOpacity: 0.6
        }).addTo(map).bindPopup(`Destination: ${region} (${count} trips)`);
    });
}

function exportData() {
    if (tripData.length === 0) {
        alert('No data to export');
        return;
    }

    // Convert to CSV
    const headers = ['tripId', 'userHash', 'startTimeUTC', 'endTimeUTC', 'originRegion', 'destinationRegion', 'mode', 'distanceMeters', 'durationSeconds'];
    const csvContent = [
        headers.join(','),
        ...tripData.map(trip => [
            trip.tripId,
            trip.userHash,
            trip.startTimeUTC,
            trip.endTimeUTC || '',
            trip.originRegion || '',
            trip.destinationRegion || '',
            trip.mode,
            trip.distanceMeters || 0,
            trip.durationSeconds || 0
        ].join(','))
    ].join('\n');

    // Download CSV
    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `trips_${document.getElementById('startDate').value}_to_${document.getElementById('endDate').value}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
}

function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
}

function showContent(show) {
    document.getElementById('content').style.display = show ? 'block' : 'none';
}

function showError(message) {
    document.getElementById('errorMessage').textContent = message;
    document.getElementById('error').style.display = 'block';
}

function hideError() {
    document.getElementById('error').style.display = 'none';
}








