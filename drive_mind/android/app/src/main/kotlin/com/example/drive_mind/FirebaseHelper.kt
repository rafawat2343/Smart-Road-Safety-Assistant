package com.example.drive_mind

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

/**
 * Helper class for saving detection metadata to Firebase
 */
class FirebaseHelper {

    companion object {
        private const val TAG = "FirebaseHelper"
        
        // Firebase collection name
        private const val COLLECTION_DETECTIONS = "wrong_way_detections"
    }
    
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Save detection record to Firebase Firestore
     */
    fun saveDetectionToFirebase(
        capturedAt: Long,
        capturedAtFormatted: String,
        locationName: String,
        vehicleType: String,
        onSuccess: (() -> Unit)? = null,
        onFailure: ((Exception) -> Unit)? = null
    ) {
        // Run on main thread since Firebase operations should be on main thread
        mainHandler.post {
            try {
                val firestore = FirebaseFirestore.getInstance()
                val auth = FirebaseAuth.getInstance()
                val userId = auth.currentUser?.uid
                
                Log.d(TAG, "Attempting to save detection - userId: $userId, vehicleType: $vehicleType, location: $locationName")

                val detectionData = hashMapOf(
                    "capturedAt" to capturedAt,
                    "capturedAtFormatted" to capturedAtFormatted,
                    "locationName" to locationName,
                    "vehicleType" to vehicleType,
                    "userId" to userId,
                    "createdAt" to com.google.firebase.Timestamp.now()
                )

                firestore.collection(COLLECTION_DETECTIONS)
                    .add(detectionData)
                    .addOnSuccessListener { documentRef ->
                        Log.d(TAG, "Detection saved to Firebase: ${documentRef.id}")
                        onSuccess?.invoke()
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Failed to save detection: ${e.message}", e)
                        onFailure?.invoke(e)
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Exception while saving to Firebase: ${e.message}", e)
                onFailure?.invoke(e)
            }
        }
    }
}
