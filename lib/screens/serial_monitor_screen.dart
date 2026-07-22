import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pvc_v2/providers/ble_provider.dart';
import 'package:pvc_v2/routes/static_routes.dart';
import 'package:pvc_v2/utils/responsive_helper.dart';

class SerialMonitorScreen extends ConsumerStatefulWidget {
  const SerialMonitorScreen({super.key});

  @override
  ConsumerState<SerialMonitorScreen> createState() =>
      _SerialMonitorScreenState();
}

class _SerialMonitorScreenState extends ConsumerState<SerialMonitorScreen> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _cmdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendCommand() {
    final cmd = _cmdController.text.trim();
    if (cmd.isEmpty) return;
    ref.read(bleProvider.notifier).writeToCharacteristic(cmd);
    _cmdController.clear();
  }

  void _scrollToBottom() {
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);
    final theme = Theme.of(context);

    final log = bleState.serialLog;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final device = bleState.connectedDevice;
        if (device != null) {
          context.go(AppRoutes.details, extra: device);
        } else {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Serial Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: () {
              final text = log.join('\n');
              if (text.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Log copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
            ),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: () => ref.read(bleProvider.notifier).clearSerialLog(),
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: theme.brightness == Brightness.dark
                    ? Colors.black87
                    : const Color(0xFF1E1E1E),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: log.length,
                  itemBuilder: (context, index) {
                    final line = log[index];
                    final isTx = line.contains(" TX: ");
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isTx
                              ? const Color(0xFF4FC3F7)
                              : const Color(0xFF81C784),
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.onSurface.withAlpha(25),
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).padding.bottom + 8,
                top: 8,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cmdController,
                        decoration: const InputDecoration(
                          hintText: 'Send command...',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        onSubmitted: (_) => _sendCommand(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: _sendCommand,
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
