import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.connected,
    required this.mode,
    this.detail,
  });

  final bool connected;
  final String mode;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final isError = mode.toLowerCase().contains('error');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError
                ? HubColors.danger
                : (connected ? HubColors.ok : HubColors.danger),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          isError
              ? 'Serial error'
              : (connected ? 'Connected' : 'Reconnecting…'),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: HubColors.muted,
          ),
        ),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(
            detail!,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              color: HubColors.muted,
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
              color: isError ? HubColors.danger : HubColors.accent,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}
