import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../protocol.dart';
import '../theme.dart';

class ThreatBadge extends StatelessWidget {
  const ThreatBadge({super.key, required this.threatCode});

  final int threatCode;

  @override
  Widget build(BuildContext context) {
    if (threatCode == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HubColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HubColors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        ThreatCode.summaryFor(threatCode),
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: HubColors.danger,
        ),
      ),
    );
  }
}

Color stateForeground(PortState state) {
  return switch (state) {
    PortState.authorized => HubColors.ok,
    PortState.quarantined ||
    PortState.manualBlocked ||
    PortState.pendingHidConfirm =>
      HubColors.danger,
    PortState.disconnected => HubColors.muted,
  };
}

Color stateBackground(PortState state) {
  return stateForeground(state).withValues(alpha: 0.1);
}

Color stateBorder(PortState state) {
  return stateForeground(state).withValues(alpha: 0.3);
}
