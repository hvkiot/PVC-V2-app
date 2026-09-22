import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/services/ble_command_controller.dart';

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (pamMode, firmwareVersion) = ref.watch(
      machineDataProvider.select((d) => (d.pamMode, d.firmwareVersion)),
    );

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          // Header Section: Branding
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.onSurface.withAlpha(25)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandCard(
                  label: 'Designed and Developed by HVK',
                  imagePath: 'assets/HVK.png',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                SizedBox(width: 10),
                BrandCard(
                  label: 'Powered by WEST',
                  imagePath: 'assets/WEST.png',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                SizedBox(width: 10),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _ConfigViewSelector(
                  pamMode: pamMode,
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                Divider(color: colorScheme.onSurface.withAlpha(25)),
                Semantics(
                  label: 'Firmware Update',
                  button: true,
                  child: _DrawerItem(
                    icon: Icons.system_update,
                    label: 'Firmware Update',
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.ota);
                    },
                  ),
                ),
                if (kDebugMode) ...[
                  Divider(color: colorScheme.onSurface.withAlpha(25)),
                  Semantics(
                    label: 'Serial Monitor',
                    button: true,
                    child: _DrawerItem(
                      icon: Icons.terminal,
                      label: 'Serial Monitor',
                      onTap: () {
                        Navigator.pop(context);
                        context.go(AppRoutes.serialMonitor);
                      },
                    ),
                  ),
                ],
                Divider(color: colorScheme.onSurface.withAlpha(25)),
                Semantics(
                  label: 'Disconnect Device',
                  button: true,
                  child: _DrawerItem(
                    icon: Icons.bluetooth_disabled_outlined,
                    label: 'DISCONNECT DEVICE',
                    isDestructive: true,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Disconnect Device'),
                          content: const Text(
                            'Are you sure you want to disconnect from the current device?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('DISCONNECT'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(bleProvider.notifier).disconnectFromDevice();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Footer Section: Version Info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'PVC Firmware v$firmwareVersion',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Configuration" section — lets the user explicitly switch the ACTUAL PAM
/// hardware MODE (STD/EXP) via [BleCommandController.setPamMode], which in
/// turn is the single source of truth for which config screen (Basic/
/// Advanced) [ConfigScreen] shows. This is now the ONLY place in the app
/// that changes PAM MODE — never automatically on connect/reconnect, never
/// as a side effect of a Basic/Advanced Config save. (Phase 13, 2026-09:
/// CONFIG_VIEW — the old, separate F|-merge-routing app-preference cache
/// this comment used to distinguish PAM MODE from — has been removed
/// entirely; [MachineData.pamMode] is now the only routing state.) The
/// selection shown here is always derived from [MachineData.pamMode] —
/// never a locally-held selection — so it stays correct even if MODE
/// changes from elsewhere, and updates automatically once the ESP's
/// D|PAM_MODE delta confirms the change.
class _ConfigViewSelector extends ConsumerWidget {
  final String pamMode;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _ConfigViewSelector({
    required this.pamMode,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // pamMode only ever carries 'STD' or 'EXP' (see PAM_MODE parsing in
    // machine_data.dart); anything unexpected falls back to Basic.
    final current = pamMode == 'EXP' ? 'EXP' : 'STD';
    final pin15 = ref.watch(machineDataProvider.select((c) => c.pin15));
    final pin6 = ref.watch(machineDataProvider.select((c) => c.pin6));
    final enabled = pin15 || pin6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIGURATION',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Configuration view',
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'STD', label: const Text('Basic-STD')),
                ButtonSegment(value: 'EXP', label: const Text('Advanced-EXP')),
              ],
              selected: {current},
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  states,
                ) {
                  if (states.contains(WidgetState.disabled)) {
                    return Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3);
                  }
                  if (states.contains(WidgetState.selected)) {
                    return Theme.of(context).colorScheme.primary;
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((
                  states,
                ) {
                  if (states.contains(WidgetState.disabled)) {
                    return Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38);
                  }
                  if (states.contains(WidgetState.selected)) {
                    return Theme.of(context).colorScheme.onPrimary;
                  }
                  return Theme.of(context).colorScheme.onSurface;
                }),
              ),
              // When enabled is false, !enabled becomes true, making the button interactive.
              onSelectionChanged: !enabled
                  ? (selection) {
                      Navigator.pop(
                        context,
                      ); // Close the drawer immediately on tap
                      final target = selection.first;
                      if (target == current) return;
                      unawaited(
                        ref.read(bleCommandProvider).setPamMode(target),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemColor = isDestructive ? colorScheme.error : null;

    return ListTile(
      leading: Icon(icon, size: 22, color: itemColor),
      title: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: itemColor,
        ),
      ),
      onTap: onTap,
    );
  }
}

class BrandCard extends StatelessWidget {
  final String label;
  final String imagePath;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const BrandCard({
    super.key,
    required this.label,
    required this.imagePath,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 125,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(8),
        child: Semantics(
          label: label,
          button: true,
          enabled: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.contains('HVK')
                    ? 'Designed & Developed by'
                    : 'Powered by',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Image.asset(imagePath),
            ],
          ),
        ),
      ),
    );
  }
}
