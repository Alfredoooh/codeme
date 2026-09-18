package com.vibely.music.app

import android.content.Context
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Response as NPResponse
import org.schabi.newpipe.extractor.downloader.Request as NPRequest
import org.schabi.newpipe.extractor.search.SearchInfo
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import java.util.concurrent.TimeUnit

class MusicExtractor(context: Context) {

    init {
        NewPipe.init(OkHttpDownloader())
    }

    private val youtube = ServiceList.YouTube

    fun search(query: String): String {
        val handler = youtube.searchQHFactory.fromQuery(query)
        val info = SearchInfo.getInfo(youtube, handler)
        val arr = JSONArray()
        for (item in info.relatedItems) {
            if (item !is StreamInfoItem) continue
            val id = extractId(item.url)
            if (id.isEmpty()) continue
            arr.put(JSONObject().apply {
                put("id", id)
                put("title", item.name ?: "")
                put("artist", item.uploaderName ?: "")
                put("duration", item.duration)
                put("thumbnail", item.thumbnails?.lastOrNull()?.url ?: "")
                put("url", item.url ?: "")
                put("views", formatViews(item.viewCount))
                put("uploadDate", item.textualUploadDate ?: "")
            })
            if (arr.length() >= 25) break
        }
        return arr.toString()
    }

    fun getStreamUrl(videoId: String): String {
        val url = "https://www.youtube.com/watch?v=$videoId"
        val info = StreamInfo.getInfo(youtube, url)
        val best = info.audioStreams.maxByOrNull { it.averageBitrate }
        return best?.content ?: ""
    }

    fun getRelated(videoId: String): String {
        val url = "https://www.youtube.com/watch?v=$videoId"
        val info = StreamInfo.getInfo(youtube, url)
        val arr = JSONArray()
        for (item in info.relatedStreams) {
            if (item !is StreamInfoItem) continue
            val id = extractId(item.url)
            if (id.isEmpty()) continue
            arr.put(JSONObject().apply {
                put("id", id)
                put("title", item.name ?: "")
                put("artist", item.uploaderName ?: "")
                put("duration", item.duration)
                put("thumbnail", item.thumbnails?.lastOrNull()?.url ?: "")
                put("url", item.url ?: "")
            })
            if (arr.length() >= 20) break
        }
        return arr.toString()
    }

    private fun extractId(url: String?): String {
        if (url.isNullOrEmpty()) return ""
        val regex = Regex("[?&]v=([^&]+)")
        return regex.find(url)?.groupValues?.get(1) ?: url.substringAfterLast("/")
    }

    private fun formatViews(views: Long): String {
        if (views <= 0) return ""
        return when {
            views >= 1_000_000_000 -> "%.1fB".format(views / 1_000_000_000.0)
            views >= 1_000_000 -> "%.1fM".format(views / 1_000_000.0)
            views >= 1_000 -> "%.1fK".format(views / 1_000.0)
            else -> views.toString()
        }
    }
}

private class OkHttpDownloader : Downloader() {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    override fun execute(request: NPRequest): NPResponse {
        val rb = Request.Builder().url(request.url())

        request.headers().forEach { (name, values) ->
            values.forEach { rb.addHeader(name, it) }
        }
        rb.header(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        )

        when (request.httpMethod()) {
            "GET" -> rb.get()
            "POST" -> {
                val body = (request.dataToSend() ?: ByteArray(0))
                    .toRequestBody("application/octet-stream".toMediaTypeOrNull())
                rb.post(body)
            }
            else -> rb.method(request.httpMethod(), null)
        }

        val response = client.newCall(rb.build()).execute()
        return NPResponse(
            response.code,
            response.message,
            response.headers.toMultimap(),
            response.body?.string() ?: "",
            response.request.url.toString()
        )
    }
}