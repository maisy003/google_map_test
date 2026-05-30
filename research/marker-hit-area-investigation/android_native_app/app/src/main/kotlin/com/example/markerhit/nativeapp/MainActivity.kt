package com.example.markerhit.nativeapp

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.markerhit.nativeapp.logging.HitLog
import com.example.markerhit.nativeapp.markers.MarkerCatalog
import com.example.markerhit.nativeapp.markers.MarkerSpec
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.SupportMapFragment
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.Marker

class MainActivity : AppCompatActivity(), OnMapReadyCallback {
    private lateinit var googleMap: GoogleMap
    private lateinit var status: TextView
    private var markers: Map<String, Pair<Marker, MarkerSpec>> = emptyMap()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        status = findViewById(R.id.status)
        val frag = supportFragmentManager.findFragmentById(R.id.map) as SupportMapFragment
        frag.getMapAsync(this)
    }

    override fun onMapReady(map: GoogleMap) {
        googleMap = map
        googleMap.uiSettings.apply {
            isRotateGesturesEnabled = false
            isTiltGesturesEnabled = false
            isMapToolbarEnabled = false
            isZoomControlsEnabled = false
        }
        val target = LatLng(35.681236, 139.767125)
        googleMap.moveCamera(
            CameraUpdateFactory.newCameraPosition(
                CameraPosition.Builder().target(target).zoom(17.5f).build()
            )
        )
        googleMap.setOnMapLoadedCallback {
            markers = MarkerCatalog.buildAll(googleMap, resources.displayMetrics)
            status.text = "Phase 2 OK — markers: ${markers.size}"
        }
        googleMap.setOnMarkerClickListener { marker ->
            val spec = marker.tag as? MarkerSpec
            val id = spec?.id ?: marker.id
            HitLog.markerTap(id)
            status.text = "tapped: $id (markers: ${markers.size})"
            true  // 戻り値 true = Maps SDK の既定のカメラ移動 / InfoWindow を抑止
        }
    }
}
