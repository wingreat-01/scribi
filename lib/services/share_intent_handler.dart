import 'dart:async';
import 'dart:io';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Wraps receive_sharing_intent so the rest of the app just gets a stream
/// of File objects, whether the app was already open or launched fresh
/// from the share sheet.
class ShareIntentHandler {
  StreamSubscription? _mediaStreamSub;

  void listen(void Function(File file) onImageShared) {
    // App already running in background/foreground.
    _mediaStreamSub =
        ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) {
        onImageShared(File(files.first.path));
      }
    });

    // App launched cold, directly from the share sheet.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        onImageShared(File(files.first.path));
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void dispose() {
    _mediaStreamSub?.cancel();
  }
}
