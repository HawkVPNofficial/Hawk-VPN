import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/reward_message.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FreeTrafficView extends ConsumerWidget {
  const FreeTrafficView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final appConfig = ref.watch(backendAppConfigStateProvider);
    final user = ref.watch(backendUserStateProvider);
    final todayRewardBytes = user?.todayRewardBytes ?? 0;
    final checkedInToday = user?.checkedInToday ?? false;
    final checkInLoading = ref.watch(loadingProvider(LoadingTag.checkIn));
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
          _TaskCard(
            icon: '🎬',
            title: appLocalizations.watchRewardVideo,
            reward: formatRewardMb(appConfig.adRewardMb),
            subtitle: appLocalizations.comingSoon,
            actionLabel: appLocalizations.comingSoon,
            actionEnabled: false,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
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
