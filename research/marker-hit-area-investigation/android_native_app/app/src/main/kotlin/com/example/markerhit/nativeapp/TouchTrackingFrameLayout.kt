package com.example.markerhit.nativeapp

import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import android.widget.FrameLayout

/**
 * ACTION_DOWN の x/y を記録するだけの FrameLayout。
 * Maps SDK は onMarkerClick にタップ座標を渡さないため、View 階層で先回りして記録する。
 */
class TouchTrackingFrameLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : FrameLayout(context, attrs, defStyleAttr) {

    var lastDownX: Float = -1f
        private set
    var lastDownY: Float = -1f
        private set

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (ev.action == MotionEvent.ACTION_DOWN) {
            lastDownX = ev.x
            lastDownY = ev.y
        }
        return super.dispatchTouchEvent(ev)
    }
}
