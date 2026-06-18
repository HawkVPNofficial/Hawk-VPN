import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InviteView extends ConsumerWidget {
  const InviteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final appConfig = ref.watch(backendAppConfigStateProvider);
    final user = ref.watch(backendUserStateProvider);
    final inviteCode = user?.inviteCode ?? '';
    final summary = user?.invitationSummary;
    return CommonScaffold(
      title: appLocalizations.inviteFriends,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            appLocalizations.inviteFriendsSubtitle,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.toLight,
          ),
          const SizedBox(height: 24),
          CommonCard(
            onPressed: () {},
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 42)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appLocalizations.inviteRewardTitle(
                            appConfig.inviteRewardMb,
                          ),
                          style: context.textTheme.titleMedium?.toSoftBold,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appLocalizations.inviteRewardDesc(
                            appConfig.inviteRewardMb,
                          ),
                          style: context.textTheme.bodyMedium?.toLight,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _RulesCard(rewardMb: appConfig.inviteRewardMb),
          const SizedBox(height: 24),
          Text(
            appLocalizations.yourInviteCode,
            style: context.textTheme.titleSmall?.toLight,
          ),
          const SizedBox(height: 10),
          CommonCard(
            onPressed: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteCode.takeFirstValid(['--']),
                      textDirection: TextDirection.ltr,
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: inviteCode.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: inviteCode),
                            );
                            if (context.mounted) {
                              context.showNotifier(
                                appLocalizations.inviteCodeCopied,
                              );
                            }
                          },
                    child: Text(appLocalizations.copy),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _InviteStatCard(
                  value: '${summary?.successCount ?? 0}',
                  label: appLocalizations.successfulInvites,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InviteStatCard(
                  value: formatTrafficBytes(summary?.rewardTotalBytes ?? 0),
                  label: appLocalizations.trafficEarned,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rewardMb});

  final int rewardMb;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      onPressed: () {},
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.appLocalizations.inviteRules,
              style: context.textTheme.titleMedium?.toSoftBold,
            ),
            const SizedBox(height: 14),
            _RuleItem(index: 1, text: context.appLocalizations.inviteRuleOne),
            const SizedBox(height: 10),
            _RuleItem(
              index: 2,
              text: context.appLocalizations.inviteRuleTwo(rewardMb),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: context.colorScheme.primary.opacity15,
          child: Text(
            '$index',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: context.textTheme.bodyMedium?.toLight),
        ),
      ],
    );
  }
}

class _InviteStatCard extends StatelessWidget {
  const _InviteStatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      onPressed: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.toLight,
            ),
          ],
        ),
      ),
    );
  }
}
