package com.example.drive_mind

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.Locale
import java.util.concurrent.Executor

/**
 * Helper class to manage location updates and geocoding.
 * Provides current location and human-readable location names.
 */
class LocationHelper(private val context: Context) {

    companion object {
        private const val TAG = "LocationHelper"
        private const val DEFAULT_UPDATE_INTERVAL_MS = 5000L
        private const val DEFAULT_MIN_UPDATE_INTERVAL_MS = 2000L
        private const val GEOCODE_DISTANCE_THRESHOLD_METERS = 50f
    }

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)
    
    private val geocoder: Geocoder = Geocoder(context, Locale.ENGLISH)
    
    private var locationCallback: LocationCallback? = null
    private var backgroundExecutor: Executor? = null
    
    // Current location state
    var currentLocation: Location? = null
        private set
    
    var cachedLocationName: String = "Location: Not available"
        private set
    
    private var lastGeocodedLocation: Location? = null
    
    // Listener for location updates
    private var locationListener: LocationUpdateListener? = null

    /**
     * Interface for receiving location updates
     */
    interface LocationUpdateListener {
        fun onLocationUpdated(location: Location)
        fun onLocationNameUpdated(locationName: String)
    }

    /**
     * Set a listener for location updates
     */
    fun setLocationListener(listener: LocationUpdateListener?) {
        this.locationListener = listener
    }

    /**
     * Set the background executor for geocoding operations
     */
    fun setBackgroundExecutor(executor: Executor) {
        this.backgroundExecutor = executor
    }

    /**
     * Check if location permissions are granted
     */
    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, 
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context, 
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Start receiving location updates
     * @param updateIntervalMs Interval between location updates in milliseconds
     * @param minUpdateIntervalMs Minimum interval between updates in milliseconds
     */
    @SuppressLint("MissingPermission")
    fun startLocationUpdates(
        updateIntervalMs: Long = DEFAULT_UPDATE_INTERVAL_MS,
        minUpdateIntervalMs: Long = DEFAULT_MIN_UPDATE_INTERVAL_MS
    ) {
        if (!hasLocationPermission()) {
            Log.w(TAG, "Location permission not granted")
            return
        }

        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, updateIntervalMs)
            .setWaitForAccurateLocation(false)
            .setMinUpdateIntervalMillis(minUpdateIntervalMs)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    currentLocation = location
                    Log.d(TAG, "Location updated: ${location.latitude}, ${location.longitude}")
                    
                    // Notify listener
                    locationListener?.onLocationUpdated(location)

                    // Reverse geocode in background to get location name
                    // Only update if location changed significantly
                    val shouldGeocode = lastGeocodedLocation == null ||
                            location.distanceTo(lastGeocodedLocation!!) > GEOCODE_DISTANCE_THRESHOLD_METERS

                    if (shouldGeocode) {
                        backgroundExecutor?.execute {
                            updateLocationName(location)
                        } ?: run {
                            // If no executor set, update synchronously (not recommended)
                            updateLocationName(location)
                        }
                    }
                }
            }
        }

        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback!!,
            Looper.getMainLooper()
        )
    }

    /**
     * Stop receiving location updates
     */
    fun stopLocationUpdates() {
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
            locationCallback = null
        }
    }

    /**
     * Reverse geocode location to get a human-readable address
     */
    private fun updateLocationName(location: Location) {
        try {
            // Create a new Geocoder with US locale to get English results
            val englishGeocoder = Geocoder(context, Locale.US)

            @Suppress("DEPRECATION")
            val addresses = englishGeocoder.getFromLocation(location.latitude, location.longitude, 1)
            if (!addresses.isNullOrEmpty()) {
                val address = addresses[0]

                // Log all address components for debugging
                Log.d(TAG, "Address: featureName=${address.featureName}, " +
                        "subLocality=${address.subLocality}, locality=${address.locality}, " +
                        "adminArea=${address.adminArea}, countryName=${address.countryName}, " +
                        "addressLine=${address.getAddressLine(0)}")

                // Build a readable location string
                val fullAddress = address.getAddressLine(0)

                val locationName = if (fullAddress != null) {
                    // Extract first 2-3 parts of the address (area, city)
                    val parts = fullAddress.split(",").map { it.trim() }
                    when {
                        parts.size >= 3 -> "${parts[0]}, ${parts[1]}"
                        parts.size >= 2 -> "${parts[0]}, ${parts[1]}"
                        parts.isNotEmpty() -> parts[0]
                        else -> formatCoordinates(location)
                    }
                } else {
                    // Fallback to building from components
                    val locationParts = mutableListOf<String>()
                    address.subLocality?.let { locationParts.add(it) }
                    address.locality?.let { city ->
                        if (city != address.subLocality) locationParts.add(city)
                    }
                    if (locationParts.isEmpty()) {
                        address.adminArea?.let { locationParts.add(it) }
                    }

                    if (locationParts.isNotEmpty()) {
                        locationParts.joinToString(", ")
                    } else {
                        formatCoordinates(location)
                    }
                }

                cachedLocationName = locationName
                lastGeocodedLocation = location
                Log.d(TAG, "Location name: $cachedLocationName")
                
                // Notify listener
                locationListener?.onLocationNameUpdated(cachedLocationName)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Geocoding failed: ${e.message}")
            // Keep the previous cached name or use coordinates
            cachedLocationName = formatCoordinates(location)
            locationListener?.onLocationNameUpdated(cachedLocationName)
        }
    }

    /**
     * Format coordinates as a string
     */
    private fun formatCoordinates(location: Location): String {
        return String.format(Locale.US, "%.4f, %.4f", location.latitude, location.longitude)
    }

    /**
     * Get the current latitude (or null if not available)
     */
    fun getLatitude(): Double? = currentLocation?.latitude

    /**
     * Get the current longitude (or null if not available)
     */
    fun getLongitude(): Double? = currentLocation?.longitude

    /**
     * Clean up resources
     */
    fun destroy() {
        stopLocationUpdates()
        locationListener = null
        backgroundExecutor = null
    }
}
