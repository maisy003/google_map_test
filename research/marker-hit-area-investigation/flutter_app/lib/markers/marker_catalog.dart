import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'bitmap_generator.dart';
import 'marker_specs.dart';

/// 18 マーカーの BitmapDescriptor 生成 + 緯度経度割り当て。
/// 配置はスクリーン座標グリッド (3 列 × 6 行 = 18) を `getLatLng` で経緯度に逆変換。
/// 計測フェーズではこの配置は使わず、1マーカーずつカメラ中央に持っていく。
class MarkerCatalog {
  /// Phase 2 用：見える状態にするためのフル配置。
  /// `screenSize` は論理 dp。内部で `devicePixelRatio` を掛けて
  /// 物理ピクセル空間で `ScreenCoordinate` を作る。
  static Future<({Set<Marker> markers, List<MarkerSpec> specs})> buildAll({
    required GoogleMapController controller,
    required Size screenSize,
    required double devicePixelRatio,
    required void Function(String id) onTap,
  }) async {
    final specs = buildSpecList();
    final markers = <Marker>{};

    // 物理ピクセルで作業（ScreenCoordinate は物理 px）
    final physW = screenSize.width * devicePixelRatio;
    final physH = screenSize.height * devicePixelRatio;

    const cols = 3;
    const rows = 6;
    final marginX = physW * 0.12;
    final marginY = physH * 0.12;
    final stepX = (physW - 2 * marginX) / (cols - 1);
    final stepY = (physH - 2 * marginY) / (rows - 1);

    for (int i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final col = i % cols;
      final row = i ~/ cols;
      final sx = marginX + col * stepX;
      final sy = marginY + row * stepY;

      final latlng = await controller.getLatLng(
        ScreenCoordinate(x: sx.round(), y: sy.round()),
      );

      final pngBytes = await BitmapGenerator.generate(spec);
      final descriptor = BitmapDescriptor.bytes(
        pngBytes,
        imagePixelRatio: spec.ratio.value, // R1=1.0, R3=3.0, RN=null
      );

      markers.add(
        Marker(
          markerId: MarkerId(spec.id),
          position: latlng,
          icon: descriptor,
          anchor: Offset(spec.anchor.x, spec.anchor.y),
          onTap: () => onTap(spec.id),
        ),
      );
    }
    return (markers: markers, specs: specs);
  }
}
