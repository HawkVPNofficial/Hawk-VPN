import 'dart:io';

import 'package:fl_clash/common/common.dart';
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
    if (!Platform.isAndroid ||
        adUnitId.isEmpty ||
        width <= 0 ||
        _lastWidth == width) {
      return;
    }
    _lastWidth = width;
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          width.truncate(),
        ) ??
        AdSize.banner;
    if (!mounted) {
      return;
    }
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
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
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

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
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
