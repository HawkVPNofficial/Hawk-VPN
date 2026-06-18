import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

InlineSpan rewardMessageSpan(BuildContext context, int rewardBytes) {
  final textTheme = context.textTheme;
  return TextSpan(
    children: [
      TextSpan(text: '🎉\n', style: textTheme.headlineMedium),
      TextSpan(
        text: context.appLocalizations.rewardReceivedMessage(
          formatTrafficBytes(rewardBytes),
        ),
      ),
    ],
  );
}
