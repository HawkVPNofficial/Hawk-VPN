package com.follow.clash.plugins

import android.app.Activity
import android.content.Context
import android.view.View
import com.thinkup.banner.api.TUBannerListener
import com.thinkup.banner.api.TUBannerView
import com.thinkup.core.api.AdError
import com.thinkup.core.api.TUAdConst
import com.thinkup.core.api.TUAdInfo
import com.thinkup.core.api.TUDebuggerConfig
import com.thinkup.core.api.TUSDK
import com.thinkup.rewardvideo.api.TURewardVideoAd
import com.thinkup.rewardvideo.api.TURewardVideoListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

private const val CHANNEL_NAME = "com.follow.clash/topon_ads"
private const val BANNER_VIEW_TYPE = "com.follow.clash/topon_banner"

class ToponAdPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var applicationContext: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var initialized = false
    private var rewardedAd: TURewardVideoAd? = null
    private var pendingLoadResult: MethodChannel.Result? = null
    private var pendingShowResult: MethodChannel.Result? = null
    private var earnedReward = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW_TYPE,
            ToponBannerViewFactory(
                isInitialized = { initialized },
                onBannerStateChanged = { viewId, loaded ->
                    channel.invokeMethod("bannerState", mapOf("viewId" to viewId, "loaded" to loaded))
                }
            )
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        rewardedAd?.destroyAd()
        rewardedAd = null
        pendingLoadResult = null
        pendingShowResult = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "loadRewarded" -> loadRewarded(call, result)
            "showRewarded" -> showRewarded(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        if (initialized) {
            result.success(true)
            return
        }
        val appId = call.argument<String>("appId")
        val appKey = call.argument<String>("appKey")
        val debug = call.argument<Boolean>("debug") ?: false
        val debugKey = call.argument<String>("debugKey")
        if (appId.isNullOrBlank() || appKey.isNullOrBlank()) {
            result.error("invalid_configuration", "TopOn appId or appKey is empty", null)
            return
        }
        TUSDK.setNetworkLogDebug(debug)
        if (debug && !debugKey.isNullOrBlank()) {
            TUSDK.setDebuggerConfig(applicationContext, debugKey, TUDebuggerConfig())
        }
        TUSDK.init(applicationContext, appId, appKey)
        initialized = true
        TUSDK.start()
        result.success(true)
    }

    private fun loadRewarded(call: MethodCall, result: MethodChannel.Result) {
        if (!initialized) {
            result.error("not_initialized", "TopOn SDK has not been initialized", null)
            return
        }
        if (pendingLoadResult != null || pendingShowResult != null) {
            result.error("busy", "A rewarded ad request is already in progress", null)
            return
        }
        val placementId = call.argument<String>("placementId")
        val userId = call.argument<String>("userId")
        val customData = call.argument<String>("customData")
        if (placementId.isNullOrBlank() || userId.isNullOrBlank() || customData.isNullOrBlank()) {
            result.error("invalid_configuration", "TopOn rewarded placementId, userId, or customData is empty", null)
            return
        }
        rewardedAd?.destroyAd()
        earnedReward = false
        pendingLoadResult = result
        rewardedAd = TURewardVideoAd(applicationContext, placementId).apply {
            setLocalExtra(
                hashMapOf<String, Any>(
                    TUAdConst.KEY.USER_ID to userId,
                    TUAdConst.KEY.USER_CUSTOM_DATA to customData,
                )
            )
            setAdListener(rewardedListener)
            load()
        }
    }

    private fun showRewarded(result: MethodChannel.Result) {
        val currentActivity = activity
        val ad = rewardedAd
        if (currentActivity == null) {
            result.error("activity_unavailable", "No Android activity is available to show rewarded ad", null)
            return
        }
        if (ad == null || !ad.isAdReady) {
            result.error("not_ready", "TopOn rewarded ad is not ready", null)
            return
        }
        pendingShowResult = result
        earnedReward = false
        ad.show(currentActivity)
    }

    private val rewardedListener = object : TURewardVideoListener {
        override fun onRewardedVideoAdLoaded() {
            pendingLoadResult?.success(true)
            pendingLoadResult = null
        }

        override fun onRewardedVideoAdFailed(error: AdError) {
            pendingLoadResult?.error("load_failed", describe(error), null)
            pendingLoadResult = null
        }

        override fun onRewardedVideoAdPlayStart(adInfo: TUAdInfo) = Unit

        override fun onRewardedVideoAdPlayEnd(adInfo: TUAdInfo) = Unit

        override fun onRewardedVideoAdPlayFailed(error: AdError, adInfo: TUAdInfo) {
            pendingShowResult?.error("show_failed", describe(error), null)
            pendingShowResult = null
            rewardedAd?.destroyAd()
            rewardedAd = null
        }

        override fun onRewardedVideoAdClosed(adInfo: TUAdInfo) {
            pendingShowResult?.success(mapOf("rewarded" to earnedReward))
            pendingShowResult = null
            rewardedAd?.destroyAd()
            rewardedAd = null
        }

        override fun onRewardedVideoAdPlayClicked(adInfo: TUAdInfo) = Unit

        override fun onReward(adInfo: TUAdInfo) {
            earnedReward = true
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun describe(error: AdError): String =
        "code=${error.code}, desc=${error.desc}, platformCode=${error.platformCode}, platformMessage=${error.platformMSG}"
}

private class ToponBannerViewFactory(
    private val isInitialized: () -> Boolean,
    private val onBannerStateChanged: (Int, Boolean) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val placementId = (args as? Map<*, *>)?.get("placementId") as? String
        return ToponBannerPlatformView(context, placementId, isInitialized(), viewId, onBannerStateChanged)
    }
}

private class ToponBannerPlatformView(
    context: Context,
    placementId: String?,
    initialized: Boolean,
    viewId: Int,
    onBannerStateChanged: (Int, Boolean) -> Unit,
) : PlatformView {
    private val bannerView = TUBannerView(context).apply {
        if (initialized && !placementId.isNullOrBlank()) {
            setPlacementId(placementId)
            setLocalExtra(
                hashMapOf<String, Any>(
                    TUAdConst.KEY.AD_WIDTH to BANNER_WIDTH_DP,
                    TUAdConst.KEY.AD_HEIGHT to BANNER_HEIGHT_DP,
                )
            )
            setBannerAdListener(object : TUBannerListener {
                override fun onBannerLoaded() = onBannerStateChanged(viewId, true)
                override fun onBannerFailed(error: AdError) = onBannerStateChanged(viewId, false)
                override fun onBannerClicked(adInfo: TUAdInfo) = Unit
                override fun onBannerShow(adInfo: TUAdInfo) = Unit
                override fun onBannerClose(adInfo: TUAdInfo) = Unit
                override fun onBannerAutoRefreshed(adInfo: TUAdInfo) = Unit
                override fun onBannerAutoRefreshFail(error: AdError) = Unit
            })
            loadAd()
        } else {
            onBannerStateChanged(viewId, false)
        }
    }

    override fun getView(): View = bannerView

    override fun dispose() {
        bannerView.destroy()
    }
}

private const val BANNER_WIDTH_DP = 320
private const val BANNER_HEIGHT_DP = 50
