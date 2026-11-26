import 'package:flutter/material.dart';

import 'connect_screen.dart';
import 'recording_controller.dart';
import 'session_screen.dart';

/// Device connection and recording for the selected child: shows the
/// connect screen until an EmotiBit is connected, then the live session.
class RecordingFlow extends StatelessWidget {
  const RecordingFlow({super.key, required this.controller});
  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PopScope(
        // Leaving while recording would orphan the session; stop it first.
        canPop: !controller.isRecording,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            controller.disconnect();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Detén la grabación antes de salir.')),
            );
          }
        },
        // While recording, the session screen stays up even if the device
        // dropped (it shows the reconnection state).
        child: controller.isConnected || controller.isRecording
            ? SessionScreen(controller: controller)
            : ConnectScreen(controller: controller),
      ),
    );
  }
}
