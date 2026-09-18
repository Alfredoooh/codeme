package com.vibely.music.app

class LibraryActivity : BaseWebViewActivity() {
    override fun getAssetHtmlFile(): String = "library.html"
    override fun getWebViewId(): Int = R.id.webview
}