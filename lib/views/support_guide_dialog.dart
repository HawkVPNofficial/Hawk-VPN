import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

enum SupportGuideDialogType { subscriptionFailed, trafficExhausted }

class SupportGuideDialog extends StatelessWidget {
  const SupportGuideDialog({super.key, required this.type});

  final SupportGuideDialogType type;

  @override
  Widget build(BuildContext context) {
    final localizations = context.appLocalizations;
    final isTrafficExhausted = type == SupportGuideDialogType.trafficExhausted;
    final title = isTrafficExhausted
        ? localizations.trafficExhaustedTitle
        : localizations.subscriptionFetchFailedTitle;
    final message = isTrafficExhausted
        ? localizations.trafficExhaustedMessage
        : localizations.subscriptionFetchFailedMessage;
    final primaryText = isTrafficExhausted
        ? localizations.contactSupportForTraffic
        : localizations.contactSupport;
    final secondaryText = isTrafficExhausted
        ? localizations.getFreeTraffic
        : localizations.tryAgain;
    final icon = isTrafficExhausted ? '📉' : '⚠️';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 290,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              _SupportPrimaryButton(
                text: primaryText,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: Colors.white70,
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(secondaryText, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportPrimaryButton extends StatelessWidget {
  const _SupportPrimaryButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF23D18B), Color(0xFF12B981)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
