package com.example.drive_mind

import kotlin.math.hypot

/**
 * Simple centroid-based object tracker.
 * Assigns consistent track IDs to objects based on proximity between frames.
 */
class ObjectTrackerHelper {

    data class TrackedObject(
        val trackId: Int,
        val cx: Float,
        val cy: Float
    )

    private val trackHistory = mutableMapOf<Int, Pair<Float, Float>>()
    private var nextTrackId = 0

    companion object {
        private const val MAX_DISTANCE = 80f // Max distance to match same object
    }

    /**
     * Assigns track IDs to detected bounding boxes based on centroid proximity.
     */
    fun track(boxes: List<BoundingBox>): List<TrackedObject> {
        val result = mutableListOf<TrackedObject>()
        val usedIds = mutableSetOf<Int>()

        for (box in boxes) {
            val cx = box.cx
            val cy = box.cy

            var bestId: Int? = null
            var minDist = Float.MAX_VALUE

            // Find closest existing track
            for ((id, pos) in trackHistory) {
                if (id in usedIds) continue
                val d = hypot(cx - pos.first, cy - pos.second)
                if (d < minDist && d < MAX_DISTANCE) {
                    minDist = d
                    bestId = id
                }
            }

            val trackId = bestId ?: nextTrackId++
            usedIds.add(trackId)
            trackHistory[trackId] = Pair(cx, cy)
            result.add(TrackedObject(trackId, cx, cy))
        }

        // Clean up old tracks not seen in this frame
        trackHistory.keys.removeAll { it !in usedIds }

        return result
    }

    fun close() {
        trackHistory.clear()
        nextTrackId = 0
    }
}
