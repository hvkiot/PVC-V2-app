// lib/screens/ota_screens/ota_screen.dart
// ============================================================
// OTA Screen — Firmware update via BLE
// Uses Riverpod, flutter_blue_plus ^2.1.0, GoRouter
// Matches your existing app structure (BleNotifier, custom_app_bar, etc.)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/ota_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';
import 'package:pvc_v2/widgets/custom_app_bar.dart';
import 'package:pvc_v2/theme/app_colors.dart';

class OtaScreen extends ConsumerWidget {
  const OtaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch OTA state
    final otaState = ref.watch(otaProvider);
    final otaNotifier = ref.read(otaProvider.notifier);
    final bleState = ref.watch(bleProvider);
    final BluetoothDevice? device = bleState.connectedDevice;

    final bool isConnected = device != null && device.isConnected;

    // Navigate to scan screen when upload finishes (success or error)
    ref.listen(otaProvider, (prev, next) {
      if (prev?.status != next.status &&
          (next.status == OtaStatus.success ||
              next.status == OtaStatus.error)) {
        otaNotifier.reset();
        ref.read(bleProvider.notifier).disconnectFromDevice();
        context.go(AppRoutes.home);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        otaNotifier.reset();
        final device = bleState.connectedDevice;
        if (device != null && context.mounted) {
          context.go(AppRoutes.details, extra: device);
        } else if (context.mounted) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: "Firmware Update", showLogo: true),
        body: SafeArea(
          child: ResponsiveWrapper(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Connection Status Banner ----
                  _ConnectionBanner(isConnected: isConnected),
                  const SizedBox(height: 24),

                  // ---- Firmware Info Card ----
                  _FirmwareInfoCard(otaState: otaState),
                  const SizedBox(height: 24),

                  // ---- Progress Section ----
                  if (otaState.isRunning ||
                      otaState.status == OtaStatus.success)
                    _ProgressSection(otaState: otaState),

                  if (otaState.isRunning ||
                      otaState.status == OtaStatus.success)
                    const SizedBox(height: 24),

                  // ---- Status Message ----
                  _StatusMessage(otaState: otaState),
                  const SizedBox(height: 32),

                  const Spacer(),

                  // ---- Action Button ----
                  _ActionButton(
                    otaState: otaState,
                    isConnected: isConnected,
                    onUpload: () {
                      if (device != null) {
                        ref.read(otaProvider.notifier).startOta(device);
                      }
                    },
                    onReset: () => otaNotifier.reset(),
                  ),

                  const SizedBox(height: 16),

                  // ---- Warning text ----
                  const _WarningText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Connection Banner ----
class _ConnectionBanner extends StatelessWidget {
  final bool isConnected;
  const _ConnectionBanner({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected
              ? isDark
                    ? AppColors.brandCyan
                    : AppColors.brandRed
              : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected
                ? isDark
                      ? AppColors.brandCyan
                      : AppColors.brandRed
                : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            isConnected
                ? "Device connected — ready to update"
                : "No device connected — scan first",
            style: TextStyle(
              color: isConnected
                  ? isDark
                        ? AppColors.brandCyan
                        : AppColors.brandRed
                  : Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Firmware Info Card ----
class _FirmwareInfoCard extends StatelessWidget {
  final OtaState otaState;
  const _FirmwareInfoCard({required this.otaState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.memory,
                color: isDark ? AppColors.brandCyan : AppColors.brandRed,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                "Firmware File",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (otaState.fileName != null) ...[
            _InfoRow(label: "File", value: otaState.fileName!),
            const SizedBox(height: 6),
            _InfoRow(
              label: "Size",
              value: "${(otaState.fileSize! / 1024).toStringAsFixed(1)} KB",
            ),
          ] else
            const Text(
              "No file selected",
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            "$label:",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---- Progress Section ----
class _ProgressSection extends StatelessWidget {
  final OtaState otaState;
  const _ProgressSection({required this.otaState});

  @override
  Widget build(BuildContext context) {
    final percent = (otaState.progress * 100).toStringAsFixed(1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Upload Progress",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              "$percent%",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.brandCyan : AppColors.brandRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: otaState.progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              otaState.status == OtaStatus.success
                  ? Colors.green
                  : isDark
                  ? AppColors.brandCyan
                  : AppColors.brandRed,
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Status Message ----
class _StatusMessage extends StatelessWidget {
  final OtaState otaState;
  const _StatusMessage({required this.otaState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color msgColor;
    IconData msgIcon;

    switch (otaState.status) {
      case OtaStatus.error:
        msgColor = Colors.red;
        msgIcon = Icons.error_outline;
        break;
      case OtaStatus.success:
        msgColor = Colors.green;
        msgIcon = Icons.check_circle_outline;
        break;
      case OtaStatus.idle:
      case OtaStatus.picking:
        msgColor = Colors.grey;
        msgIcon = Icons.info_outline;
        break;
      default:
        msgColor = isDark ? AppColors.brandCyan : AppColors.brandRed;
        msgIcon = Icons.upload_outlined;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(msgIcon, color: msgColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            otaState.message,
            style: TextStyle(color: msgColor, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ---- Action Button ----
class _ActionButton extends StatelessWidget {
  final OtaState otaState;
  final bool isConnected;
  final VoidCallback onUpload;
  final VoidCallback onReset;

  const _ActionButton({
    required this.otaState,
    required this.isConnected,
    required this.onUpload,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // After error or success: show Reset button
    if (otaState.status == OtaStatus.error ||
        otaState.status == OtaStatus.success) {
      return OutlinedButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.refresh),
        label: const Text("Reset"),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    // During upload: show disabled button with spinner
    if (otaState.isRunning) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: const Text("Uploading..."),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: isDark ? AppColors.brandCyan : AppColors.brandRed,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Idle: show Upload button
    return ElevatedButton.icon(
      onPressed: isConnected ? onUpload : null,
      icon: const Icon(Icons.upload_file),
      label: const Text("Select & Upload Firmware"),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: isDark ? AppColors.brandCyan : AppColors.brandRed,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
      ),
    );
  }
}

// ---- Warning Text ----
class _WarningText extends StatelessWidget {
  const _WarningText();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      "⚠ Keep the app and device near during update.\nDo not close the app or turn off the device.",
      textAlign: TextAlign.center,
      style: TextStyle(
        color: isDark ? Colors.orange : Colors.orange.shade700,
        fontSize: 12,
      ),
    );
  }
}
