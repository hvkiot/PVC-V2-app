import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  child: Image.asset('assets/HVK.png'),
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
                  child: Image.asset('assets/WEST.png'),
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
                _DrawerItem(
                  icon: Icons.save_outlined,
                  label: 'SAVE CONFIG',
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.history_outlined,
                  label: 'LOAD CONFIG',
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.drive_file_rename_outline_outlined,
                  label: 'RENAME CONFIG',
                  onTap: () => Navigator.pop(context),
                ),
                Divider(color: colorScheme.onSurface.withAlpha(25)),
                _DrawerItem(
                  icon: Icons.bluetooth_disabled_outlined,
                  label: 'DISCONNECT DEVICE',
                  isDestructive: true,
                  onTap: () {
                    ref.read(bleProvider.notifier).disconnectFromDevice();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          // Footer Section: Version Info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'PVC Firmware v2.0.1',
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
