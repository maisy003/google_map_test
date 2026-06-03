package com.example.markerhit.nativeapp

import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.markerhit.nativeapp.logging.HitLog
import com.example.markerhit.nativeapp.markers.BitmapGenerator
import com.example.markerhit.nativeapp.markers.MarkerCatalog
import com.example.markerhit.nativeapp.markers.MarkerSpec
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.SupportMapFragment
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.Circle
import com.google.android.gms.maps.model.CircleOptions
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.Marker
import kotlin.math.hypot
import kotlin.math.roundToInt

class MainActivity : AppCompatActivity(), OnMapReadyCallback {
    private lateinit var googleMap: GoogleMap
    private lateinit var status: TextView
    private lateinit var touchRoot: TouchTrackingFrameLayout
    private var markers: Map<String, Pair<Marker, MarkerSpec>> = emptyMap()
    private val handler = Handler(Looper.getMainLooper())
    private val baseCamera = CameraPosition.Builder()
        .target(LatLng(35.681236, 139.767125))
        .zoom(17.5f)
        .build()
    private val resetRunnable = object : Runnable {
        override fun run() {
            if (::googleMap.isInitialized) {
                googleMap.moveCamera(CameraUpdateFactory.newCameraPosition(baseCamera))
            }
            handler.postDelayed(this, 150)
        }
    }
    private var tapMarker: Circle? = null
    private var lastHighlighted: Pair<Marker, MarkerSpec>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        status = findViewById(R.id.status)
        touchRoot = findViewById(R.id.touch_root)
        val frag = supportFragmentManager.findFragmentById(R.id.map) as SupportMapFragment
        frag.getMapAsync(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(resetRunnable)
    }

    override fun onMapReady(map: GoogleMap) {
        googleMap = map
        googleMap.uiSettings.apply {
            isRotateGesturesEnabled = false
            isTiltGesturesEnabled = false
            isMapToolbarEnabled = false
            isZoomControlsEnabled = false
            isScrollGesturesEnabled = false
            isZoomGesturesEnabled = false
        }
        googleMap.moveCamera(CameraUpdateFactory.newCameraPosition(baseCamera))
        googleMap.setOnMapLoadedCallback {
            markers = MarkerCatalog.buildAll(googleMap, resources.displayMetrics)
            status.text = "Ready — ${markers.size} markers placed. Tap any marker to inspect."
            handler.postDelayed(resetRunnable, 150)
        }
        googleMap.setOnMarkerClickListener { marker ->
            val spec = marker.tag as? MarkerSpec ?: return@setOnMarkerClickListener true
            handleTap(marker, spec)
            true
        }
        // タップが マーカーに当たらなかった場合の表示 (距離だけ計算したい場合)
        googleMap.setOnMapClickListener { latlng ->
            val tapX = touchRoot.lastDownX
            val tapY = touchRoot.lastDownY
            status.text = buildString {
                append("MISS  no marker hit\n")
                append("tap @ (${tapX.toInt()}, ${tapY.toInt()})  latlng=(${"%.6f".format(latlng.latitude)}, ${"%.6f".format(latlng.longitude)})")
            }
            showTapDot(latlng, isHit = false)
        }
    }

    private fun handleTap(marker: Marker, spec: MarkerSpec) {
        val tapX = touchRoot.lastDownX
        val tapY = touchRoot.lastDownY
        val anchorScreen = googleMap.projection.toScreenLocation(marker.position)
        val ax = anchorScreen.x.toFloat()
        val ay = anchorScreen.y.toFloat()
        val dx = tapX - ax
        val dy = tapY - ay
        val dist = hypot(dx, dy)

        // 表示サイズの計算
        val displayMetrics: DisplayMetrics = resources.displayMetrics
        val density = displayMetrics.densityDpi // e.g. 420
        val bitmapPx = "${spec.bitmapPxWidth}×${spec.bitmapPxHeight}"
        val expectedScreenPx = when (spec.ratio.id) {
            "R1" -> {
                // density=160 (DENSITY_DEFAULT) → scale = density/160
                val w = spec.bitmapPxWidth * density / 160
                val h = spec.bitmapPxHeight * density / 160
                "$w×$h"
            }
            "R3" -> {
                // density=480 → scale = density/480
                val w = spec.bitmapPxWidth * density / 480
                val h = spec.bitmapPxHeight * density / 480
                "$w×$h"
            }
            "RN" -> {
                // DENSITY_NONE → raw px
                "${spec.bitmapPxWidth}×${spec.bitmapPxHeight}"
            }
            else -> "?"
        }
        val visualRadius = expectedScreenPx.split("×")[0].toIntOrNull()?.let { it / 2 } ?: -1
        val ratioMeaning = when (spec.ratio.id) {
            "R1" -> "imagePixelRatio=1.0 (density 160=1x)"
            "R3" -> "imagePixelRatio=3.0 (density 480=3x)"
            "RN" -> "ratio=null / DENSITY_NONE (raw px)"
            else -> "?"
        }
        val shapeMeaning = when (spec.shape.id) {
            "S0" -> "solid square (透明 0%)"
            "S1" -> "circle inscribed (透明 ~21%)"
            "S2" -> "circle + 20% padding (透明 ~47%)"
            "S3" -> "circle + 40% padding (透明 ~68%)"
            "S4" -> "pin (tight bbox)"
            "S5" -> "pin + 10% padding"
            else -> "?"
        }

        // ヒットマーカーを緑にハイライトし、1.2秒後に元に戻す
        lastHighlighted?.let { (m, s) ->
            m.setIcon(BitmapDescriptorFactory.fromBitmap(BitmapGenerator.generate(s)))
        }
        marker.setIcon(BitmapDescriptorFactory.fromBitmap(BitmapGenerator.generateHighlighted(spec)))
        lastHighlighted = marker to spec
        handler.postDelayed({
            marker.setIcon(BitmapDescriptorFactory.fromBitmap(BitmapGenerator.generate(spec)))
            if (lastHighlighted?.first == marker) lastHighlighted = null
        }, 1200)

        // タップ位置に赤丸 (緯度経度) を打つ
        val tapLatLng = googleMap.projection.fromScreenLocation(android.graphics.Point(tapX.toInt(), tapY.toInt()))
        showTapDot(tapLatLng, isHit = true)

        status.text = buildString {
            append("HIT  ${spec.id}\n")
            append("shape:  $shapeMeaning\n")
            append("ratio:  $ratioMeaning\n")
            append("bitmap:  $bitmapPx px\n")
            append("display: ~$expectedScreenPx px (radius ≈ $visualRadius px)\n")
            append("marker @ (${ax.toInt()}, ${ay.toInt()})\n")
            append("tap    @ (${tapX.toInt()}, ${tapY.toInt()})\n")
            append("distance: ${dist.roundToInt()} px (visual radius $visualRadius px)\n")
            append(if (dist > visualRadius) "  → 視覚境界の外でヒット (${"%.2f".format(dist/visualRadius.coerceAtLeast(1).toFloat())}x)" else "  → 視覚内")
        }
        HitLog.markerTap(spec.id)
    }

    private fun showTapDot(latlng: LatLng, isHit: Boolean) {
        tapMarker?.remove()
        // 半径は 0.5m。zoom 17.5 / 緯度 35.68° で約 1.5 px に相当（視認できる小さな点）
        tapMarker = googleMap.addCircle(
            CircleOptions()
                .center(latlng)
                .radius(0.6)
                .fillColor(if (isHit) Color.argb(220, 0, 200, 0) else Color.argb(220, 200, 0, 0))
                .strokeColor(if (isHit) Color.argb(255, 0, 100, 0) else Color.argb(255, 100, 0, 0))
                .strokeWidth(2f)
                .zIndex(1000f)
        )
        val tag = tapMarker
        handler.postDelayed({
            if (tapMarker == tag) {
                tapMarker?.remove(); tapMarker = null
            }
        }, 2000)
    }
}
