package com.example.markerhit.nativeapp.markers

/**
 * 形状とピクセル比のバリエーション仕様。Flutter 側の `marker_specs.dart` と一対一対応。
 */
enum class MarkerShape(val id: String, val label: String) {
    S0_SOLID_SQUARE("S0", "solid square"),
    S1_CIRCLE("S1", "circle tight"),
    S2_CIRCLE_PAD20("S2", "circle pad20"),
    S3_CIRCLE_PAD40("S3", "circle pad40"),
    S4_PIN_TIGHT("S4", "pin tight"),
    S5_PIN_PAD10("S5", "pin pad10"),
}

enum class MarkerRatio(val id: String, val ratioValue: Double?, val basePx: Int) {
    /** 実ピクセル 32x32 を 1x 扱い（DENSITY_DEFAULT） */
    R1("R1", 1.0, 32),
    /** 実ピクセル 96x96 を 3x 扱い（density = 3*160 = 480） */
    R3("R3", 3.0, 96),
    /** 実ピクセル 96x96 を density 指定なし（端末既定スケール） */
    RN("RN", null, 96),
}

enum class AnchorMode(val id: String, val x: Float, val y: Float) {
    CENTER("AC", 0.5f, 0.5f),
    BOTTOM("AB", 0.5f, 1.0f),
}

data class MarkerSpec(
    val shape: MarkerShape,
    val ratio: MarkerRatio,
    val anchor: AnchorMode,
) {
    val id: String get() = "${shape.id}_${ratio.id}_${anchor.id}"
    val bitmapPxWidth: Int get() = ratio.basePx
    val bitmapPxHeight: Int
        get() = if (shape == MarkerShape.S4_PIN_TIGHT) (ratio.basePx * 1.3).toInt() else ratio.basePx
}

/** 18 マーカー（S0-S5 × R1/R3/RN、center anchor） */
fun buildSpecList(): List<MarkerSpec> {
    val list = mutableListOf<MarkerSpec>()
    for (shape in MarkerShape.values()) {
        for (ratio in MarkerRatio.values()) {
            list.add(MarkerSpec(shape, ratio, AnchorMode.CENTER))
        }
    }
    return list
}
