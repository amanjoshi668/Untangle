package com.amanjoshi.untangle_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.amanjoshi.untangle_app/native"
        private const val REQ_CREATE_DOC = 4021
        private const val REQ_NOTIF_PERM = 4022
    }

    private var pendingDocContent: String? = null
    private var pendingDocResult: MethodChannel.Result? = null
    private var pendingReminderArgs: Map<String, Any?>? = null
    private var pendingReminderResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "configureReminders" -> {
                    val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                    val enabled = args["enabled"] as? Boolean ?: false
                    val amHour = (args["amHour"] as? Number)?.toInt() ?: 8
                    val amMinute = (args["amMinute"] as? Number)?.toInt() ?: 30
                    val pmHour = (args["pmHour"] as? Number)?.toInt() ?: 20
                    val pmMinute = (args["pmMinute"] as? Number)?.toInt() ?: 30

                    if (enabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingReminderArgs = args
                        pendingReminderResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF_PERM)
                    } else {
                        ReminderScheduler.saveAndApply(applicationContext, enabled, amHour, amMinute, pmHour, pmMinute)
                        result.success(true)
                    }
                }

                "saveExportDocument" -> {
                    val filename = call.argument<String>("filename") ?: "untangle_decisions.md"
                    val mimeType = call.argument<String>("mimeType") ?: "text/markdown"
                    val content = call.argument<String>("content") ?: ""

                    try {
                        pendingDocContent = content
                        pendingDocResult = result
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }
                        startActivityForResult(intent, REQ_CREATE_DOC)
                    } catch (_: Exception) {
                        pendingDocContent = null
                        pendingDocResult = null
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, filename)
                            putExtra(Intent.EXTRA_TEXT, content)
                        }
                        startActivity(Intent.createChooser(share, "Export Decisions"))
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_NOTIF_PERM) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            val args = pendingReminderArgs
            val res = pendingReminderResult
            pendingReminderArgs = null
            pendingReminderResult = null
            if (granted && args != null) {
                val amHour = (args["amHour"] as? Number)?.toInt() ?: 8
                val amMinute = (args["amMinute"] as? Number)?.toInt() ?: 30
                val pmHour = (args["pmHour"] as? Number)?.toInt() ?: 20
                val pmMinute = (args["pmMinute"] as? Number)?.toInt() ?: 30
                ReminderScheduler.saveAndApply(applicationContext, true, amHour, amMinute, pmHour, pmMinute)
                res?.success(true)
            } else {
                res?.success(false)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_CREATE_DOC) {
            val content = pendingDocContent
            val res = pendingDocResult
            pendingDocContent = null
            pendingDocResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null && content != null) {
                val uri: Uri = data.data!!
                try {
                    contentResolver.openOutputStream(uri)?.use { stream ->
                        stream.write(content.toByteArray(Charsets.UTF_8))
                    }
                    res?.success(true)
                } catch (_: Exception) {
                    res?.success(false)
                }
            } else {
                res?.success(false)
            }
        }
    }
}
