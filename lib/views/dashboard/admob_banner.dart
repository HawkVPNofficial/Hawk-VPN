import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DashboardAdMobBanner extends StatefulWidget {
  const DashboardAdMobBanner({super.key});

  @override
  State<DashboardAdMobBanner> createState() => _DashboardAdMobBannerState();
}

class _DashboardAdMobBannerState extends State<DashboardAdMobBanner> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoaded = false;
  double? _lastWidth;

  String get _adUnitId {
    return resolveBannerAdUnitId(releaseMode: kReleaseMode);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd(double width) async {
    final adUnitId = _adUnitId;
    if (!showGoogleAds) {
      commonPrint.log('横幅广告未加载：SHOW_GOOGLE_ADS=false，广告入口已关闭');
      return;
    }
    if (!Platform.isAndroid) {
      commonPrint.log('横幅广告未加载：当前不是 Android 平台');
      return;
    }
    if (adUnitId.isEmpty) {
      commonPrint.log('横幅广告未加载：广告位 ID 为空，请检查 ADMOB_BANNER_AD_UNIT_ID');
      return;
    }
    if (width <= 0) {
      commonPrint.log('横幅广告未加载：容器宽度无效，width=$width');
      return;
    }
    if (_lastWidth == width) {
      return;
    }
    _lastWidth = width;
    commonPrint.log(
      '开始加载横幅广告：广告位=$adUnitId，'
      'releaseMode=$kReleaseMode，'
      'configured=${configuredBannerAdUnitId.isNotEmpty}，'
      '容器宽度=$width',
    );
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          width.truncate(),
        ) ??
        AdSize.banner;
    if (!mounted) {
      commonPrint.log('横幅广告尺寸已获取，但页面已销毁，停止加载');
      return;
    }
    commonPrint.log('横幅广告尺寸：${adSize.width}x${adSize.height}');
    await _bannerAd?.dispose();
    setState(() {
      _adSize = adSize;
      _isLoaded = false;
    });
    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            commonPrint.log('横幅广告已加载，但页面已销毁，立即释放广告对象');
            ad.dispose();
            return;
          }
          commonPrint.log('横幅广告加载成功：广告位=$adUnitId');
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          commonPrint.log(
            '横幅广告加载失败：广告位=$adUnitId，'
            '错误码=${error.code}，'
            '错误域=${error.domain}，'
            '错误信息=${error.message}，'
            '原因说明=${_describeAdLoadError(error)}',
            logLevel: LogLevel.warning,
          );
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );
    await bannerAd.load();
  }

  String _describeAdLoadError(AdError error) {
    final message = error.message.toLowerCase();
    if (error.code == 3 || message.contains('no fill')) {
      return '无广告填充。常见原因：广告位刚创建还未生效、当前地区/设备暂无可返回广告、应用包名或广告位配置不匹配、账号/应用审核状态限制。';
    }
    if (error.code == 0 || message.contains('internal')) {
      return '广告 SDK 内部错误，通常可稍后重试；如果持续出现，请检查 Google Play 服务和广告位配置。';
    }
    if (error.code == 1 || message.contains('invalid request')) {
      return '广告请求无效，请重点检查广告位 ID、应用 ID、包名和 AdMob 后台配置是否一致。';
    }
    if (error.code == 2 || message.contains('network')) {
      return '网络错误，请检查设备网络、代理、DNS、Google Play 服务连通性。';
    }
    return '未知原因，请结合错误码、错误域和错误信息继续排查。';
  }

  @override
  Widget build(BuildContext context) {
    if (!showGoogleAds || !Platform.isAndroid) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width.isFinite && width > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadAd(width);
            }
          });
        }
        final adSize = _adSize;
        if (!_isLoaded || _bannerAd == null || adSize == null) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: adSize.width.toDouble(),
              height: adSize.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        );
      },
    );
  }
}
