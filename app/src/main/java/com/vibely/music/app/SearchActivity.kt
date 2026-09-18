package com.vibely.music.app

class SearchActivity : BaseWebViewActivity() {
    override fun getAssetHtmlFile(): String = "search.html"
    override fun getWebViewId(): Int = R.id.webview
}