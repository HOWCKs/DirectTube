package com.directtube.app

import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.stream.StreamInfo
import java.util.concurrent.TimeUnit

/** Downloader OkHttp exigido pelo NewPipeExtractor. */
object OkDownloader : Downloader() {
    private val client = OkHttpClient.Builder()
        .readTimeout(30, TimeUnit.SECONDS)
        .connectTimeout(15, TimeUnit.SECONDS)
        .build()

    override fun execute(request: Request): Response {
        val builder = okhttp3.Request.Builder().url(request.url())
        for ((key, values) in request.headers()) {
            for (value in values) builder.addHeader(key, value)
        }
        val body = request.dataToSend()?.toRequestBody(null)
        builder.method(request.httpMethod(), body)

        val resp = client.newCall(builder.build()).execute()
        val headerMap = resp.headers.toMultimap()
        val responseBody = resp.body?.string()
        return Response(
            resp.code,
            resp.message,
            headerMap,
            responseBody,
            resp.request.url.toString()
        )
    }
}

/**
 * Ponte nativa para o NewPipeExtractor (a mesma tecnologia de extração do
 * NewPipe): resolve metadados e lista streams com URLs diretas, sem API oficial.
 * Canal: `com.directtube.app/newpipe`.
 */
object NewPipeBridge {
    @Volatile private var initialized = false

    @Synchronized
    fun ensureInit() {
        if (!initialized) {
            NewPipe.init(OkDownloader)
            initialized = true
        }
    }

    fun resolve(url: String): Map<String, Any?> {
        ensureInit()
        val info = StreamInfo.getInfo(url)
        return mapOf(
            "id" to info.id,
            "title" to info.name,
            "author" to (info.uploaderName ?: ""),
            "durationSeconds" to info.duration,
            "thumbnailUrl" to (info.thumbnails.firstOrNull()?.url ?: "")
        )
    }

    fun formats(url: String): List<Map<String, Any?>> {
        ensureInit()
        val info = StreamInfo.getInfo(url)
        val out = mutableListOf<Map<String, Any?>>()

        for (s in info.videoStreams) {
            out.add(
                mapOf(
                    "url" to s.content,
                    "label" to (s.resolution ?: "video"),
                    "ext" to (s.mediaFormat?.suffix ?: "mp4"),
                    "audioOnly" to false,
                    "height" to parseHeight(s.resolution),
                    "bitrateKbps" to 0,
                    "size" to s.contentLength,
                    "needsMuxing" to false
                )
            )
        }
        for (s in info.videoOnlyStreams) {
            out.add(
                mapOf(
                    "url" to s.content,
                    "label" to ((s.resolution ?: "video") + " (vídeo mudo)"),
                    "ext" to (s.mediaFormat?.suffix ?: "mp4"),
                    "audioOnly" to false,
                    "height" to parseHeight(s.resolution),
                    "bitrateKbps" to 0,
                    "size" to s.contentLength,
                    "needsMuxing" to true
                )
            )
        }
        for (s in info.audioStreams) {
            out.add(
                mapOf(
                    "url" to s.content,
                    "label" to ("Áudio " + (s.averageBitrate) + "k"),
                    "ext" to (s.mediaFormat?.suffix ?: "m4a"),
                    "audioOnly" to true,
                    "height" to null,
                    "bitrateKbps" to s.averageBitrate,
                    "size" to s.contentLength,
                    "needsMuxing" to false
                )
            )
        }
        return out
    }

    private fun parseHeight(resolution: String?): Int? {
        if (resolution == null) return null
        return resolution.filter { it.isDigit() }.toIntOrNull()
    }
}
