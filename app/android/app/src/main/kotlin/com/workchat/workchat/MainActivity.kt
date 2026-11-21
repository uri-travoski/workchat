package com.workchat.workchat

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.workchat.workchat/share"
    private var pendingSharedData: Map<String, Any?>? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
        pendingSharedData?.let {
            methodChannel?.invokeMethod("onSharedContentReceived", it)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedContent" -> {
                        result.success(pendingSharedData)
                        pendingSharedData = null
                    }
                    "clearSharedContent" -> {
                        pendingSharedData = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action

        if (Intent.ACTION_SEND == action) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            val uri: Uri? = try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            } catch (e: Exception) {
                null
            }

            val filesList = mutableListOf<Map<String, String>>()
            if (uri != null) {
                copyUriToCache(uri)?.let { filesList.add(it) }
            }

            if (sharedText != null || filesList.isNotEmpty()) {
                pendingSharedData = mapOf(
                    "text" to sharedText,
                    "files" to filesList
                )
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val uris: ArrayList<Uri>? = try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
            } catch (e: Exception) {
                null
            }

            val filesList = mutableListOf<Map<String, String>>()
            uris?.forEach { uri ->
                copyUriToCache(uri)?.let { filesList.add(it) }
            }
            if (filesList.isNotEmpty()) {
                pendingSharedData = mapOf(
                    "text" to null,
                    "files" to filesList
                )
            }
        }
    }

    private fun copyUriToCache(uri: Uri): Map<String, String>? {
        return try {
            val contentResolver = applicationContext.contentResolver
            var fileName = "shared_file_${System.currentTimeMillis()}"

            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1 && cursor.moveToFirst()) {
                    fileName = cursor.getString(nameIndex)
                }
            }

            val targetDir = File(cacheDir, "shared_incoming").apply { mkdirs() }
            val targetFile = File(targetDir, fileName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }

            mapOf(
                "path" to targetFile.absolutePath,
                "name" to fileName,
                "mimeType" to (contentResolver.getType(uri) ?: "*/*")
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
