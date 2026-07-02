package com.streamflix.streamflix

import android.content.Context
import android.media.AudioManager
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.streamflix.app/native_controls"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVolume" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                        val percentage = currentVolume.toDouble() / maxVolume.toDouble()
                        result.success(percentage)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume")
                    if (volume != null) {
                        try {
                            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val targetVolume = (volume * maxVolume).toInt()
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, AudioManager.FLAG_SHOW_UI)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("BAD_ARGUMENT", "Volume argument is null", null)
                    }
                }
                "getBrightness" -> {
                    try {
                        val lp = window.attributes
                        val brightness = lp.screenBrightness
                        if (brightness < 0) {
                            // System default (-1.0f). Read system setting:
                            try {
                                val sysBrightness = android.provider.Settings.System.getInt(
                                    contentResolver,
                                    android.provider.Settings.System.SCREEN_BRIGHTNESS
                                )
                                result.success(sysBrightness.toDouble() / 255.0)
                            } catch (e: Exception) {
                                result.success(0.5) // default fallback
                            }
                        } else {
                            result.success(brightness.toDouble())
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "setBrightness" -> {
                    val brightness = call.argument<Double>("brightness")
                    if (brightness != null) {
                        try {
                            runOnUiThread {
                                val lp = window.attributes
                                lp.screenBrightness = brightness.toFloat()
                                window.attributes = lp
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("BAD_ARGUMENT", "Brightness argument is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
