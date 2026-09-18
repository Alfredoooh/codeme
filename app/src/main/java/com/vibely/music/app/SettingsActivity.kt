package com.vibely.music.app

class SettingsActivity : BaseWebViewActivity() {
    override fun getAssetHtmlFile(): String = "settings.html"
    override fun getWebViewId(): Int = R.id.webview
}