import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/screens/navigate_screens/config_screen.dart';
import 'package:pvc_v2/screens/navigate_screens/inputs_screen.dart';
import 'package:pvc_v2/screens/navigate_screens/pam_data_screen.dart';
import 'package:pvc_v2/widgets/custom_app_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final BluetoothDevice device;

  const HomeScreen({super.key, required this.device});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late final BluetoothDevice device;
  // Declare the listener here
  late final ProviderSubscription<BleState> _bleListener;

  @override
  void initState() {
    super.initState();
    device = widget.device;

    // GLOBAL ERROR LISTENER
    _bleListener = ref.listenManual<BleState>(bleProvider, (previous, next) {
      if (!mounted) return;

      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFF56565),
            behavior: SnackBarBehavior.floating, // Better for modern UI
          ),
        );
        ref.read(bleProvider.notifier).clearError();
      }
    });
  }

  @override
  void dispose() {
    _bleListener.close(); // Important to stop the listener
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
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: title(),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.menu, size: 36),
              onPressed: () {},
            ),
        ],
      ),
      body: _children[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        items: _bottomNavigationBarItems,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
