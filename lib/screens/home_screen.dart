import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/providers/global_message_provider.dart';
import 'package:pvc_v2/providers/processing_overlay_provider.dart';
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

  @override
  void initState() {
    super.initState();
    device = widget.device;
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

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const CustomDrawer(),
      appBar: CustomAppBar(
        title: title(),
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
          IconButton(
            icon: const Icon(Icons.menu, size: 36),

            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: _bottomNavigationBarItems,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        // UI FEEDBACK: Dim the bar when disconnected
        selectedItemColor: isConnected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.38),
        unselectedItemColor: theme.colorScheme.onSurface.withValues(
          alpha: 0.38,
        ),

        // Disable visual "ink" splashes when disconnected
        enableFeedback: isConnected,
      ),
    );
  }
}
