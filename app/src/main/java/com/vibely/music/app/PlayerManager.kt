package com.vibely.music.app

import android.content.Context
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.stream.StreamInfo
import java.util.concurrent.Executors

object PlayerManager {

    private const val TAG = "PlayerManager"
    private val executor = Executors.newSingleThreadExecutor()
    private var exoPlayer: ExoPlayer? = null
    private var currentVideoId: String? = null

    var onStateChanged: ((isPlaying: Boolean, isLoading: Boolean, videoId: String?) -> Unit)? = null

    fun init(context: Context) {
        if (exoPlayer == null) {
            exoPlayer = ExoPlayer.Builder(context.applicationContext).build().apply {
                addListener(object : Player.Listener {
                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        onStateChanged?.invoke(isPlaying, false, currentVideoId)
                    }
                    override fun onPlaybackStateChanged(state: Int) {
                        val loading = state == Player.STATE_BUFFERING
                        onStateChanged?.invoke(isPlaying, loading, currentVideoId)
                    }
                })
            }
        }
    }

    fun playVideoId(context: Context, videoId: String, videoUrl: String) {
        init(context)
        currentVideoId = videoId
        onStateChanged?.invoke(false, true, videoId)

        executor.execute {
            try {
                val streamInfo = StreamInfo.getInfo(ServiceList.YouTube, videoUrl)
                val audioStreams = streamInfo.audioStreams

                if (audioStreams.isNullOrEmpty()) {
                    Log.e(TAG, "Nenhuma stream de áudio encontrada para $videoId")
                    onStateChanged?.invoke(false, false, videoId)
                    return@execute
                }

                val bestAudio = audioStreams.maxByOrNull { it.averageBitrate }
                val streamUrl = bestAudio?.content

                if (streamUrl.isNullOrEmpty()) {
                    Log.e(TAG, "URL de stream vazia para $videoId")
                    onStateChanged?.invoke(false, false, videoId)
                    return@execute
                }

                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    val mediaItem = MediaItem.fromUri(streamUrl)
                    exoPlayer?.setMediaItem(mediaItem)
                    exoPlayer?.prepare()
                    exoPlayer?.play()
                }

            } catch (e: Exception) {
                Log.e(TAG, "Erro ao resolver stream: ${e.message}", e)
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    onStateChanged?.invoke(false, false, videoId)
                }
            }
        }
    }

    fun togglePlayPause() {
        exoPlayer?.let {
            if (it.isPlaying) it.pause() else it.play()
        }
    }

    fun pause() {
        exoPlayer?.pause()
    }

    fun stop() {
        exoPlayer?.stop()
        currentVideoId = null
    }

    fun isPlaying(): Boolean = exoPlayer?.isPlaying ?: false

    fun getCurrentVideoId(): String? = currentVideoId

    fun getCurrentPositionMs(): Long = exoPlayer?.currentPosition ?: 0

    fun getDurationMs(): Long = exoPlayer?.duration?.takeIf { it > 0 } ?: 0

    fun seekTo(positionMs: Long) {
        exoPlayer?.seekTo(positionMs)
    }

    fun release() {
        exoPlayer?.release()
        exoPlayer = null
        currentVideoId = null
    }
}