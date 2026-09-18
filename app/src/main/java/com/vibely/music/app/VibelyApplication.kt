package com.vibely.music.app

import android.app.Application
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Response as NPResponse
import org.schabi.newpipe.extractor.downloader.Request as NPRequest

class VibelyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        NewPipe.init(OkHttpDownloader())
    }
}

private class OkHttpDownloader : Downloader() {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    override fun execute(request: NPRequest): NPResponse {
        val httpMethod = request.httpMethod()
        val url = request.url()
        val headers = request.headers()
        val dataToSend = request.dataToSend()

        val requestBuilder = okhttp3.Request.Builder().url(url)

        headers.forEach { (headerName, headerValueList) ->
            headerValueList.forEach { headerValue ->
                requestBuilder.addHeader(headerName, headerValue)
            }
        }

        requestBuilder.header(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        )

        when (httpMethod) {
            "GET" -> requestBuilder.get()
            "POST" -> {
                val body = (dataToSend ?: ByteArray(0))
                    .toRequestBody("application/octet-stream".toMediaTypeOrNull())
                requestBuilder.post(body)
            }
            else -> requestBuilder.method(httpMethod, null)
        }

        val okRequest: Request = requestBuilder.build()
        val response = client.newCall(okRequest).execute()

        val responseBodyString = response.body?.string() ?: ""
        val responseHeaders = response.headers.toMultimap()

        return NPResponse(
            response.code,
            response.message,
            responseHeaders,
            responseBodyString,
            response.request.url.toString()
        )
    }
}