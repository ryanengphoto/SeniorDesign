import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../protocol.dart';
import '../theme.dart';

/// Modal dialog presented to the operator when an HID keyboard is detected
/// on a downstream port.
///
/// Prompts the operator to confirm or isolate the device to prevent
/// unauthorized keystroke injection (BadUSB) before the port is authorized.
class KeyboardConfirmDialog extends StatelessWidget {
  const KeyboardConfirmDialog({
    super.key,
    required this.port,
    required this.onConfirm,
    this.onIsolate,
  });

  final PortStatus port;
  final VoidCallback onConfirm;
  final VoidCallback? onIsolate;

  static Future<void> show(
    BuildContext context, {
    required PortStatus port,
    required VoidCallback onConfirm,
    VoidCallback? onIsolate,
    void Function(BuildContext dialogContext)? onContextReady,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        onContextReady?.call(dialogContext);
        return KeyboardConfirmDialog(
          port: port,
          onConfirm: () {
            Navigator.of(dialogContext).pop();
            onConfirm();
          },
          onIsolate: onIsolate != null
              ? () {
                  Navigator.of(dialogContext).pop();
                  onIsolate();
                }
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HubColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HubColors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HubColors.warn.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: HubColors.warn.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.keyboard_outlined,
              color: HubColors.warn,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Keyboard Detected',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: HubColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PORT ${port.port + 1} PENDING AUTHORIZATION',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: HubColors.warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A keyboard or HID device was connected to Port ${port.port + 1}. '
              'To protect the host from keystroke injection attacks, '
              'operator confirmation is required before this device can communicate.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: HubColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HubColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HubColors.border),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _DetailPill(
                    label: 'Port',
                    value: 'Port ${port.port + 1}',
                  ),
                  _DetailPill(
                    label: 'VID',
                    value: port.vid,
                  ),
                  _DetailPill(
                    label: 'PID',
                    value: port.pid,
                  ),
                  _DetailPill(
                    label: 'Interface',
                    value: UsbClass.display(port.intClass),
                    isEmphasized: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (onIsolate != null)
          OutlinedButton(
            onPressed: onIsolate,
            style: OutlinedButton.styleFrom(
              foregroundColor: HubColors.danger,
              side: BorderSide(
                color: HubColors.danger.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Isolate port'),
          ),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: HubColors.ok,
            foregroundColor: HubColors.bg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Confirm keyboard'),
        ),
      ],
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  final String label;
  final String value;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEmphasized
              ? HubColors.ok.withValues(alpha: 0.5)
              : HubColors.border,
        ),
      ),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: HubColors.muted,
          ),
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 12,
                fontWeight: isEmphasized ? FontWeight.w600 : FontWeight.w500,
                color: isEmphasized ? HubColors.ok : HubColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
