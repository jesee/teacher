package com.example.teacher

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.speech.RecognitionListener
import android.speech.SpeechRecognizer
import android.speech.RecognizerIntent
import android.content.Intent
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SpeechRecognitionPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private val RECORD_AUDIO_REQUEST_CODE = 101

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.example.teacher/speech")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        initializeSpeechRecognizer()
    }

    override fun onDetachedFromActivity() {
        activity = null
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    private fun initializeSpeechRecognizer() {
        if (activity == null) return
        
        if (speechRecognizer == null) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity)
            speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    isListening = false
                    channel.invokeMethod("onSpeechError", error.toString())
                }
                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        channel.invokeMethod("onSpeechResult", matches[0])
                    }
                    isListening = false
                }
                override fun onPartialResults(partialResults: Bundle?) {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        channel.invokeMethod("onPartialResult", matches[0])
                    }
                }
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkPermission" -> {
                if (activity != null) {
                    val permissionStatus = ContextCompat.checkSelfPermission(activity!!, Manifest.permission.RECORD_AUDIO)
                    result.success(permissionStatus == PackageManager.PERMISSION_GRANTED)
                } else {
                    result.error("NO_ACTIVITY", "Activity is null", null)
                }
            }
            "requestPermission" -> {
                if (activity != null) {
                    ActivityCompat.requestPermissions(
                        activity!!,
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        RECORD_AUDIO_REQUEST_CODE
                    )
                    result.success(null)
                } else {
                    result.error("NO_ACTIVITY", "Activity is null", null)
                }
            }
            "startListening" -> {
                if (!isListening) {
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    }
                    try {
                        speechRecognizer?.startListening(intent)
                        isListening = true
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SPEECH_RECOGNITION_ERROR", e.message, null)
                    }
                } else {
                    result.error("ALREADY_LISTENING", "Speech recognition is already active", null)
                }
            }
            "stopListening" -> {
                if (isListening) {
                    speechRecognizer?.stopListening()
                    isListening = false
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}