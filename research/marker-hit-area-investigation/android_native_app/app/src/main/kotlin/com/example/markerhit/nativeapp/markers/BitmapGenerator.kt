package com.example.markerhit.nativeapp.markers

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.DisplayMetrics

/**
 * 形状仕様から Bitmap を生成。Flutter 側 `bitmap_generator.dart` と同じ幾何。
 * density による論理サイズ調整は呼び出し側で `Bitmap.setDensity` する。
 */
object BitmapGenerator {

    /** ヒット時のハイライト用に色だけ差し替えた版を生成 */
    fun generateHighlighted(spec: MarkerSpec): Bitmap =
        generate(spec, highlightColor = "#1B5E20") // dark green

    fun generate(spec: MarkerSpec, highlightColor: String? = null): Bitmap {
        val w = spec.bitmapPxWidth
        val h = spec.bitmapPxHeight
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        // 背景は透明
        canvas.drawColor(Color.TRANSPARENT)

        val paint = Paint().apply {
            color = Color.parseColor(highlightColor ?: "#E53935")
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        when (spec.shape) {
            MarkerShape.S0_SOLID_SQUARE -> {
                canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
            }
            MarkerShape.S1_CIRCLE -> {
                canvas.drawCircle(w / 2f, h / 2f, w / 2f, paint)
            }
            MarkerShape.S2_CIRCLE_PAD20 -> {
                canvas.drawCircle(w / 2f, h / 2f, w * 0.3f, paint)
            }
            MarkerShape.S3_CIRCLE_PAD40 -> {
                canvas.drawCircle(w / 2f, h / 2f, w * 0.1f, paint)
            }
            MarkerShape.S4_PIN_TIGHT -> {
                drawPin(canvas, w.toFloat(), h.toFloat(), padding = 0f, paint = paint)
            }
            MarkerShape.S5_PIN_PAD10 -> {
                drawPin(canvas, w.toFloat(), h.toFloat(), padding = 0.1f, paint = paint)
            }
        }

        // density 設定で論理サイズを制御。
        // R1: DENSITY_DEFAULT (160 = 1x) → 32px bitmap が 32 dp で表示
        // R3: 480 (3x) → 96px bitmap が 32 dp で表示
        // RN: DENSITY_NONE → Maps SDK は scale せず raw px を使う想定
        when (spec.ratio) {
            MarkerRatio.R1 -> bmp.density = DisplayMetrics.DENSITY_DEFAULT
            MarkerRatio.R3 -> bmp.density = 480
            MarkerRatio.RN -> bmp.density = Bitmap.DENSITY_NONE
        }
        return bmp
    }

    private fun drawPin(canvas: Canvas, w: Float, h: Float, padding: Float, paint: Paint) {
        val padX = w * padding
        val padY = h * padding
        val innerW = w - 2 * padX
        val innerH = h - 2 * padY
        val circleRadius = innerW / 2f
        val cx = padX + innerW / 2f
        val cy = padY + circleRadius
        canvas.drawCircle(cx, cy, circleRadius, paint)
        val path = Path().apply {
            moveTo(cx - circleRadius * 0.5f, cy + circleRadius * 0.6f)
            lineTo(cx + circleRadius * 0.5f, cy + circleRadius * 0.6f)
            lineTo(cx, padY + innerH)
            close()
        }
        canvas.drawPath(path, paint)
    }
}
