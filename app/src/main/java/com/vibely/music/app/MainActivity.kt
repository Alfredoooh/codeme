package com.vibely.music.app

class MainActivity : BaseWebViewActivity() {
    override fun getAssetHtmlFile(): String = "home.html"
    override fun getWebViewId(): Int = R.id.webview
}