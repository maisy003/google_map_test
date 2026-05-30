package com.example.markerhit.nativeapp.markers

import android.graphics.Point
import android.util.DisplayMetrics
import com.example.markerhit.nativeapp.logging.HitLog
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions

object MarkerCatalog {

    fun buildAll(map: GoogleMap, displayMetrics: DisplayMetrics): Map<String, Pair<Marker, MarkerSpec>> {
        val specs = buildSpecList()
        val result = mutableMapOf<String, Pair<Marker, MarkerSpec>>()

        val physW = displayMetrics.widthPixels.toFloat()
        val physH = displayMetrics.heightPixels.toFloat()
        val devicePixelRatio = displayMetrics.density.toDouble()
        val cols = 3
        val rows = 6
        val marginX = physW * 0.12f
        val marginY = physH * 0.12f
        val stepX = (physW - 2 * marginX) / (cols - 1)
        val stepY = (physH - 2 * marginY) / (rows - 1)

        HitLog.indexStart("native")

        for ((i, spec) in specs.withIndex()) {
            val col = i % cols
            val row = i / cols
            val sx = (marginX + col * stepX).toInt()
            val sy = (marginY + row * stepY).toInt()
            val latlng = map.projection.fromScreenLocation(Point(sx, sy))

            val bitmap = BitmapGenerator.generate(spec)
            val opts = MarkerOptions()
                .position(latlng)
                .icon(BitmapDescriptorFactory.fromBitmap(bitmap))
                .anchor(spec.anchor.x, spec.anchor.y)
                .title(spec.id)
            val marker = map.addMarker(opts) ?: continue
            marker.tag = spec
            result[spec.id] = marker to spec

            val ratioForLogical = spec.ratio.ratioValue ?: devicePixelRatio
            HitLog.index(
                id = spec.id,
                shape = spec.shape.id,
                ratio = spec.ratio.id,
                anchor = spec.anchor.id,
                bitmapPxW = spec.bitmapPxWidth,
                bitmapPxH = spec.bitmapPxHeight,
                logicalPtW = spec.bitmapPxWidth / ratioForLogical,
                logicalPtH = spec.bitmapPxHeight / ratioForLogical,
                anchorScreenX = sx,
                anchorScreenY = sy,
            )
        }
        HitLog.indexDone()
        return result
    }
}
