import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/reward_message.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class FreeTrafficView extends ConsumerStatefulWidget {
  const FreeTrafficView({super.key});

  @override
  ConsumerState<FreeTrafficView> createState() => _FreeTrafficViewState();
}

class _FreeTrafficViewState extends ConsumerState<FreeTrafficView> {
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  bool _isRewardedAdLoaded = false;
  bool _isRewardedAdLoadFailed = false;
  bool _earnedReward = false;

  String get _rewardedAdUnitId {
    return resolveRewardedAdUnitId(releaseMode: kReleaseMode);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && showGoogleAds) {
        _loadRewardedAd();
      }
    });
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final appConfig = ref.watch(backendAppConfigStateProvider);
    final user = ref.watch(backendUserStateProvider);
    final todayRewardBytes = user?.todayRewardBytes ?? 0;
    final checkedInToday = user?.checkedInToday ?? false;
    final rewardedAdEnabled =
        showGoogleAds && (user?.rewardedAdEnabled ?? false);
    final rewardedAdWatchedToday = user?.rewardedAdWatchedToday ?? 0;
    final rewardedAdDailyLimit = user?.rewardedAdDailyLimit ?? 3;
    final rewardedAdCompleted =
        rewardedAdDailyLimit > 0 &&
        rewardedAdWatchedToday >= rewardedAdDailyLimit;
    final checkInLoading = ref.watch(loadingProvider(LoadingTag.checkIn));
    final rewardedAdLoading = ref.watch(loadingProvider(LoadingTag.rewardedAd));
    final rewardedAdBusy = rewardedAdLoading || _isRewardedAdLoading;
    final canWatchRewardedAd =
        Platform.isAndroid &&
        rewardedAdEnabled &&
        !rewardedAdCompleted &&
        !rewardedAdBusy;
    return CommonScaffold(
      title: appLocalizations.freeTraffic,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            appLocalizations.freeTrafficSubtitle,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.toLight,
          ),
          const SizedBox(height: 24),
          Text(
            appLocalizations.dailyTasks,
            style: context.textTheme.titleMedium?.toSoftBold,
          ),
          const SizedBox(height: 12),
          if (showGoogleAds) ...[
            _TaskCard(
              icon: '🎬',
              title: appLocalizations.watchRewardVideo,
              reward: formatRewardMb(appConfig.adRewardMb),
              subtitle: appLocalizations.todayTaskProgress(
                rewardedAdWatchedToday,
                rewardedAdDailyLimit,
              ),
              actionLabel: _rewardedAdActionLabel(
                context,
                rewardedAdEnabled: rewardedAdEnabled,
                rewardedAdCompleted: rewardedAdCompleted,
                rewardedAdLoading: rewardedAdBusy,
              ),
              actionEnabled: canWatchRewardedAd,
              isLoading: rewardedAdBusy,
              onPressed: () => _handleRewardedAd(context, ref),
            ),
            const SizedBox(height: 12),
          ],
          _TaskCard(
            icon: '📅',
            title: appLocalizations.dailyCheckIn,
            reward: formatRewardMb(appConfig.checkInRewardMb),
            subtitle: checkedInToday ? appLocalizations.checkedInToday : null,
            actionLabel: checkInLoading
                ? appLocalizations.loading
                : checkedInToday
                ? appLocalizations.checkedInToday
                : appLocalizations.checkIn,
            actionEnabled: !checkInLoading && !checkedInToday,
            isLoading: checkInLoading,
            onPressed: () => _handleCheckIn(context, ref),
          ),
          const SizedBox(height: 12),
          _TaskCard(
            icon: '👥',
            title: appLocalizations.inviteFriends,
            reward: appLocalizations.inviteRewardPerPerson(
              appConfig.inviteRewardMb,
            ),
            subtitle: null,
            trailing: const Icon(Icons.chevron_right),
            onPressed: () {
              ref
                  .read(currentPageLabelProvider.notifier)
                  .toPage(PageLabel.invite);
            },
          ),
          const SizedBox(height: 28),
          _TodayRewardCard(todayRewardBytes: todayRewardBytes),
        ],
      ),
    );
  }

  String _rewardedAdActionLabel(
    BuildContext context, {
    required bool rewardedAdEnabled,
    required bool rewardedAdCompleted,
    required bool rewardedAdLoading,
  }) {
    final appLocalizations = context.appLocalizations;
    if (rewardedAdCompleted) {
      return appLocalizations.todayCompleted;
    }
    if (!Platform.isAndroid || !rewardedAdEnabled) {
      return appLocalizations.rewardedAdUnavailable;
    }
    if (rewardedAdLoading) {
      return appLocalizations.loading;
    }
    if (_isRewardedAdLoading) {
      return appLocalizations.loading;
    }
    if (_isRewardedAdLoadFailed) {
      return appLocalizations.reload;
    }
    if (!_isRewardedAdLoaded) {
      return appLocalizations.reload;
    }
    return appLocalizations.watch;
  }

  void _loadRewardedAd() {
    if (_isRewardedAdLoading) {
      commonPrint.log('激励视频广告正在加载中，忽略重复加载请求');
      return;
    }
    final adUnitId = _rewardedAdUnitId;
    if (!showGoogleAds) {
      commonPrint.log('激励视频广告未加载：SHOW_GOOGLE_ADS=false，广告入口已关闭');
      return;
    }
    if (!Platform.isAndroid) {
      commonPrint.log('激励视频广告未加载：当前不是 Android 平台');
      return;
    }
    if (adUnitId.isEmpty) {
      commonPrint.log('激励视频广告未加载：广告位 ID 为空，请检查 ADMOB_REWARDED_AD_UNIT_ID');
      return;
    }
    commonPrint.log(
      '开始加载激励视频广告：广告位=$adUnitId，'
      'releaseMode=$kReleaseMode，'
      'configured=${configuredRewardedAdUnitId.isNotEmpty}',
    );
    _rewardedAd?.dispose();
    _rewardedAd = null;
    setState(() {
      _isRewardedAdLoading = true;
      _isRewardedAdLoaded = false;
      _isRewardedAdLoadFailed = false;
    });
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            commonPrint.log('激励视频广告已加载，但页面已销毁，立即释放广告对象');
            ad.dispose();
            return;
          }
          commonPrint.log('激励视频广告加载成功：广告位=$adUnitId');
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoading = false;
            _isRewardedAdLoaded = true;
            _isRewardedAdLoadFailed = false;
          });
        },
        onAdFailedToLoad: (error) {
          commonPrint.log(
            '激励视频广告加载失败：广告位=$adUnitId，'
            '错误码=${error.code}，'
            '错误域=${error.domain}，'
            '错误信息=${error.message}，'
            '原因说明=${_describeAdLoadError(error)}',
            logLevel: LogLevel.warning,
          );
          if (!mounted) return;
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoading = false;
            _isRewardedAdLoaded = false;
            _isRewardedAdLoadFailed = true;
          });
        },
      ),
    );
  }

  Future<void> _handleRewardedAd(BuildContext context, WidgetRef ref) async {
    final ad = _rewardedAd;
    if (ad == null || !_isRewardedAdLoaded) {
      commonPrint.log('激励视频广告点击时还未加载完成，重新触发加载');
      _loadRewardedAd();
      return;
    }
    final loading = ref.read(loadingProvider(LoadingTag.rewardedAd).notifier);
    loading.start();
    _earnedReward = false;
    try {
      final session = await ref
          .read(profilesActionProvider.notifier)
          .createAdRewardSession();
      commonPrint.log('激励视频广告服务端会话创建成功：sessionId=${session.sessionId}');
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(customData: session.customData),
      );
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: (ad) async {
          commonPrint.log('激励视频广告已关闭：earnedReward=$_earnedReward');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoading = false;
            _isRewardedAdLoaded = false;
            _isRewardedAdLoadFailed = false;
          });
          if (_earnedReward) {
            await _refreshAfterReward(context, ref);
          }
          await loading.stop();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) async {
          commonPrint.log(
            '激励视频广告展示失败：错误码=${error.code}，'
            '错误域=${error.domain}，'
            '错误信息=${error.message}，'
            '原因说明=${_describeAdLoadError(error)}',
            logLevel: LogLevel.warning,
          );
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoading = false;
            _isRewardedAdLoaded = false;
            _isRewardedAdLoadFailed = true;
          });
          await loading.stop();
          _loadRewardedAd();
          if (context.mounted) {
            await globalState.showMessage(
              title: context.appLocalizations.rewardedAdFailed,
              message: TextSpan(text: error.message),
            );
          }
        },
      );
      await ad.show(
        onUserEarnedReward: (_, _) {
          commonPrint.log('激励视频广告已触发用户奖励回调');
          _earnedReward = true;
        },
      );
      setState(() {
        _rewardedAd = null;
        _isRewardedAdLoading = false;
        _isRewardedAdLoaded = false;
        _isRewardedAdLoadFailed = false;
      });
    } catch (e) {
      commonPrint.log(
        '激励视频广告流程异常：${request.unwrapBackendError(e)}',
        logLevel: LogLevel.warning,
      );
      ad.dispose();
      if (mounted) {
        setState(() {
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          _isRewardedAdLoaded = false;
          _isRewardedAdLoadFailed = true;
        });
      }
      _loadRewardedAd();
      await loading.stop();
      if (context.mounted) {
        await globalState.showMessage(
          title: context.appLocalizations.rewardedAdFailed,
          message: TextSpan(text: request.unwrapBackendError(e).toString()),
        );
      }
    }
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

  Future<void> _refreshAfterReward(BuildContext context, WidgetRef ref) async {
    final before = ref.read(backendUserStateProvider);
    var rewardBytes = 0;
    for (var i = 0; i < 3; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      await ref.read(profilesActionProvider.notifier).refreshBackendUser();
      final after = ref.read(backendUserStateProvider);
      rewardBytes =
          ((after?.todayRewardBytes ?? 0) - (before?.todayRewardBytes ?? 0))
              .clamp(0, 1 << 62);
      if (rewardBytes > 0) {
        break;
      }
    }
    if (!context.mounted) return;
    if (rewardBytes <= 0) {
      await globalState.showMessage(
        title: context.appLocalizations.rewardReceived,
        message: TextSpan(text: context.appLocalizations.rewardConfirming),
        cancelable: false,
      );
      return;
    }
    await globalState.showMessage(
      title: context.appLocalizations.rewardReceived,
      message: rewardMessageSpan(context, rewardBytes),
      cancelable: false,
    );
  }

  Future<void> _handleCheckIn(BuildContext context, WidgetRef ref) async {
    final loading = ref.read(loadingProvider(LoadingTag.checkIn).notifier);
    loading.start();
    try {
      final reward = await ref.read(profilesActionProvider.notifier).checkIn();
      if (context.mounted) {
        await globalState.showMessage(
          title: context.appLocalizations.rewardReceived,
          message: rewardMessageSpan(context, reward.rewardBytes),
          cancelable: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        await globalState.showMessage(
          title: context.appLocalizations.checkInFailed,
          message: TextSpan(text: request.unwrapBackendError(e).toString()),
        );
      }
    } finally {
      await loading.stop();
    }
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.icon,
    required this.title,
    required this.reward,
    required this.onPressed,
    this.subtitle,
    this.actionLabel,
    this.actionEnabled = true,
    this.isLoading = false,
    this.trailing,
  });

  final String icon;
  final String title;
  final String reward;
  final String? subtitle;
  final String? actionLabel;
  final bool actionEnabled;
  final bool isLoading;
  final Widget? trailing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return CommonCard(
      onPressed: trailing != null ? onPressed : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textTheme.titleMedium?.toSoftBold),
                  const SizedBox(height: 3),
                  Text(
                    reward,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: context.textTheme.bodySmall?.toLight,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (actionLabel != null)
              FilledButton(
                onPressed: actionEnabled ? onPressed : null,
                child: isLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayRewardCard extends StatelessWidget {
  const _TodayRewardCard({required this.todayRewardBytes});

  final int todayRewardBytes;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      onPressed: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          children: [
            Text(
              context.appLocalizations.todayReceived,
              style: context.textTheme.titleSmall?.toLight,
            ),
            const SizedBox(height: 8),
            Text(
              formatTrafficBytes(todayRewardBytes),
              style: context.textTheme.headlineMedium?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
