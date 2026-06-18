import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/reward_message.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountProfileView extends ConsumerWidget {
  const AccountProfileView({super.key});

  String _createdAtText(int createdAt) {
    if (createdAt <= 0) return '--';
    return DateTime.fromMillisecondsSinceEpoch(createdAt).showFull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(backendUserStateProvider);
    final rows = [
      (context.appLocalizations.deviceId, globalState.deviceId),
      (context.appLocalizations.inviteCode, user?.inviteCode ?? ''),
      (
        context.appLocalizations.registerTime,
        _createdAtText(user?.createdAt ?? 0),
      ),
    ];
    return CommonScaffold(
      title: context.appLocalizations.personalProfile,
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 0),
        itemBuilder: (_, index) {
          final row = rows[index];
          return ListItem(
            title: Text(row.$1),
            subtitle: Text(row.$2.takeFirstValid(['--'])),
            onTap: row.$2.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: row.$2));
                    context.showNotifier(context.appLocalizations.copied);
                  },
          );
        },
      ),
    );
  }
}

class InviteCodeSubmitView extends ConsumerStatefulWidget {
  const InviteCodeSubmitView({super.key});

  @override
  ConsumerState<InviteCodeSubmitView> createState() =>
      _InviteCodeSubmitViewState();
}

class _InviteCodeSubmitViewState extends ConsumerState<InviteCodeSubmitView> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final loading = ref.read(loadingProvider(LoadingTag.inviteCode).notifier);
    loading.start();
    try {
      final reward = await ref
          .read(profilesActionProvider.notifier)
          .submitInviteCode(_controller.text.trim().toUpperCase());
      if (mounted) {
        await globalState.showMessage(
          title: context.appLocalizations.rewardReceived,
          message: rewardMessageSpan(context, reward.rewardBytes),
          cancelable: false,
        );
      }
    } catch (e) {
      if (mounted) {
        await globalState.showMessage(
          title: context.appLocalizations.inviteCodeSubmitFailed,
          message: TextSpan(text: request.unwrapBackendError(e).toString()),
        );
      }
    } finally {
      await loading.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(backendUserStateProvider);
    final appConfig = ref.watch(backendAppConfigStateProvider);
    final isLoading = ref.watch(loadingProvider(LoadingTag.inviteCode));
    final submitted = user?.inviteCodeSubmitted == true;
    return CommonScaffold(
      title: context.appLocalizations.submitInviteCode,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (submitted)
            CommonCard(
              onPressed: () {},
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.appLocalizations.inviteCodeAlreadySubmitted,
                        style: context.textTheme.titleMedium?.toSoftBold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: context.appLocalizations.friendInviteCode,
                      hintText: 'ABC-123',
                      helperText: context.appLocalizations.inviteCodeHint(
                        appConfig.invitedRewardMb,
                      ),
                    ),
                    validator: (value) {
                      final code = value?.trim().toUpperCase() ?? '';
                      if (!RegExp(
                        r'^[A-Z0-9]{3}-[A-Z0-9]{3}$',
                      ).hasMatch(code)) {
                        return context.appLocalizations.inviteCodeInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.appLocalizations.submitInviteCode),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
