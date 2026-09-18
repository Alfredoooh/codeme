package com.vibely.music.app

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.search.SearchInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import java.util.concurrent.Executors

object YouTubeScraper {

    private const val TAG = "YouTubeScraper"
    private val executor = Executors.newSingleThreadExecutor()

    fun search(query: String, callback: (resultsJson: String) -> Unit) {
        executor.execute {
            try {
                val service = ServiceList.YouTube
                val queryHandler = service.searchQHFactory
                    .fromQuery(query, listOf("music_songs"), null)

                val searchInfo = SearchInfo.getInfo(service, queryHandler)

                val output = JSONArray()

                for (item in searchInfo.relatedItems) {
                    if (item !is StreamInfoItem) continue

                    val videoId = extractVideoId(item.url)
                    if (videoId.isEmpty()) continue

                    val resultObj = JSONObject().apply {
                        put("videoId", videoId)
                        put("url", item.url ?: "")
                        put("title", item.name ?: "")
                        put("channel", item.uploaderName ?: "")
                        put("duration", formatDuration(item.duration))
                        put("views", formatViews(item.viewCount))
                        put("thumbnail", item.thumbnails?.lastOrNull()?.url ?: "")
                        put("uploadDate", item.textualUploadDate ?: "")
                    }

                    output.put(resultObj)

                    if (output.length() >= 25) break
                }

                callback(output.toString())

            } catch (e: Exception) {
                Log.e(TAG, "Erro na pesquisa: ${e.message}", e)
                callback("[]")
            }
        }
    }

    fun getDescription(videoUrl: String, callback: (description: String) -> Unit) {
        executor.execute {
            try {
                val streamInfo = org.schabi.newpipe.extractor.stream.StreamInfo.getInfo(
                    ServiceList.YouTube, videoUrl
                )
                callback(streamInfo.description?.content ?: "")
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao obter descrição: ${e.message}", e)
                callback("")
            }
        }
    }

    private fun extractVideoId(url: String?): String {
        if (url.isNullOrEmpty()) return ""
        val regex = Regex("[?&]v=([^&]+)")
        val match = regex.find(url)
        return match?.groupValues?.get(1) ?: url.substringAfterLast("/")
    }

    private fun formatDuration(seconds: Long): String {
        if (seconds <= 0) return ""
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return if (h > 0) String.format("%d:%02d:%02d", h, m, s)
        else String.format("%d:%02d", m, s)
    }

    private fun formatViews(views: Long): String {
        if (views <= 0) return ""
        return when {
            views >= 1_000_000_000 -> String.format("%.1fB", views / 1_000_000_000.0)
            views >= 1_000_000 -> String.format("%.1fM", views / 1_000_000.0)
            views >= 1_000 -> String.format("%.1fK", views / 1_000.0)
            else -> views.toString()
        }
    }
}
