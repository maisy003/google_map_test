import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../logging/hit_log.dart';
import 'bitmap_generator.dart';
import 'marker_specs.dart';

class MarkerCatalog {
  /// `screenSize` は論理 dp。内部で `devicePixelRatio` を掛けて
  /// 物理 px 空間で `ScreenCoordinate` を作る。
  static Future<({Set<Marker> markers, List<MarkerSpec> specs})> buildAll({
    required GoogleMapController controller,
    required Size screenSize,
    required double devicePixelRatio,
    required void Function(String id) onTap,
  }) async {
    final specs = buildSpecList();
    final markers = <Marker>{};

    final physW = screenSize.width * devicePixelRatio;
    final physH = screenSize.height * devicePixelRatio;

    const cols = 3;
    const rows = 6;
    final marginX = physW * 0.12;
    final marginY = physH * 0.12;
    final stepX = (physW - 2 * marginX) / (cols - 1);
    final stepY = (physH - 2 * marginY) / (rows - 1);

    HitLog.indexStart(app: 'flutter');

    for (int i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final col = i % cols;
      final row = i ~/ cols;
      final sx = (marginX + col * stepX).round();
      final sy = (marginY + row * stepY).round();

      final latlng = await controller.getLatLng(ScreenCoordinate(x: sx, y: sy));

      final pngBytes = await BitmapGenerator.generate(spec);
      final descriptor = BitmapDescriptor.bytes(
        pngBytes,
        imagePixelRatio: spec.ratio.value,
      );

      markers.add(
        Marker(
          markerId: MarkerId(spec.id),
          position: latlng,
          icon: descriptor,
          anchor: Offset(spec.anchor.x, spec.anchor.y),
          // タイトル無しの InfoWindow → InfoWindow が開かず Maps SDK の
          // デフォルトカメラパンも発火しない。
          infoWindow: InfoWindow.noText,
          consumeTapEvents: true,
          onTap: () {
            HitLog.markerTap(spec.id);
            onTap(spec.id);
          },
        ),
      );

      HitLog.index(
        id: spec.id,
        shape: spec.shape.id,
        ratio: spec.ratio.id,
        anchor: spec.anchor.id,
        bitmapPxW: spec.bitmapPxWidth,
        bitmapPxH: spec.bitmapPxHeight,
        logicalPtW: spec.logicalPtWidth(devicePixelRatio),
        logicalPtH: spec.logicalPtHeight(devicePixelRatio),
        anchorScreenX: sx,
        anchorScreenY: sy,
      );
    }
    HitLog.indexDone();
    return (markers: markers, specs: specs);
  }
}
