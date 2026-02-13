import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Home',
        actions: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
              scale: 0.5,
              device.platformName.isNotEmpty
                  ? 'https://hvksystems.in/wp-content/uploads/2021/11/logo.png'
                  : 'Unknown Device',
            ),
          ),
          const SizedBox(width: 16),
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
