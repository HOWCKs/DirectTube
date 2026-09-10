package com.directtube.app

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

/**
 * Activity + canal nativo `com.directtube.app/media`:
 *  - publish: copia um download para a memória pública (MediaStore).
 *  - requestAudioPermission: pede leitura de áudio e devolve se concedeu.
 *  - pickFolder: abre o seletor de pasta do sistema (SAF) e devolve o caminho.
 *  - scanFolders: lista os arquivos de áudio das pastas escolhidas.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.directtube.app/media"
    private val pickRequest = 4210
    private val permissionRequest = 4211

    private var pendingPick: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "publish" -> {
                        val path = call.argument<String>("path")
                        val isAudio = call.argument<Boolean>("isAudio") ?: false
                        val title = call.argument<String>("title") ?: "DirectTube"
                        if (path.isNullOrEmpty()) {
                            result.error("args", "path é obrigatório", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(publish(path, isAudio, title))
                        } catch (e: Exception) {
                            result.error("publish", e.message ?: "falha ao salvar", null)
                        }
                    }
                    "requestAudioPermission" -> requestAudioPermission(result)
                    "pickFolder" -> pickFolder(result)
                    "scanFolders" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        try {
                            result.success(scanFolders(paths))
                        } catch (e: Exception) {
                            result.error("scan", e.message ?: "falha ao escanear", null)
                        }
                    }
                    "share" -> {
                        val text = call.argument<String>("text") ?: ""
                        try {
                            shareText(text)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("share", e.message ?: "falha ao compartilhar", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------------------------------------------------ //
    // Permissão de áudio
    // ------------------------------------------------------------------ //

    private fun permission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            Manifest.permission.READ_MEDIA_AUDIO
        else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun requestAudioPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, permission())
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(this, arrayOf(permission()), permissionRequest)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequest) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermission?.success(granted)
            pendingPermission = null
        }
    }

    // ------------------------------------------------------------------ //
    // Seletor de pasta (SAF)
    // ------------------------------------------------------------------ //

    private fun pickFolder(result: MethodChannel.Result) {
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            startActivityForResult(intent, pickRequest)
        } catch (e: Exception) {
            pendingPick = null
            result.error("pick", e.message ?: "seletor indisponível", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickRequest) {
            val result = pendingPick
            pendingPick = null
            if (result == null) return
            if (resultCode == RESULT_OK && data != null) {
                val uri: Uri? = data.data
                val path = uri?.let { treeToPath(it) }
                result.success(path)
            } else {
                result.success(null)
            }
        }
    }

    private fun treeToPath(uri: Uri): String? {
        return try {
            val doc = DocumentsContract.getTreeDocumentId(uri)
            when {
                doc.startsWith("primary:") ->
                    "/storage/emulated/0/" + doc.removePrefix("primary:")
                doc.contains(':') -> {
                    val volume = doc.substringBefore(':')
                    val rest = doc.substringAfter(':')
                    "/storage/$volume/$rest"
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    // ------------------------------------------------------------------ //
    // Scanner de pastas
    // ------------------------------------------------------------------ //

    private val audioExtensions = setOf(
        "mp3", "m4a", "aac", "flac", "ogg", "opus", "wav", "wma"
    )

    private fun scanFolders(paths: List<String>): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        for (root in paths) {
            val dir = File(root)
            if (!dir.exists() || !dir.isDirectory) continue
            dir.walkTopDown()
                .maxDepth(6)
                .filter { it.isFile && audioExtensions.contains(it.extension.lowercase()) }
                .take(800 - out.size)
                .forEach { file ->
                    out.add(
                        mapOf(
                            "path" to file.absolutePath,
                            "title" to file.nameWithoutExtension,
                            "folder" to (file.parentFile?.name ?: ""),
                            "size" to file.length()
                        )
                    )
                    if (out.size >= 800) return out
                }
        }
        return out
    }

    // ------------------------------------------------------------------ //
    // Publicação na memória pública (MediaStore)
    // ------------------------------------------------------------------ //

    private fun publish(path: String, isAudio: Boolean, title: String): String {
        val source = File(path)
        if (!source.exists()) throw Exception("O arquivo baixado não foi encontrado.")

        val relative = if (isAudio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES
        val mime = guessMime(source.name, isAudio)

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
            put(MediaStore.MediaColumns.TITLE, title)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, relative)
            }
        }

        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (isAudio) {
                    MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                }
            } else {
                if (isAudio) MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }

        val resolver = contentResolver
        val uri = resolver.insert(collection, values)
            ?: throw Exception("Não consegui registrar o arquivo na memória.")

        resolver.openOutputStream(uri)?.use { out ->
            source.inputStream().use { input -> input.copyTo(out) }
        } ?: throw Exception("Não consigo gravar o arquivo na memória.")

        return publicPath(relative, source.name)
    }

    private fun publicPath(relative: String, name: String): String {
        val root = Environment.getExternalStoragePublicDirectory(relative)
        return File(root, name).absolutePath
    }

    private fun shareText(text: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(send, null))
    }

    private fun guessMime(name: String, isAudio: Boolean): String {
        val lower = name.lowercase()
        return when {
            lower.endsWith(".mp3") -> "audio/mpeg"
            lower.endsWith(".m4a") -> "audio/mp4"
            lower.endsWith(".opus") -> "audio/ogg"
            lower.endsWith(".webm") -> if (isAudio) "audio/webm" else "video/webm"
            lower.endsWith(".mkv") -> "video/x-matroska"
            lower.endsWith(".mp4") -> "video/mp4"
            isAudio -> "audio/mpeg"
            else -> "video/mp4"
        }
    }
}
