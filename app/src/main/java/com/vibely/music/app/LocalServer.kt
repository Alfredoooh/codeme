package com.vibely.music.app

import android.content.Context
import fi.iki.elonen.NanoHTTPD

class LocalServer(context: Context) : NanoHTTPD(8080) {

    private val extractor = MusicExtractor(context)

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val params = session.parameters

        return try {
            when {
                uri == "/search" -> {
                    val query = params["q"]?.firstOrNull() ?: return badRequest("Missing q")
                    val json = extractor.search(query)
                    jsonResponse(json)
                }
                uri == "/stream" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    val url = extractor.getStreamUrl(id)
                    jsonResponse("""{"streamUrl":"$url"}""")
                }
                uri == "/related" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    val json = extractor.getRelated(id)
                    jsonResponse(json)
                }
                else -> newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found")
            }
        } catch (e: Exception) {
            newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "application/json", """{"error":"${e.message}"}""")
        }
    }

    private fun jsonResponse(json: String): Response {
        val r = newFixedLengthResponse(Response.Status.OK, "application/json", json)
        r.addHeader("Access-Control-Allow-Origin", "*")
        return r
    }

    private fun badRequest(msg: String): Response {
        return newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", """{"error":"$msg"}""")
    }
}
