package com.example.markerhit.nativeapp.logging

import android.util.Log
import org.json.JSONObject
import java.time.Instant

/**
 * 計測ログ単一行 JSON を logcat に "HITLOG" タグ前置で書く。
 * 受信側は `adb logcat -s HitLog:I` でも `adb logcat | grep HITLOG` でも拾える。
 */
object HitLog {
    private const val TAG = "HitLog"
    private const val PREFIX = "HITLOG"

    private fun emit(event: Map<String, Any?>) {
        val json = JSONObject(event)
        Log.i(TAG, "$PREFIX $json")
    }

    fun indexStart(app: String) = emit(
        mapOf("event" to "index_start", "app" to app, "ts" to Instant.now().toString())
    )

    fun index(
        id: String,
        shape: String,
        ratio: String,
        anchor: String,
        bitmapPxW: Int,
        bitmapPxH: Int,
        logicalPtW: Double,
        logicalPtH: Double,
        anchorScreenX: Int,
        anchorScreenY: Int,
    ) = emit(
        mapOf(
            "event" to "index",
            "id" to id,
            "shape" to shape,
            "ratio" to ratio,
            "anchor" to anchor,
            "bitmap_px_w" to bitmapPxW,
            "bitmap_px_h" to bitmapPxH,
            "logical_pt_w" to logicalPtW,
            "logical_pt_h" to logicalPtH,
            "anchor_screen_x" to anchorScreenX,
            "anchor_screen_y" to anchorScreenY,
        )
    )

    fun indexDone() = emit(
        mapOf("event" to "index_done", "ts" to Instant.now().toString())
    )

    fun markerTap(id: String) = emit(
        mapOf("event" to "tap", "id" to id, "ts" to Instant.now().toString())
    )
}
