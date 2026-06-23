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
  bool _isRewardedAdLoaded = false;
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
    final canWatchRewardedAd =
        Platform.isAndroid &&
        rewardedAdEnabled &&
        !rewardedAdCompleted &&
        _isRewardedAdLoaded &&
        !rewardedAdLoading;
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
                rewardedAdLoading: rewardedAdLoading,
              ),
              actionEnabled: canWatchRewardedAd,
              isLoading: rewardedAdLoading,
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
    if (!_isRewardedAdLoaded) {
      return appLocalizations.loading;
    }
    return appLocalizations.watch;
  }

  void _loadRewardedAd() {
    final adUnitId = _rewardedAdUnitId;
    if (!showGoogleAds || !Platform.isAndroid || adUnitId.isEmpty) return;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    setState(() {
      _isRewardedAdLoaded = false;
    });
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoaded = false;
          });
        },
      ),
    );
  }

  Future<void> _handleRewardedAd(BuildContext context, WidgetRef ref) async {
    final ad = _rewardedAd;
    if (ad == null || !_isRewardedAdLoaded) {
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
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(customData: session.customData),
      );
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: (ad) async {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoaded = false;
          });
          if (_earnedReward) {
            await _refreshAfterReward(context, ref);
          }
          await loading.stop();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) async {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoaded = false;
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
          _earnedReward = true;
        },
      );
      setState(() {
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
      });
    } catch (e) {
      ad.dispose();
      if (mounted) {
        setState(() {
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
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
