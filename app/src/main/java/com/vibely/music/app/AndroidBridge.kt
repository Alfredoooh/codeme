package com.vibely.music.app

import android.webkit.JavascriptInterface

class AndroidBridge(private val activity: MainActivity) {

    @JavascriptInterface
    fun isInsideApp(): Boolean = true

    @JavascriptInterface
    fun getAppVersion(): String = activity.packageManager
        .getPackageInfo(activity.packageName, 0).versionName ?: "1.0"
}