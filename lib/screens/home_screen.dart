import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          endDrawer: const CustomDrawer(),
          appBar: CustomAppBar(
            title: title(),
            actions: [
              if (_currentIndex == 0)
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
          ),
        ),
        // 3. Processing Overlay
        if (isProcessing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: AppColors.brandCyan,
              backgroundColor: AppColors.brandBlue.withAlpha(50),
            ),
          ),
      ],
    );
  }
}
