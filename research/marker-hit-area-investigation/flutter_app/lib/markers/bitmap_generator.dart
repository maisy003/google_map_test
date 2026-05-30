import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'marker_specs.dart';

/// 形状仕様から PNG バイトを生成する。
/// 透明領域の比率は仕様書 §4.1 と一致するよう描画する。
/// 全形状とも色は固定で red 系（仮説検証に色は無関係）。
class BitmapGenerator {
  /// PNG バイトを返す。
  static Future<Uint8List> generate(MarkerSpec spec) async {
    final w = spec.bitmapPxWidth;
    final h = spec.bitmapPxHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 背景は完全透明（PNG の透明領域として保持）
    final paint = Paint()..style = PaintingStyle.fill;

    switch (spec.shape) {
      case MarkerShape.s0SolidSquare:
        paint.color = const Color(0xFFE53935); // red 600
        canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), paint);
        break;

      case MarkerShape.s1Circle:
        paint.color = const Color(0xFFE53935);
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          w / 2,
          paint,
        );
        break;

      case MarkerShape.s2CirclePad20:
        // 周囲 20% パディング → 円の半径は w * 0.5 * 0.6 = w*0.3
        paint.color = const Color(0xFFE53935);
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          w * 0.3,
          paint,
        );
        break;

      case MarkerShape.s3CirclePad40:
        // 周囲 40% パディング → 円の半径は w * 0.5 * 0.2 = w*0.1
        paint.color = const Color(0xFFE53935);
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          w * 0.1,
          paint,
        );
        break;

      case MarkerShape.s4PinTight:
        // 円(上半分) + 下向きポインタ。bbox はちょうどフィット
        // bitmapPxHeight は w * 1.3 になっている前提
        _drawPin(canvas, w.toDouble(), h.toDouble(), padding: 0.0);
        break;

      case MarkerShape.s5PinPad10:
        // 正方形 bbox（ここでは w × w）+ 周囲 10% パディング
        // 元のピン形状は w*0.8 × w*0.8*1.3 で中央に配置
        _drawPin(canvas, w.toDouble(), h.toDouble(), padding: 0.1);
        break;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawPin(Canvas canvas, double w, double h, {required double padding}) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    // padding は片側比率。実領域は (w - 2*pad*w) × (h - 2*pad*h)
    final padX = w * padding;
    final padY = h * padding;
    final innerW = w - 2 * padX;
    final innerH = h - 2 * padY;

    // 円の半径 = innerW / 2、中心 = (innerW/2, innerW/2)（円は上に配置）
    final circleRadius = innerW / 2;
    final cx = padX + innerW / 2;
    final cy = padY + circleRadius;

    canvas.drawCircle(Offset(cx, cy), circleRadius, paint);

    // ポインタは下向き三角形：円の底（cy + r）から bottom (padY + innerH) まで
    final path = Path()
      ..moveTo(cx - circleRadius * 0.5, cy + circleRadius * 0.6)
      ..lineTo(cx + circleRadius * 0.5, cy + circleRadius * 0.6)
      ..lineTo(cx, padY + innerH)
      ..close();
    canvas.drawPath(path, paint);
  }
}
