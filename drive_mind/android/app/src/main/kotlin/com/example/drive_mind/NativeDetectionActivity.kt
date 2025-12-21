package com.example.drive_mind

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Typeface
import android.location.Location
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.drive_mind.Constants.LABELS_PATH
import com.example.drive_mind.Constants.MODEL_PATH
import com.example.drive_mind.databinding.ActivityDetectionBinding
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.sqrt

class NativeDetectionActivity : AppCompatActivity(), Detector.DetectorListener {

    private lateinit var binding: ActivityDetectionBinding
    private lateinit var detector: Detector
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var tracker: ObjectTrackerHelper

    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null

    private val isFrontCamera = false

    /* ───────── Wrong Direction Detection Params ───────── */

    // Allowed directions: vehicles should move DOWN the screen (positive Y direction)
    // This assumes camera is mounted facing forward on the road
    // Vehicles coming toward you appear to move DOWN (increasing Y)
    // Vehicles going away appear to move UP (decreasing Y) - these are "wrong way" from your perspective
    private val allowedDirs = arrayOf(
        floatArrayOf(-0.5f, 1f),      // Straight down-left
        floatArrayOf(-1f, 1f),
    ).map {
        val n = sqrt(it[0] * it[0] + it[1] * it[1])
        floatArrayOf(it[0] / n, it[1] / n)
    }

    private val trackHistory = mutableMapOf<Int, ArrayDeque<Pair<Float, Float>>>()
    private val wrongDirCounter = mutableMapOf<Int, Int>()
    
    /* ───────── Auto Capture Variables ───────── */
    @Volatile
    private var currentFrameBitmap: Bitmap? = null
    private var lastCaptureTime = 0L
    private val capturedTracks = mutableSetOf<Int>()  // Track IDs that have been captured
    
    /* ───────── Location Helper ───────── */
    private lateinit var locationHelper: LocationHelper
    
    /* ───────── Firebase Helper ───────── */
    private val firebaseHelper = FirebaseHelper()

    companion object {
        private const val TAG = "Camera"
        // Movement threshold in normalized coordinates (0-1 range)
        // 0.02 means 2% of screen size movement required
        private const val MOVEMENT_THRESHOLD = 0.07f
        // Cosine threshold: negative means opposite direction
        // 0.3 means roughly within ~70 degrees of allowed direction is OK
        private const val COSINE_THRESHOLD = 0.1f
        private const val HISTORY_LENGTH = 5
        private const val CONSECUTIVE_FRAMES = 2
        
        // Auto capture settings
        private const val CAPTURE_COOLDOWN_MS = 1500L  // Minimum 1.5 seconds between captures

        private val REQUIRED_PERMISSIONS = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        } else {
            arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        }
    }

    /* ───────── Lifecycle ───────── */

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityDetectionBinding.inflate(layoutInflater)
        setContentView(binding.root)

        detector = Detector(baseContext, MODEL_PATH, LABELS_PATH, this)
        detector.setup()

        tracker = ObjectTrackerHelper()
        cameraExecutor = Executors.newSingleThreadExecutor()
        
        // Initialize location helper
        locationHelper = LocationHelper(this)
        locationHelper.setBackgroundExecutor(cameraExecutor)

        if (allPermissionsGranted()) {
            startCamera()
            locationHelper.startLocationUpdates()
        } else {
            ActivityCompat.requestPermissions(this, REQUIRED_PERMISSIONS, 10)
        }
    }
    
    /* ───────── Camera Setup ───────── */

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            bindCameraUseCases()
        }, ContextCompat.getMainExecutor(this))
    }

    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: return

        val rotation = binding.preview.display.rotation

        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_BACK)
            .build()

        preview = Preview.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(rotation)
            .build()

        imageAnalyzer = ImageAnalysis.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()

        imageAnalyzer?.setAnalyzer(cameraExecutor) { imageProxy ->

            val bitmapBuffer = Bitmap.createBitmap(
                imageProxy.width,
                imageProxy.height,
                Bitmap.Config.ARGB_8888
            )

            imageProxy.use {
                bitmapBuffer.copyPixelsFromBuffer(it.planes[0].buffer)
            }

            val matrix = Matrix().apply {
                postRotate(imageProxy.imageInfo.rotationDegrees.toFloat())
                if (isFrontCamera) {
                    postScale(-1f, 1f, imageProxy.width.toFloat(), imageProxy.height.toFloat())
                }
            }

            val rotatedBitmap = Bitmap.createBitmap(
                bitmapBuffer,
                0, 0,
                bitmapBuffer.width,
                bitmapBuffer.height,
                matrix,
                true
            )

            // Store current frame for potential capture
            currentFrameBitmap = rotatedBitmap.copy(Bitmap.Config.ARGB_8888, true)

            detector.detect(rotatedBitmap)
        }

        provider.unbindAll()

        try {
            camera = provider.bindToLifecycle(this, cameraSelector, preview, imageAnalyzer)
            preview?.setSurfaceProvider(binding.preview.surfaceProvider)
        } catch (e: Exception) {
            Log.e(TAG, "Camera bind failed", e)
        }
    }

    /* ───────── Detector Callbacks ───────── */

    override fun onEmptyDetect() {
        binding.overlay.invalidate()
    }

    override fun onDetect(boundingBoxes: List<BoundingBox>, inferenceTime: Long) {
        runOnUiThread {

            val trackedObjects = tracker.track(boundingBoxes)

            trackedObjects.forEach { tracked ->
                val box = boundingBoxes.find { it.cx == tracked.cx && it.cy == tracked.cy } ?: return@forEach
                val trackId = tracked.trackId

                val cx = box.cx
                val cy = box.cy

                val history = trackHistory.getOrPut(trackId) {
                    ArrayDeque(HISTORY_LENGTH)
                }

                wrongDirCounter.putIfAbsent(trackId, 0)

                history.addLast(Pair(cx, cy))
                if (history.size > HISTORY_LENGTH) history.removeFirst()
                
                // Need at least 2 points to calculate direction
                if (history.size < 2) {
                    // Not enough data yet, show tracking status
                    box.clsName = "${box.clsName} 🔄"
                    return@forEach
                }

                val (oldX, oldY) = history.first()
                val dx = cx - oldX
                val dy = cy - oldY

                val movementMag = sqrt(dx * dx + dy * dy)
                
                // Check if there's significant movement
                if (movementMag < MOVEMENT_THRESHOLD) {
                    // Not enough movement to determine direction
                    box.clsName = "${box.clsName} ⏸️"
                    return@forEach
                }

                // Normalize movement vector
                val mvx = dx / movementMag
                val mvy = dy / movementMag

                // Find best match with allowed directions
                var bestSimilarity = -1f
                for (dir in allowedDirs) {
                    val sim = dir[0] * mvx + dir[1] * mvy
                    bestSimilarity = maxOf(bestSimilarity, sim)
                }

                // Log for debugging
                Log.d(TAG, "Track $trackId: dx=${"%.4f".format(dx)}, dy=${"%.4f".format(dy)}, similarity=${"%.2f".format(bestSimilarity)}")

                // Update wrong direction counter
                if (bestSimilarity < COSINE_THRESHOLD) {
                    wrongDirCounter[trackId] = wrongDirCounter[trackId]!! + 1
                } else {
                    wrongDirCounter[trackId] = 0
                }

                val wrongWay = wrongDirCounter[trackId]!! >= CONSECUTIVE_FRAMES
                box.clsName = if (wrongWay) {
                    // Trigger auto-capture if this track hasn't been captured recently
                    if (trackId !in capturedTracks) {
                        captureWrongWayImage(box, trackId)
                    }
                    "${box.clsName} ❌ WRONG WAY"
                } else {
                    "${box.clsName} ✅ OK"
                }
            }

            // Clean up old tracks that are no longer visible
            val activeTrackIds = trackedObjects.map { it.trackId }.toSet()
            trackHistory.keys.retainAll(activeTrackIds)
            wrongDirCounter.keys.retainAll(activeTrackIds)
            capturedTracks.retainAll(activeTrackIds)

            binding.inferenceTime.text = "${inferenceTime}ms"
            binding.overlay.setResults(boundingBoxes)
            binding.overlay.invalidate()
        }
    }

    /* ───────── Auto Capture ───────── */

    private fun captureWrongWayImage(box: BoundingBox, trackId: Int) {
        val currentTime = System.currentTimeMillis()
        
        // Check cooldown
        if (currentTime - lastCaptureTime < CAPTURE_COOLDOWN_MS) {
            return
        }
        
        val bitmap = currentFrameBitmap ?: return
        
        // Mark this track as captured and update time
        capturedTracks.add(trackId)
        lastCaptureTime = currentTime
        
        // Get current timestamp
        val captureTime = Date()
        val timeFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        val timestampText = timeFormat.format(captureTime)
        
        // Get location info - use cached location name for human-readable address
        val location = locationHelper.currentLocation
        val locationText = locationHelper.cachedLocationName
        
        // Create a copy with bounding box and info overlay
        val annotatedBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(annotatedBitmap)
        
        // Bounding box paint
        val boxPaint = Paint().apply {
            color = Color.RED
            style = Paint.Style.STROKE
            strokeWidth = 8f
        }
        
        // Background paint for text
        val bgPaint = Paint().apply {
            color = Color.argb(180, 0, 0, 0)
            style = Paint.Style.FILL
        }
        
        // Text paint for overlay info
        val textPaint = Paint().apply {
            color = Color.WHITE
            textSize = 25f
            style = Paint.Style.FILL
            typeface = Typeface.DEFAULT_BOLD
            isAntiAlias = true
        }
        
        // Warning text paint
        val warningPaint = Paint().apply {
            color = Color.RED
            textSize = 25f
            style = Paint.Style.FILL
            typeface = Typeface.DEFAULT_BOLD
            isAntiAlias = true
        }
        
        // Draw bounding box
        val left = box.x1 * annotatedBitmap.width
        val top = box.y1 * annotatedBitmap.height
        val right = box.x2 * annotatedBitmap.width
        val bottom = box.y2 * annotatedBitmap.height
        canvas.drawRect(left, top, right, bottom, boxPaint)
        
        // Draw "WRONG WAY" label above box
        val warningText = "⚠️ WRONG WAY DETECTED!"
        canvas.drawText(warningText, left, top - 15, warningPaint)
        
        // Draw info overlay at the bottom of the image
        val padding = 10f
        val lineHeight = 25f
        val infoBoxTop = annotatedBitmap.height - (lineHeight * 3) - padding * 2
        
        // Draw semi-transparent background for info
        canvas.drawRect(
            0f,
            infoBoxTop,
            annotatedBitmap.width.toFloat(),
            annotatedBitmap.height.toFloat(),
            bgPaint
        )
        
        // Draw timestamp
        canvas.drawText(
            "📅 Time: $timestampText",
            padding,
            infoBoxTop + lineHeight,
            textPaint
        )
        
        // Draw location
        canvas.drawText(
            "📍 $locationText",
            padding,
            infoBoxTop + lineHeight * 2,
            textPaint
        )
        
        // Draw app name/watermark
        canvas.drawText(
            "🚗 Wrong Way Detection",
            padding,
            infoBoxTop + lineHeight * 3,
            textPaint
        )
        
        // Save in background thread with location data
        val lat = location?.latitude
        val lon = location?.longitude
        val vehicleType = box.clsName.split(" ").firstOrNull() ?: "Unknown"
        val captureTimeMillis = captureTime.time
        cameraExecutor.execute {
            // Save image locally to device
            saveImageToGallery(annotatedBitmap, timestampText, lat, lon)
            
            // Save detection info to Firebase
            saveDetectionToFirebase(
                capturedAt = captureTimeMillis,
                capturedAtFormatted = timestampText,
                locationName = locationText,
                vehicleType = vehicleType
            )
        }
    }
    
    private fun saveDetectionToFirebase(
        capturedAt: Long,
        capturedAtFormatted: String,
        locationName: String,
        vehicleType: String
    ) {
        firebaseHelper.saveDetectionToFirebase(
            capturedAt = capturedAt,
            capturedAtFormatted = capturedAtFormatted,
            locationName = locationName,
            vehicleType = vehicleType,
            onSuccess = {
                runOnUiThread {
                    Toast.makeText(this, "✅ Saved to records", Toast.LENGTH_SHORT).show()
                }
            },
            onFailure = { e ->
                runOnUiThread {
                    Toast.makeText(this, "❌ Firebase error: ${e.message}", Toast.LENGTH_LONG).show()
                    Log.e(TAG, "Failed to save detection: ${e.message}")
                }
            }
        )
    }
    
    private fun saveImageToGallery(bitmap: Bitmap, timestamp: String, latitude: Double?, longitude: Double?) {
        val fileTimestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val filename = "WrongWay_$fileTimestamp.jpg"
        
        var outputStream: OutputStream? = null
        var savedPath: String? = null
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ use MediaStore
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/DriveMind")
                    // Add location metadata if available
                    if (latitude != null && longitude != null) {
                        put(MediaStore.Images.Media.LATITUDE, latitude)
                        put(MediaStore.Images.Media.LONGITUDE, longitude)
                    }
                }
                
                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                uri?.let {
                    outputStream = contentResolver.openOutputStream(it)
                    savedPath = "Pictures/DriveMind/$filename"
                }
            } else {
                // Legacy storage
                val imagesDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "DriveMind")
                if (!imagesDir.exists()) imagesDir.mkdirs()
                
                val imageFile = File(imagesDir, filename)
                outputStream = FileOutputStream(imageFile)
                savedPath = imageFile.absolutePath
            }
            
            outputStream?.let {
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)
                it.flush()
                
                val locationInfo = if (latitude != null && longitude != null) {
                    " at (${"%,.4f".format(latitude)}, ${"%,.4f".format(longitude)})"
                } else ""
                
                runOnUiThread {
                    Toast.makeText(this, "📸 Captured: $filename$locationInfo", Toast.LENGTH_SHORT).show()
                }
                Log.d(TAG, "Image saved: $savedPath | Time: $timestamp | Location: $latitude, $longitude")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save image: ${e.message}", e)
            runOnUiThread {
                Toast.makeText(this, "Failed to save capture", Toast.LENGTH_SHORT).show()
            }
        } finally {
            outputStream?.close()
        }
    }

    /* ───────── Utils ───────── */

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }

    private val requestPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            if (it[Manifest.permission.CAMERA] == true) startCamera()
        }

    override fun onResume() {
        super.onResume()
        if (allPermissionsGranted()) {
            startCamera()
            locationHelper.startLocationUpdates()
        } else {
            requestPermissionLauncher.launch(REQUIRED_PERMISSIONS)
        }
    }
    
    override fun onPause() {
        super.onPause()
        locationHelper.stopLocationUpdates()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Stop location updates and clean up
        locationHelper.destroy()
        // First unbind camera to stop the image analyzer
        cameraProvider?.unbindAll()
        // Shutdown executor and wait for pending tasks
        cameraExecutor.shutdown()
        try {
            cameraExecutor.awaitTermination(1, java.util.concurrent.TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Log.e("Camera", "Executor shutdown interrupted", e)
        }
        // Now safe to clear the detector
        detector.clear()
        tracker.close()
    }
}
