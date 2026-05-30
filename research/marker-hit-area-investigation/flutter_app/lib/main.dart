import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'markers/marker_catalog.dart';
import 'markers/marker_specs.dart';

void main() {
  runApp(const MarkerHitTestApp());
}

class MarkerHitTestApp extends StatelessWidget {
  const MarkerHitTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marker Hit-area Test',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  Set<Marker> _markers = const {};
  List<MarkerSpec> _specs = const [];
  String? _lastTapped;

  static const _initialCamera = CameraPosition(
    target: LatLng(35.681236, 139.767125),
    zoom: 17.5,
  );

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    // 1フレーム以上待ってからスクリーン座標→緯度経度の逆引きをする。
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final mq = MediaQuery.of(context);
    final result = await MarkerCatalog.buildAll(
      controller: controller,
      screenSize: mq.size,
      devicePixelRatio: mq.devicePixelRatio,
      onTap: (id) => setState(() => _lastTapped = id),
    );
    if (!mounted) return;
    setState(() {
      _markers = result.markers;
      _specs = result.specs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: _onMapCreated,
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.white70,
                child: Text(
                  _lastTapped == null
                      ? 'Phase 2 OK — markers: ${_markers.length}'
                      : 'tapped: $_lastTapped (markers: ${_markers.length})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
