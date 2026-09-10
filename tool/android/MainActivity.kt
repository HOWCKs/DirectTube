package com.directtube.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Além da activity, expõe o canal `com.directtube.app/media` que publica um
 * arquivo baixado (em armazenamento privado do app) na memória PÚBLICA via
 * MediaStore — assim ele aparece no gerenciador de arquivos, na galeria e nos
 * apps de música, em `Músicas/` ou `Filmes/`.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.directtube.app/media"

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
                    else -> result.notImplemented()
                }
            }
    }

    /** Copia [path] para a coleção pública e devolve o caminho absoluto final. */
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
        } ?: throw Exception("Não consegui gravar o arquivo na memória.")

        return publicPath(relative, source.name)
    }

    private fun publicPath(relative: String, name: String): String {
        val root = Environment.getExternalStoragePublicDirectory(relative)
        return File(root, name).absolutePath
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
