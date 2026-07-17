import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final machineData = ref.watch(machineDataProvider);

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
                Container(
                  width: 125,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
              padding: EdgeInsets.all(8),
              child: Semantics(
                label: 'Designed and Developed by HVK',
                image: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Designed & Developed by',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Image.asset('assets/HVK.png'),
                  ],
                ),
              ),
                ),
                SizedBox(width: 10),
                Container(
                  width: 125,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
              padding: EdgeInsets.all(8),
              child: Semantics(
                label: 'Powered by WEST',
                image: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Powered by',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center
                    ),
                    Image.asset('assets/WEST.png'),
                  ],
                ),
              ),
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
              'PVC Firmware v${machineData.firmwareVersion}',
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
