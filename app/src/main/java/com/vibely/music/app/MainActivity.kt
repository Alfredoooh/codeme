package com.vibely.music.app

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsetsController
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var reloadBtn: Button

    private val appUrl = "https://vibelywebapp.onrender.com"

    // Marca se a página principal falhou ao carregar
    private var loadFailed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webView)
        reloadBtn = findViewById(R.id.reloadBtn)

        ViewCompat.setOnApplyWindowInsetsListener(webView) { _, insets -> insets }

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowContentAccess = true
            builtInZoomControls = false
            displayZoomControls = false
            setSupportZoom(false)
            cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
        }

        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false
        webView.setBackgroundColor(Color.TRANSPARENT)

        webView.addJavascriptInterface(AndroidBridge(this), "Android")

        webView.webViewClient = object : WebViewClient() {

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean {
                return false
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                loadFailed = false
                reloadBtn.visibility = View.GONE
            }

            // Falhou ao carregar a página principal:
            // esconde o WebView (some a tela de erro nativa) e mostra o botão "Recarregar"
            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                if (request.isForMainFrame) {
                    loadFailed = true
                    view.stopLoading()
                    view.visibility = View.INVISIBLE
                    reloadBtn.visibility = View.VISIBLE
                }
            }

            // Carregou sem erro: mostra o WebView e esconde o botão
            override fun onPageFinished(view: WebView, url: String?) {
                super.onPageFinished(view, url)
                if (!loadFailed) {
                    view.visibility = View.VISIBLE
                    reloadBtn.visibility = View.GONE
                }
            }
        }

        reloadBtn.setOnClickListener {
            reloadBtn.visibility = View.GONE
            webView.visibility = View.VISIBLE
            loadFailed = false
            // Após um erro, reload() pode recarregar a página de erro; loadUrl é o certo
            webView.loadUrl(appUrl)
        }

        Thread {
            LocalServer(this).start()
        }.start()

        if (savedInstanceState != null) {
            webView.restoreState(savedInstanceState)
        } else {
            webView.loadUrl(appUrl)
        }
    }

    fun setStatusBarIcons(dark: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val controller = window.insetsController
                if (dark) {
                    controller?.setSystemBarsAppearance(
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS,
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                    )
                } else {
                    controller?.setSystemBarsAppearance(
                        0,
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                    )
                }
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = if (dark) {
                    window.decorView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                } else {
                    window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                }
            }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}