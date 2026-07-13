import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/screens/navigate_screens/config_screen.dart';
import 'package:pvc_v2/screens/navigate_screens/inputs_screen.dart';
import 'package:pvc_v2/screens/navigate_screens/pam_data_screen.dart';
import 'package:pvc_v2/theme/app_colors.dart';
import 'package:pvc_v2/widgets/custom_app_bar.dart';
import 'package:pvc_v2/widgets/custom_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final BluetoothDevice device;

  const HomeScreen({super.key, required this.device});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late final BluetoothDevice device;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    device = widget.device;
    _connSub = widget.device.connectionState.listen((state) {
      if (!mounted) return;
      if (state == BluetoothConnectionState.disconnected) {
        // Show alert snackbar
        ref
            .read(globalMessageProvider.notifier)
            .showError("ESP32 disconnected! Returning to scan...");

        // Navigate to scan screen after short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          context.go(AppRoutes.home); // your scan screen route
        });
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  late final List<Widget> _children = [
    PamDataScreen(device: device),
    InputScreen(),
    ConfigScreen(),
  ];

  final List<BottomNavigationBarItem> _bottomNavigationBarItems = [
    BottomNavigationBarItem(
      icon: const Icon(Icons.home_outlined),
      label: 'Home',
    ),
    BottomNavigationBarItem(icon: const Icon(Icons.input), label: 'Inputs'),
    BottomNavigationBarItem(icon: const Icon(Icons.settings), label: 'Config'),
  ];

  String title() {
    switch (_currentIndex) {
      case 0:
        return 'HOME';
      case 1:
        return 'INPUTS';
      case 2:
        return 'CONFIG';
      default:
        return 'HOME';
    }
  }

  void _onItemTapped(int index) {
    // Use ref.read to check connection status without a full rebuild here
    final isConnected = ref.read(bleProvider).connectedDevice != null;

    // Rule: Allow index 0 (Dashboard) always, but block others if disconnected
    if (!isConnected && index != 0) {
      ref
          .read(globalMessageProvider.notifier)
          .showError("COMMUNICATION LOSS: Reconnect to access this module");
      return; // Exit function, preventing the tab change
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen for Global Messages
    ref.listen<GlobalMessage?>(globalMessageProvider, (previous, next) {
      if (next != null) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Color bgColor;
        Color textColor = Colors.white;

        if (next.type == MessageType.success) {
          bgColor = isDark ? AppColors.brandCyan : Colors.green;
          if (isDark) textColor = Colors.black;
        } else {
          bgColor = isDark ? AppColors.brandRed.withAlpha(200) : Colors.red;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.message,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: next.type == MessageType.success
                    ? AppColors.brandCyan
                    : AppColors.brandRed,
                width: 1,
              ),
            ),
          ),
        );
        ref.read(globalMessageProvider.notifier).clear();
      }
    });

    // 2. Watch Processing Overlay State
    final isProcessing = ref.watch(processingOverlayProvider);
    final bleState = ref.watch(bleProvider);
    final isConnected = bleState.connectedDevice == device;
    final theme = Theme.of(context);
    final pamIsConnected = ref.watch(machineDataProvider).func == "None"
        ? false
        : true;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const CustomDrawer(),
      appBar: CustomAppBar(
        title: pamIsConnected ? title() : "PAM NOT CONNECTED",
        preferredSizeChild: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: isProcessing
              ? LinearProgressIndicator(
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.38,
                  ),
                )
              : Container(),
        ),
        actions: [
          pamIsConnected
              ? IconButton(
                  icon: const Icon(Icons.menu, size: 36),

                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                )
              : SizedBox.shrink(),
        ],
      ),
      body: pamIsConnected ? _children[_currentIndex] : _buildNoPamScreen(),
      bottomNavigationBar: pamIsConnected
          ? BottomNavigationBar(
              items: _bottomNavigationBarItems,
              currentIndex: _currentIndex,
              onTap: _onItemTapped,
              selectedItemColor: isConnected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.38),
              unselectedItemColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.38,
              ),
              enableFeedback: isConnected,
            )
          : null,
    );
  }

  Widget _buildNoPamScreen() {
    final theme = Theme.of(context);
    final bleState = ref.watch(bleProvider);
    final isConnecting = bleState.isConnecting;
    final device = widget.device;
    final bleNotifier = ref.read(bleProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.usb_off_rounded,
                      size: 80,
                      color: theme.colorScheme.error,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              "PAM NOT CONNECTED",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              "The PAM module is not detected. Please check the USB connection between ESP32 and PAM device.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Status card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.usb,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Troubleshooting Tips:",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTipItem(
                      "Check USB cable is properly connected",
                      Icons.usb,
                      theme,
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      "Disconnect and reconnect the USB cable",
                      Icons.power_settings_new,
                      theme,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Retry button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isConnecting
                    ? null
                    : () async {
                        ref
                            .read(globalMessageProvider.notifier)
                            .showError("Reconnecting to PAM...");
                        // Reconnect logic - you may need to reinitialize USB Host
                        // For now, just reset the connection or reload the device
                        await bleNotifier.connectToDevice(device);
                        if (!mounted) return;
                      },
                icon: isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  isConnecting ? "CONNECTING TO PAM..." : "RETRY CONNECTION",
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Back button
            TextButton.icon(
              onPressed: () async {
                final notifier = ref.read(bleProvider.notifier);
                final currentDevice = ref.read(bleProvider).connectedDevice;
                if (currentDevice?.remoteId == device.remoteId) {
                  await notifier.disconnectFromDevice();
                }
                if (!mounted) return; // ← ADD THIS before using context
                context.go(AppRoutes.home);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text("BACK TO DEVICE SCAN"),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for tips
  Widget _buildTipItem(String text, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
