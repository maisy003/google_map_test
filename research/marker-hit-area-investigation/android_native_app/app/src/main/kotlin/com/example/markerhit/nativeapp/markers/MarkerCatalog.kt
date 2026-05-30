package com.example.markerhit.nativeapp.markers

import android.graphics.Point
import android.util.DisplayMetrics
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions

/**
 * 18 種マーカーをグリッド配置して GoogleMap に追加する。
 * 物理 px グリッド (3 列 × 6 行)。`Projection.fromScreenLocation` で経緯度に逆引き。
 */
object MarkerCatalog {

    /**
     * @return id → MarkerSpec の対応表。タップハンドラから ID で引ける。
     */
    fun buildAll(map: GoogleMap, displayMetrics: DisplayMetrics): Map<String, Pair<Marker, MarkerSpec>> {
        val specs = buildSpecList()
        val result = mutableMapOf<String, Pair<Marker, MarkerSpec>>()

        val physW = displayMetrics.widthPixels.toFloat()
        val physH = displayMetrics.heightPixels.toFloat()
        val cols = 3
        val rows = 6
        val marginX = physW * 0.12f
        val marginY = physH * 0.12f
        val stepX = (physW - 2 * marginX) / (cols - 1)
        val stepY = (physH - 2 * marginY) / (rows - 1)

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
        }
        return result
    }
}
