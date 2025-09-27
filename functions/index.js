const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const csv = require('csv-writer');
const fs = require('fs');
const path = require('path');
const os = require('os');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Google Cloud Storage
const storage = new Storage();

// Get environment variables
const BUCKET_NAME = process.env.STORAGE_BUCKET || 'your-storage-bucket';
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'your-project-id';

/**
 * Nightly trip export function - runs at 2 AM UTC daily
 * 🔥 REQUIRES FIREBASE BLAZE PLAN - Cloud Functions and Cloud Storage
 */
exports.exportTripsNightly = functions.pubsub
    .schedule('0 2 * * *') // 2 AM UTC daily
    .timeZone('UTC')
    .onRun(async (context) => {
        console.log('Starting nightly trip export...');

        try {
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 1);
            const startOfDay = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate());
            const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);

            console.log(`Exporting trips from ${startOfDay.toISOString()} to ${endOfDay.toISOString()}`);

            // Get all trips from yesterday
            const tripsSnapshot = await admin.firestore()
                .collectionGroup('trips')
                .where('startedAt', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
                .where('startedAt', '<', admin.firestore.Timestamp.fromDate(endOfDay))
                .get();

            if (tripsSnapshot.empty) {
                console.log('No trips found for export');
                return { message: 'No trips to export' };
            }

            console.log(`Found ${tripsSnapshot.size} trips to export`);

            // Process and anonymize trips
            const anonymizedTrips = await processAndAnonymizeTrips(tripsSnapshot);

            // Generate CSV export
            const csvData = await generateCSVExport(anonymizedTrips);

            // Generate GeoJSON export
            const geoJsonData = await generateGeoJSONExport(anonymizedTrips);

            // Upload to Cloud Storage
            const csvFileName = `trip-exports/${yesterday.toISOString().split('T')[0]}/trips.csv`;
            const geoJsonFileName = `trip-exports/${yesterday.toISOString().split('T')[0]}/trips.geojson`;

            await uploadToStorage(csvFileName, csvData, 'text/csv');
            await uploadToStorage(geoJsonFileName, geoJsonData, 'application/json');

            // Store export metadata
            await storeExportMetadata(yesterday, csvFileName, geoJsonFileName, anonymizedTrips.length);

            console.log('Trip export completed successfully');
            return {
                message: 'Export completed',
                tripCount: anonymizedTrips.length,
                csvFile: csvFileName,
                geoJsonFile: geoJsonFileName
            };

        } catch (error) {
            console.error('Error during trip export:', error);
            throw new functions.https.HttpsError('internal', 'Export failed', error);
        }
    });

/**
 * Manual trip export function - triggered by HTTP request
 * 🔥 REQUIRES FIREBASE BLAZE PLAN - Cloud Functions and Cloud Storage
 */
exports.exportTripsManual = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const { startDate, endDate, userId } = data;

    try {
        console.log(`Manual export requested by ${context.auth.uid} for ${startDate} to ${endDate}`);

        const start = new Date(startDate);
        const end = new Date(endDate);

        // Get trips for the specified date range
        let query = admin.firestore().collectionGroup('trips')
            .where('startedAt', '>=', admin.firestore.Timestamp.fromDate(start))
            .where('startedAt', '<', admin.firestore.Timestamp.fromDate(end));

        // If userId is provided, filter by user
        if (userId) {
            query = admin.firestore().collection('users').doc(userId).collection('trips')
                .where('startedAt', '>=', admin.firestore.Timestamp.fromDate(start))
                .where('startedAt', '<', admin.firestore.Timestamp.fromDate(end));
        }

        const tripsSnapshot = await query.get();

        if (tripsSnapshot.empty) {
            return { message: 'No trips found for the specified date range' };
        }

        // Process and anonymize trips
        const anonymizedTrips = await processAndAnonymizeTrips(tripsSnapshot);

        // Generate exports
        const csvData = await generateCSVExport(anonymizedTrips);
        const geoJsonData = await generateGeoJSONExport(anonymizedTrips);

        // Upload to Cloud Storage
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const csvFileName = `manual-exports/${timestamp}/trips.csv`;
        const geoJsonFileName = `manual-exports/${timestamp}/trips.geojson`;

        await uploadToStorage(csvFileName, csvData, 'text/csv');
        await uploadToStorage(geoJsonFileName, geoJsonData, 'application/json');

        return {
            message: 'Manual export completed',
            tripCount: anonymizedTrips.length,
            csvFile: csvFileName,
            geoJsonFile: geoJsonFileName
        };

    } catch (error) {
        console.error('Error during manual export:', error);
        throw new functions.https.HttpsError('internal', 'Export failed', error);
    }
});

/**
 * Process and anonymize trip data
 */
async function processAndAnonymizeTrips(tripsSnapshot) {
    const trips = [];

    for (const doc of tripsSnapshot.docs) {
        const tripData = doc.data();

        // Anonymize trip data
        const anonymizedTrip = {
            id: generateAnonymizedId(doc.id),
            startedAt: tripData.startedAt?.toDate()?.toISOString(),
            endedAt: tripData.endedAt?.toDate()?.toISOString(),
            distanceMeters: tripData.distanceMeters || 0,
            mode: tripData.mode || 'unknown',
            purpose: tripData.purpose || 'unknown',
            isRecurring: tripData.isRecurring || false,
            destinationRegion: tripData.destinationRegion || 'unknown',
            originRegion: tripData.originRegion || 'unknown',
            timezoneOffsetMinutes: tripData.timezoneOffsetMinutes || 0,
            // AnonymizedUserId: generateAnonymizedId(doc.ref.parent.parent.id),
        };

        // Get trip points for GeoJSON
        try {
            const pointsSnapshot = await doc.ref.collection('points').get();
            anonymizedTrip.points = pointsSnapshot.docs.map(pointDoc => {
                const pointData = pointDoc.data();
                return {
                    latitude: pointData.latitude,
                    longitude: pointData.longitude,
                    timestamp: pointData.timestamp?.toDate()?.toISOString(),
                    accuracy: pointData.accuracy || 0,
                    speed: pointData.speed || 0,
                    heading: pointData.heading || 0
                };
            });
        } catch (error) {
            console.warn(`Could not fetch points for trip ${doc.id}:`, error);
            anonymizedTrip.points = [];
        }

        trips.push(anonymizedTrip);
    }

    return trips;
}

/**
 * Generate CSV export
 */
async function generateCSVExport(trips) {
    const tempDir = os.tmpdir();
    const csvPath = path.join(tempDir, 'trips.csv');

    const csvWriter = csv.createObjectCsvWriter({
        path: csvPath,
        header: [
            { id: 'id', title: 'Trip ID' },
            { id: 'startedAt', title: 'Start Time' },
            { id: 'endedAt', title: 'End Time' },
            { id: 'distanceMeters', title: 'Distance (m)' },
            { id: 'mode', title: 'Transport Mode' },
            { id: 'purpose', title: 'Purpose' },
            { id: 'isRecurring', title: 'Is Recurring' },
            { id: 'destinationRegion', title: 'Destination Region' },
            { id: 'originRegion', title: 'Origin Region' },
            { id: 'timezoneOffsetMinutes', title: 'Timezone Offset (min)' },
            { id: 'pointCount', title: 'Point Count' }
        ]
    });

    const csvData = trips.map(trip => ({
        ...trip,
        pointCount: trip.points?.length || 0
    }));

    await csvWriter.writeRecords(csvData);

    return fs.readFileSync(csvPath, 'utf8');
}

/**
 * Generate GeoJSON export
 */
async function generateGeoJSONExport(trips) {
    const features = [];

    for (const trip of trips) {
        if (trip.points && trip.points.length > 0) {
            // Create LineString for trip path
            const coordinates = trip.points.map(point => [point.longitude, point.latitude]);

            const feature = {
                type: 'Feature',
                properties: {
                    tripId: trip.id,
                    startedAt: trip.startedAt,
                    endedAt: trip.endedAt,
                    distanceMeters: trip.distanceMeters,
                    mode: trip.mode,
                    purpose: trip.purpose,
                    isRecurring: trip.isRecurring,
                    destinationRegion: trip.destinationRegion,
                    originRegion: trip.originRegion,
                    timezoneOffsetMinutes: trip.timezoneOffsetMinutes
                },
                geometry: {
                    type: 'LineString',
                    coordinates: coordinates
                }
            };

            features.push(feature);
        }
    }

    const geoJson = {
        type: 'FeatureCollection',
        features: features,
        properties: {
            exportDate: new Date().toISOString(),
            tripCount: trips.length,
            totalPoints: trips.reduce((sum, trip) => sum + (trip.points?.length || 0), 0)
        }
    };

    return JSON.stringify(geoJson, null, 2);
}

/**
 * Upload file to Cloud Storage
 */
async function uploadToStorage(fileName, data, contentType) {
    const bucket = storage.bucket(BUCKET_NAME);
    const file = bucket.file(fileName);

    await file.save(data, {
        metadata: {
            contentType: contentType,
            cacheControl: 'public, max-age=3600'
        }
    });

    console.log(`Uploaded ${fileName} to Cloud Storage`);
}

/**
 * Store export metadata in Firestore
 */
async function storeExportMetadata(date, csvFile, geoJsonFile, tripCount) {
    const exportDoc = {
        date: admin.firestore.Timestamp.fromDate(date),
        csvFile: csvFile,
        geoJsonFile: geoJsonFile,
        tripCount: tripCount,
        createdAt: admin.firestore.Timestamp.now(),
        status: 'completed'
    };

    await admin.firestore().collection('trip_exports').add(exportDoc);
    console.log('Export metadata stored in Firestore');
}

/**
 * Generate anonymized ID
 */
function generateAnonymizedId(originalId) {
    // Simple hash function for anonymization
    let hash = 0;
    for (let i = 0; i < originalId.length; i++) {
        const char = originalId.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash).toString(36);
}

/**
 * Get export statistics
 * 🔥 REQUIRES FIREBASE BLAZE PLAN - Cloud Functions
 */
exports.getExportStats = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    try {
        const { startDate, endDate } = data;

        const start = new Date(startDate);
        const end = new Date(endDate);

        const exportsSnapshot = await admin.firestore()
            .collection('trip_exports')
            .where('date', '>=', admin.firestore.Timestamp.fromDate(start))
            .where('date', '<', admin.firestore.Timestamp.fromDate(end))
            .orderBy('date', 'desc')
            .get();

        const exports = exportsSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            date: doc.data().date.toDate().toISOString()
        }));

        const totalTrips = exports.reduce((sum, exp) => sum + exp.tripCount, 0);

        return {
            exports: exports,
            totalTrips: totalTrips,
            exportCount: exports.length
        };

    } catch (error) {
        console.error('Error getting export stats:', error);
        throw new functions.https.HttpsError('internal', 'Failed to get export stats', error);
    }
});