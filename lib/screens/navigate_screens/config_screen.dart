import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/screens/navigate_screens/advanced_config_screen.dart';
import 'package:pvc_v2/screens/navigate_screens/basic_config_screen.dart';

/// Config destination — automatically renders BasicConfigScreen or
/// AdvancedConfigScreen based on MachineData.pamMode, with NO user-facing
/// selector of any kind (the actual selector lives in the drawer — see
/// CustomDrawer's _ConfigViewSelector).
///
/// MachineData.pamMode is the ACTUAL PAM hardware MODE (STD/EXP), read back
/// from PAM's own MODE register on the ESP — the single source of truth for
/// which config UI is active. It changes ONLY via an explicit Basic/Advanced
/// drawer selection (BleCommandController.setPamMode()), never automatically
/// on connect/reconnect or as a side effect of saving Basic/Advanced Config
/// parameters. This is NOT the live AINA V/C input type (MachineData.mode,
/// wire key MODE). (Phase 13, 2026-09: the old MachineData.configView
/// app-preference cache this comment used to distinguish `pamMode` from has
/// been removed entirely — `pamMode` is now the only routing state.)
///
/// This widget is intentionally NOT a Scaffold: BasicConfigScreen and
/// AdvancedConfigScreen each already return their own top-level Scaffold
/// (transparent background, no AppBar, no bottomNavigationBar), exactly as
/// they did when HomeScreen placed them directly as `body:` for their own
/// bottom-nav tabs — this screen just picks which one to show.
class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pamMode = ref.watch(
      machineDataProvider.select((d) => d.pamMode),
    );

    return pamMode == 'EXP'
        ? AdvancedConfigScreen()
        : const BasicConfigScreen();
  }
}
