/// 形状とピクセル比のバリエーション仕様。
/// 仕様書 §4.1 / §4.2 と一対一対応。Android Native 側と同じ ID を共有する。

enum MarkerShape {
  /// 不透明な単色正方形。透明ピクセル 0% (control)
  s0SolidSquare(id: 'S0', label: 'solid square'),

  /// 単色円を bbox に内接。コーナー4箇所透明 (約21%)
  s1Circle(id: 'S1', label: 'circle tight'),

  /// S1 + 周囲 20% パディング (透明 約47%)
  s2CirclePad20(id: 'S2', label: 'circle pad20'),

  /// S1 + 周囲 40% パディング (透明 約68%)
  s3CirclePad40(id: 'S3', label: 'circle pad40'),

  /// 円+下向きポインタ (写真マーカー型) / タイト bbox
  s4PinTight(id: 'S4', label: 'pin tight'),

  /// S4 + 周囲 10% パディング (正方形 bbox)
  s5PinPad10(id: 'S5', label: 'pin pad10');

  const MarkerShape({required this.id, required this.label});
  final String id;
  final String label;
}

enum MarkerRatio {
  /// imagePixelRatio 1.0 を明示指定 (実ピクセル 32x32)
  r1(id: 'R1', value: 1.0, basePx: 32),

  /// imagePixelRatio 3.0 を明示指定 (実ピクセル 96x96)
  r3(id: 'R3', value: 3.0, basePx: 96),

  /// imagePixelRatio を指定しない (プラグイン既定)
  rn(id: 'RN', value: null, basePx: 96);

  const MarkerRatio({required this.id, required this.value, required this.basePx});
  final String id;
  final double? value;
  final int basePx;
}

enum AnchorMode {
  /// (0.5, 0.5) - 中心
  center(id: 'AC', x: 0.5, y: 0.5),

  /// (0.5, 1.0) - 下端 (ポインタ尻尾)
  bottom(id: 'AB', x: 0.5, y: 1.0);

  const AnchorMode({required this.id, required this.x, required this.y});
  final String id;
  final double x;
  final double y;
}

/// 1マーカーの完全仕様。
class MarkerSpec {
  const MarkerSpec({
    required this.shape,
    required this.ratio,
    required this.anchor,
  });

  final MarkerShape shape;
  final MarkerRatio ratio;
  final AnchorMode anchor;

  /// 一意 ID。例: "S0_R1_AC"
  String get id => '${shape.id}_${ratio.id}_${anchor.id}';

  /// 実ビットマップ ピクセルサイズ（高さ）。
  /// S4/S5 のピンは縦長（縦 = 横 * 1.3）。
  int get bitmapPxWidth => ratio.basePx;
  int get bitmapPxHeight =>
      (shape == MarkerShape.s4PinTight) ? (ratio.basePx * 1.3).round() : ratio.basePx;

  /// imagePixelRatio で除して得られる論理サイズ（dp）
  /// RN の場合は端末既定 pixelRatio を使う想定だが、ここでは 3.0 として表示。
  double logicalPtWidth(double devicePixelRatio) =>
      bitmapPxWidth / (ratio.value ?? devicePixelRatio);
  double logicalPtHeight(double devicePixelRatio) =>
      bitmapPxHeight / (ratio.value ?? devicePixelRatio);
}

/// 18 マーカー × anchor バリアントを列挙。
/// S0-S3 は anchor 1 種（center）、S4-S5 は anchor 2 種（center + bottom）
/// 合計 18 種マーカー（S0-S3 × R1/R3/RN = 12, S4-S5 × R1/R3/RN × 2 anchor = 12 → 24）
/// 仕様書 §4.1 は 18 と記載されているので、まずは center anchor のみ 18 種で実行し、
/// S4/S5 の bottom anchor バリアントは「追加」とする。
List<MarkerSpec> buildSpecList() {
  final list = <MarkerSpec>[];
  for (final shape in MarkerShape.values) {
    for (final ratio in MarkerRatio.values) {
      list.add(MarkerSpec(shape: shape, ratio: ratio, anchor: AnchorMode.center));
    }
  }
  return list;
}

/// S4/S5 専用の bottom anchor バリアント（仕様書 §4.3）。
List<MarkerSpec> buildAnchorVariantList() {
  final list = <MarkerSpec>[];
  for (final shape in [MarkerShape.s4PinTight, MarkerShape.s5PinPad10]) {
    for (final ratio in MarkerRatio.values) {
      list.add(MarkerSpec(shape: shape, ratio: ratio, anchor: AnchorMode.bottom));
    }
  }
  return list;
}
