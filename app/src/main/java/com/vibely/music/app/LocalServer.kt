package com.vibely.music.app

import android.content.Context
import fi.iki.elonen.NanoHTTPD
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class LocalServer(context: Context) : NanoHTTPD(8080) {

    private val extractor = MusicExtractor(context)

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val params = session.parameters

        if (session.method == Method.OPTIONS) {
            return withCors(newFixedLengthResponse(Response.Status.OK, "text/plain", ""))
        }

        return try {
            when (uri) {
                "/search" -> {
                    val query = params["q"]?.firstOrNull() ?: return badRequest("Missing q")
                    jsonResponse(extractor.search(query))
                }
                "/stream" -> {
                    // Aponta para o proxy local em vez da URL crua do YouTube
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    jsonResponse("""{"streamUrl":"http://localhost:8080/audio?id=$id"}""")
                }
                "/audio" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    proxyAudio(id, session.headers["range"])
                }
                "/related" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    jsonResponse(extractor.getRelated(id))
                }
                else -> withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found"))
            }
        } catch (e: Exception) {
            withCors(
                newFixedLengthResponse(
                    Response.Status.INTERNAL_ERROR,
                    "application/json",
                    """{"error":"${(e.message ?: "erro").replace("\"", "'")}"}"""
                )
            )
        }
    }

    private fun proxyAudio(videoId: String, rangeHeader: String?): Response {
        var upstream = openUpstream(videoId, rangeHeader)

        // URL expirada ou recusada: descarta o cache e tenta uma vez com URL nova
        if (upstream == null || (!upstream.isSuccessful && upstream.code != 206)) {
            upstream?.close()
            extractor.invalidate(videoId)
            upstream = openUpstream(videoId, rangeHeader)
        }

        if (upstream == null || (!upstream.isSuccessful && upstream.code != 206)) {
            val code = upstream?.code ?: 0
            upstream?.close()
            return withCors(
                newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Upstream $code")
            )
        }

        val body = upstream.body ?: run {
            upstream.close()
            return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Sem corpo"))
        }

        val mime = upstream.header("Content-Type") ?: "audio/mp4"
        val length = body.contentLength()
        val status = if (upstream.code == 206) Response.Status.PARTIAL_CONTENT else Response.Status.OK

        val resp = if (length >= 0) {
            newFixedLengthResponse(status, mime, body.byteStream(), length)
        } else {
            newChunkedResponse(status, mime, body.byteStream())
        }

        resp.addHeader("Accept-Ranges", "bytes")
        upstream.header("Content-Range")?.let { resp.addHeader("Content-Range", it) }
        return withCors(resp)
    }

    private fun openUpstream(videoId: String, rangeHeader: String?): okhttp3.Response? {
        val streamUrl = extractor.getStreamUrl(videoId)
        if (streamUrl.isEmpty()) return null

        val rb = Request.Builder()
            .url(streamUrl)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
            )
        // Sem Range o YouTube pode limitar/cortar o stream; força "bytes=0-" quando o player não manda
        rb.header("Range", rangeHeader ?: "bytes=0-")

        return try {
            http.newCall(rb.build()).execute()
        } catch (e: Exception) {
            null
        }
    }

    private fun jsonResponse(json: String): Response =
        withCors(newFixedLengthResponse(Response.Status.OK, "application/json", json))

    private fun badRequest(msg: String): Response =
        withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", """{"error":"$msg"}"""))

    private fun withCors(r: Response): Response {
        r.addHeader("Access-Control-Allow-Origin", "*")
        r.addHeader("Access-Control-Allow-Headers", "Range, Content-Type")
        r.addHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
        r.addHeader("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")
        return r
    }
}