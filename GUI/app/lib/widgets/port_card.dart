import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../protocol.dart';
import '../theme.dart';
import '../usb_names.dart';

/// One downstream port: identity, VID/PID/class metrics, Isolate/Restore.
class PortCard extends StatelessWidget {
  const PortCard({
    super.key,
    required this.port,
    required this.onCommand,
    this.onRequestConfirmKeyboard,
  });

  final PortStatus port;
  final void Function(CommandType cmd, int port) onCommand;
  final VoidCallback? onRequestConfirmKeyboard;

  @override
  Widget build(BuildContext context) {
    // Isolate is operator-only; system quarantine already cut the port.
    final canIsolate = port.state == PortState.authorized;
    final canRestore = port.state == PortState.manualBlocked ||
        port.state == PortState.quarantined ||
        port.threatCode > 0;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HubColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = _Identity(
            port: port,
            onRequestConfirmKeyboard: onRequestConfirmKeyboard,
          );
          final metrics = _MetricsRow(port: port);
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: 'Isolate',
                enabled: canIsolate,
                foreground: HubColors.danger,
                onPressed: () =>
                    onCommand(CommandType.isolatePort, port.port),
              ),
              _ActionButton(
                label: 'Restore',
                enabled: canRestore,
                foreground: HubColors.ok,
                onPressed: () =>
                    onCommand(CommandType.restorePort, port.port),
              ),
            ],
          );

          final narrow = constraints.maxWidth < 640;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                identity,
                const SizedBox(height: 8),
                actions,
                const SizedBox(height: 10),
                metrics,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  actions,
                ],
              ),
              const SizedBox(height: 10),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.port,
    this.onRequestConfirmKeyboard,
  });

  final PortStatus port;
  final VoidCallback? onRequestConfirmKeyboard;

  @override
  Widget build(BuildContext context) {
    final isPendingConfirm = port.state == PortState.pendingHidConfirm;
    final hasHardwareThreat = port.threatCode > 0 &&
        port.threatCode != ThreatCode.manualHostKill.value;
    final showReason = isPendingConfirm || hasHardwareThreat;
    final reasonText = isPendingConfirm
        ? 'Confirm keyboard?'
        : ThreatCode.fromValue(port.threatCode).summary;

    Widget badgeWidget = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: stateBackground(port.state),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stateBorder(port.state)),
      ),
      child: Text(
        port.state.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: stateForeground(port.state),
        ),
      ),
    );

    if (isPendingConfirm && onRequestConfirmKeyboard != null) {
      badgeWidget = InkWell(
        onTap: onRequestConfirmKeyboard,
        borderRadius: BorderRadius.circular(999),
        child: badgeWidget,
      );
    }

    Widget? reasonWidget;
    if (showReason) {
      final textWidget = Text(
        reasonText,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: HubColors.danger,
          height: 1.25,
        ),
      );
      if (isPendingConfirm && onRequestConfirmKeyboard != null) {
        reasonWidget = InkWell(
          onTap: onRequestConfirmKeyboard,
          child: textWidget,
        );
      } else {
        reasonWidget = textWidget;
      }
    }

    final hasDevice = port.state != PortState.disconnected ||
        !UsbNames.isZeroOrEmpty(port.vid);
    final deviceName = hasDevice
        ? (UsbNames.lookup(port.vid, port.pid) ?? 'Unknown device')
        : null;

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'PORT ${port.port + 1}',
          style: GoogleFonts.ibmPlexMono(
            fontSize: 12,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: HubColors.muted,
          ),
        ),
        badgeWidget,
        if (deviceName != null)
          Text(
            deviceName,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HubColors.muted,
            ),
          ),
        ?reasonWidget,
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.port});

  final PortStatus port;

  @override
  Widget build(BuildContext context) {
    final highlightHid = port.threatCode == ThreatCode.unauthorizedHid.value ||
        port.state == PortState.pendingHidConfirm;
    final isDisconnected = port.state == PortState.disconnected &&
        UsbNames.isZeroOrEmpty(port.vid);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Metric(
            label: 'VENDOR ID',
            hexValue: port.vid,
            decoded: isDisconnected ? '—' : UsbNames.lookupVendor(port.vid),
            protocolTooltip:
                'USB Vendor ID (idVendor)\n16-bit identifier in the Device Descriptor assigned by the USB-IF to identify the hardware manufacturer.',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Metric(
            label: 'PRODUCT ID',
            hexValue: port.pid,
            decoded: isDisconnected
                ? '—'
                : UsbNames.lookupProduct(port.vid, port.pid),
            protocolTooltip:
                'USB Product ID (idProduct)\n16-bit identifier in the Device Descriptor assigned by the manufacturer to identify the specific product model.',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Metric(
            label: 'DEVICE CLASS',
            hexValue: port.devClass,
            decoded: isDisconnected
                ? '—'
                : UsbNames.lookupDeviceClass(port.devClass),
            protocolTooltip:
                'USB Device Class (bDeviceClass)\nDeclares the primary category in the Device Descriptor, defining high-level architecture or delegating functions to interfaces.',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Metric(
            label: 'INTERFACE CLASS',
            hexValue: port.intClass,
            decoded: isDisconnected
                ? '—'
                : UsbNames.lookupInterfaceClass(port.intClass),
            emphasize: highlightHid,
            protocolTooltip:
                'USB Interface Class (bInterfaceClass)\nDeclares the functional operating category of an individual interface in the Interface Descriptor.',
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.hexValue,
    required this.decoded,
    required this.protocolTooltip,
    this.emphasize = false,
  });

  final String label;
  final String hexValue;
  final String decoded;
  final String protocolTooltip;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: protocolTooltip,
          preferBelow: false,
          verticalOffset: 16,
          waitDuration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HubColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HubColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            height: 1.35,
            color: HubColors.text,
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.help,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: emphasize ? HubColors.danger : HubColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline,
                  size: 11,
                  color: (emphasize ? HubColors.danger : HubColors.muted)
                      .withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hexValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 12,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
            color: emphasize ? HubColors.danger : HubColors.text,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          decoded,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
            color: emphasize ? HubColors.danger : HubColors.muted,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.35),
        side: BorderSide(
          color: enabled
              ? foreground.withValues(alpha: 0.4)
              : HubColors.border,
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(label),
    );
  }
}
