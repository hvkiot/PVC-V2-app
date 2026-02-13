// -----------------------------------------------------------------------------
// 2. ROUTER CONFIGURATION
// -----------------------------------------------------------------------------
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/screens/scan_devices_screen.dart';
import 'package:pvc_v2/screens/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.home,
  routes: <RouteBase>[
    // Route: Home
    GoRoute(
      path: AppRoutes.home,
      builder: (BuildContext context, GoRouterState state) {
        return const AvailableDevicesScreen();
      },
      routes: <RouteBase>[
        // Route: Details (Nested under home)
        GoRoute(
          path: AppRoutes.details,
          builder: (BuildContext context, GoRouterState state) {
            final device = state.extra as BluetoothDevice;
            return HomeScreen(device: device);
          },
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) {
    return const Scaffold(body: Center(child: Text('404 - Page Not Found')));
  },
);
