import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MessageType { success, error }

class GlobalMessage {
  final String message;
  final MessageType type;

  GlobalMessage({required this.message, required this.type});
}

class GlobalMessageNotifier extends StateNotifier<GlobalMessage?> {
  GlobalMessageNotifier() : super(null);

  void showSuccess(String message) {
    state = GlobalMessage(message: message, type: MessageType.success);
  }

  void showError(String message) {
    state = GlobalMessage(message: message, type: MessageType.error);
  }

  void clear() {
    state = null;
  }
}

final globalMessageProvider =
    StateNotifierProvider<GlobalMessageNotifier, GlobalMessage?>((ref) {
      return GlobalMessageNotifier();
    });
