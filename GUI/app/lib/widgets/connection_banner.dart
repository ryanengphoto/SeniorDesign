import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.connected,
    required this.mode,
    this.detail,
    this.errorMessage,
    this.supportsReconnect = false,
    this.onReconnect,
  });

  final bool connected;
  final String mode;
  final String? detail;
  final String? errorMessage;
  final bool supportsReconnect;
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context) {
    final lower = mode.toLowerCase();
    final isError = lower.contains('error');
    final isReconnecting = lower.contains('reconnect');
    final showRetry = supportsReconnect &&
        onReconnect != null &&
        (isError || isReconnecting);

    final statusLabel = isReconnecting
        ? 'Reconnecting…'
        : (isError
            ? 'Serial error'
            : (connected ? 'Connected' : 'Waiting…'));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError || isReconnecting
                ? HubColors.danger
                : (connected ? HubColors.ok : HubColors.muted),
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusLabel,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: HubColors.muted,
                ),
              ),
              if (detail != null && detail!.isNotEmpty)
                Text(
                  detail!,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: HubColors.muted,
                  ),
                ),
              if ((isError || isReconnecting) &&
                  errorMessage != null &&
                  errorMessage!.isNotEmpty)
                Text(
                  errorMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    color: HubColors.danger,
                  ),
                ),
            ],
          ),
        ),
        if (showRetry) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: onReconnect,
            style: TextButton.styleFrom(
              foregroundColor: HubColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: HubColors.border),
          ),
          child: Text(
            mode.toUpperCase(),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              color: isError || isReconnecting
                  ? HubColors.danger
                  : HubColors.accent,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}
