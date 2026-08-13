import 'dart:io';

import 'package:fl_clash/common/build_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToponAds {
  ToponAds._();

  static const _channel = MethodChannel('com.follow.clash/topon_ads');
  static const _bannerViewType = 'com.follow.clash/topon_banner';
  static final _bannerStates = <int, bool>{};
  static final _bannerListeners = <int, ValueChanged<bool>>{};
  static var _bannerHandlerRegistered = false;

  static Future<bool> initialize() async {
    if (!Platform.isAndroid || !showToponAds) {
      return false;
    }
    _registerBannerHandler();
    return await _channel.invokeMethod<bool>('initialize', {
          'appId': toponAppId,
          'appKey': toponAppKey,
          'debug': !kReleaseMode,
          'debugKey': toponSdkDebugKey,
        }) ??
        false;
  }

  static Future<void> loadRewarded({
    required String userId,
    required String customData,
  }) async {
    await _channel.invokeMethod<void>('loadRewarded', {
      'placementId': toponRewardedPlacementId,
      'userId': userId,
      'customData': customData,
    });
  }

  static Future<bool> showRewarded() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'showRewarded',
    );
    return result?['rewarded'] == true;
  }

  static Widget banner() {
    if (!Platform.isAndroid ||
        !showToponAds ||
        toponBannerPlacementId.isEmpty) {
      return const SizedBox.shrink();
    }
    _registerBannerHandler();
    return const _ToponBanner();
  }

  static void _registerBannerHandler() {
    if (_bannerHandlerRegistered) return;
    _bannerHandlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'bannerState' || call.arguments is! Map) return;
      final arguments = call.arguments as Map<dynamic, dynamic>;
      final viewId = (arguments['viewId'] as num?)?.toInt();
      if (viewId == null) return;
      final loaded = arguments['loaded'] == true;
      _bannerStates[viewId] = loaded;
      _bannerListeners[viewId]?.call(loaded);
    });
  }

  static void registerBannerListener(int viewId, ValueChanged<bool> listener) {
    _bannerListeners[viewId] = listener;
    listener(_bannerStates[viewId] ?? false);
  }

  static void unregisterBannerListener(int viewId) {
    _bannerListeners.remove(viewId);
    _bannerStates.remove(viewId);
  }
}

class _ToponBanner extends StatefulWidget {
  const _ToponBanner();

  @override
  State<_ToponBanner> createState() => _ToponBannerState();
}

class _ToponBannerState extends State<_ToponBanner> {
  int? _viewId;
  var _loaded = false;

  @override
  void dispose() {
    final viewId = _viewId;
    if (viewId != null) {
      ToponAds.unregisterBannerListener(viewId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _loaded ? 66 : 0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AndroidView(
          viewType: ToponAds._bannerViewType,
          creationParams: {'placementId': toponBannerPlacementId},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      ),
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    ToponAds.registerBannerListener(viewId, (loaded) {
      if (mounted && _loaded != loaded) {
        setState(() => _loaded = loaded);
      }
    });
  }
}
