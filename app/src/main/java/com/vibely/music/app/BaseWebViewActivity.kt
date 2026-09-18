package com.vibely.music.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowInsetsController
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat

abstract class BaseWebViewActivity : AppCompatActivity() {

    protected lateinit var webView: WebView
    private val progressHandler = Handler(Looper.getMainLooper())
    private var progressRunnable: Runnable? = null

    abstract fun getAssetHtmlFile(): String
    abstract fun getWebViewId(): Int

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(getLayoutResId())
        webView = findViewById(getWebViewId())
        setupWebView()
        applyStatusBarTheme()
        webView.loadUrl("file:///android_asset/${getAssetHtmlFile()}")

        PlayerManager.onStateChanged = { isPlaying, isLoading, videoId ->
            runOnUiThread {
                webView.evaluateJavascript(
                    "if (window.onPlayerStateChanged) window.onPlayerStateChanged($isPlaying, $isLoading, ${if (videoId != null) "'$videoId'" else "null"});",
                    null
                )
            }
        }

        startProgressLoop()
    }

    private fun startProgressLoop() {
        progressRunnable = object : Runnable {
            override fun run() {
                val position = PlayerManager.getCurrentPositionMs()
                val duration = PlayerManager.getDurationMs()
                val videoId = PlayerManager.getCurrentVideoId()
                if (videoId != null && duration > 0) {
                    webView.evaluateJavascript(
                        "if (window.onPlayerProgress) window.onPlayerProgress($position, $duration);",
                        null
                    )
                }
                progressHandler.postDelayed(this, 500)
            }
        }
        progressHandler.post(progressRunnable!!)
    }

    override fun onDestroy() {
        super.onDestroy()
        progressRunnable?.let { progressHandler.removeCallbacks(it) }
    }

    protected open fun getLayoutResId(): Int = R.layout.activity_webview_base

    private fun setupWebView() {
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.mediaPlaybackRequiresUserGesture = false
        webView.webViewClient = WebViewClient()
        webView.addJavascriptInterface(NativeBridge(), "NativeBridge")
    }

    protected fun applyStatusBarTheme() {
        val isDark = ThemeManager.isDarkModeActive(this)

        WindowCompat.setDecorFitsSystemWindows(window, true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.setSystemBarsAppearance(
                if (isDark) 0 else WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS,
                WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
            )
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = if (isDark) {
                0
            } else {
                View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            }
        }
    }

    inner class NativeBridge {

        @JavascriptInterface
        fun navigateTo(screen: String) {
            runOnUiThread {
                val targetClass: Class<out AppCompatActivity>? = when (screen) {
                    "home" -> MainActivity::class.java
                    "search" -> SearchActivity::class.java
                    "library" -> LibraryActivity::class.java
                    "settings" -> SettingsActivity::class.java
                    else -> null
                }
                targetClass?.let {
                    if (it != this@BaseWebViewActivity::class.java) {
                        startActivity(Intent(this@BaseWebViewActivity, it))
                    }
                }
            }
        }

        @JavascriptInterface
        fun goBack() {
            runOnUiThread { onBackPressedDispatcher.onBackPressed() }
        }

        @JavascriptInterface
        fun getCurrentTheme(): String {
            return ThemeManager.getTheme(this@BaseWebViewActivity)
        }

        @JavascriptInterface
        fun isDarkModeActive(): Boolean {
            return ThemeManager.isDarkModeActive(this@BaseWebViewActivity)
        }

        @JavascriptInterface
        fun setTheme(theme: String) {
            runOnUiThread {
                ThemeManager.setTheme(this@BaseWebViewActivity, theme)
                applyStatusBarTheme()
                webView.evaluateJavascript(
                    "if (window.onThemeChanged) window.onThemeChanged('${ThemeManager.getTheme(this@BaseWebViewActivity)}', ${ThemeManager.isDarkModeActive(this@BaseWebViewActivity)});",
                    null
                )
            }
        }

        @JavascriptInterface
        fun searchMusic(query: String, callbackId: String) {
            YouTubeScraper.search(query) { resultsJson ->
                runOnUiThread {
                    webView.evaluateJavascript(
                        "if (window.onSearchResults) window.onSearchResults('$callbackId', $resultsJson);",
                        null
                    )
                }
            }
        }

        @JavascriptInterface
        fun playTrack(videoId: String, videoUrl: String) {
            runOnUiThread {
                PlayerManager.playVideoId(this@BaseWebViewActivity, videoId, videoUrl)
            }
        }

        @JavascriptInterface
        fun togglePlayPause() {
            runOnUiThread { PlayerManager.togglePlayPause() }
        }

        @JavascriptInterface
        fun seekTo(positionMs: Long) {
            runOnUiThread { PlayerManager.seekTo(positionMs) }
        }

        @JavascriptInterface
        fun getPlayerState(): String {
            val videoId = PlayerManager.getCurrentVideoId()
            val isPlaying = PlayerManager.isPlaying()
            val position = PlayerManager.getCurrentPositionMs()
            val duration = PlayerManager.getDurationMs()
            return "{\"videoId\":${if (videoId != null) "\"$videoId\"" else "null"},\"isPlaying\":$isPlaying,\"position\":$position,\"duration\":$duration}"
        }
    }
}