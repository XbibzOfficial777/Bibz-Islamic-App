package com.all.bibz

import android.content.ContentUris
import android.content.ContentValues
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "quranx/diagnostics"
        private const val DIRECTORY_NAME = "QuranX/Logs"
        private val MEDIA_RELATIVE_PATH = "${Environment.DIRECTORY_DOWNLOADS}/$DIRECTORY_NAME/"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                4201,
            )
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "writeLog" -> {
                            val fileName = validName(call.argument<String>("fileName"))
                            val contents = call.argument<String>("contents")
                                ?: throw IllegalArgumentException("Log contents are required")
                            result.success(writeLog(fileName, contents))
                        }
                        "listLogs" -> result.success(listLogs())
                        "deleteLog" -> {
                            val fileName = validName(call.argument<String>("fileName"))
                            result.success(deleteLog(fileName))
                        }
                        "deleteAllLogs" -> {
                            deleteAllLogs()
                            result.success(true)
                        }
                        "getLogDirectory" -> result.success(logDirectoryDescription())
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("DIAGNOSTIC_STORAGE", error.message, null)
                }
            }
    }

    private fun validName(value: String?): String {
        val name = value ?: throw IllegalArgumentException("Log filename is required")
        require(name.matches(Regex("QuranX_Log_[A-Za-z0-9_-]+\\.txt"))) {
            "Invalid diagnostic filename"
        }
        return name
    }

    private fun legacyDirectory(): File {
        val directory = File(Environment.getExternalStorageDirectory(), DIRECTORY_NAME)
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Unable to create ${directory.path}")
        }
        return directory
    }

    private fun logDirectoryDescription(): String {
        return if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            legacyDirectory().path
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$DIRECTORY_NAME"
        }
    }

    private fun writeLog(fileName: String, contents: String): Map<String, String> {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            val file = File(legacyDirectory(), fileName)
            file.writeText(contents, Charsets.UTF_8)
            return mapOf(
                "name" to fileName,
                "path" to file.path,
                "displayPath" to file.path,
            )
        }

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "text/plain")
            put(MediaStore.Downloads.RELATIVE_PATH, MEDIA_RELATIVE_PATH)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create diagnostic file")
        try {
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(contents.toByteArray(Charsets.UTF_8))
                output.flush()
            } ?: throw IllegalStateException("Unable to open diagnostic file")
            contentResolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) },
                null,
                null,
            )
            return mapOf(
                "name" to fileName,
                "path" to uri.toString(),
                "displayPath" to "${Environment.DIRECTORY_DOWNLOADS}/$DIRECTORY_NAME",
                "id" to uri.toString(),
            )
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun listLogs(): List<Map<String, String>> {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            return legacyDirectory().listFiles()
                ?.filter { it.isFile && it.name.endsWith(".txt") }
                ?.sortedByDescending { it.name }
                ?.map {
                    mapOf(
                        "name" to it.name,
                        "path" to it.path,
                        "displayPath" to it.path,
                    )
                }
                ?: emptyList()
        }

        val logs = mutableListOf<Map<String, String>>()
        val projection = arrayOf(
            MediaStore.Downloads._ID,
            MediaStore.Downloads.DISPLAY_NAME,
        )
        val selection = "${MediaStore.Downloads.RELATIVE_PATH} = ?"
        contentResolver.query(
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            projection,
            selection,
            arrayOf(MEDIA_RELATIVE_PATH),
            "${MediaStore.Downloads.DISPLAY_NAME} DESC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val name = cursor.getString(nameColumn)
                if (name.endsWith(".txt")) {
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                        id,
                    )
                    logs += mapOf(
                        "name" to name,
                        "path" to uri.toString(),
                        "displayPath" to "${Environment.DIRECTORY_DOWNLOADS}/$DIRECTORY_NAME",
                        "id" to uri.toString(),
                    )
                }
            }
        }
        return logs
    }

    private fun deleteLog(fileName: String): Boolean {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            return File(legacyDirectory(), fileName).delete()
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        return contentResolver.delete(
            collection,
            "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?",
            arrayOf(fileName, MEDIA_RELATIVE_PATH),
        ) > 0
    }

    private fun deleteAllLogs() {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            legacyDirectory().listFiles()
                ?.filter { it.isFile && it.name.endsWith(".txt") }
                ?.forEach { it.delete() }
            return
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        contentResolver.delete(
            collection,
            "${MediaStore.Downloads.RELATIVE_PATH} = ?",
            arrayOf(MEDIA_RELATIVE_PATH),
        )
    }
}
