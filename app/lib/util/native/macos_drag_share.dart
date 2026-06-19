import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/tray_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Keeps the macOS menu bar drag-share panel in sync with nearby devices.
class MacMenuBarDragShareWatcher extends StatefulWidget {
  final Widget child;

  const MacMenuBarDragShareWatcher({required this.child, super.key});

  @override
  State<MacMenuBarDragShareWatcher> createState() => _MacMenuBarDragShareWatcherState();
}

class _MacMenuBarDragShareWatcherState extends State<MacMenuBarDragShareWatcher> with Refena {
  String? _lastDeviceSignature;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final devices = ref.watch(nearbyDevicesProvider).allDevices.values.toList();
      final signature = devices.map((device) => '${device.fingerprint}:${device.alias}').join('|');
      if (signature != _lastDeviceSignature) {
        _lastDeviceSignature = signature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          syncMenuBarDragShareDevices(devices);
        });
      }
    }
    return widget.child;
  }
}

/// Handles a file drop from the macOS menu bar drag-share panel.
Future<void> handleMenuBarDragShareDrop(
  Ref ref, {
  required List<String> files,
  String? fingerprint,
}) async {
  if (files.isEmpty) {
    return;
  }

  ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
  await ref.redux(selectedSendingFilesProvider).dispatchAsync(LoadSelectionFromArgsAction(files));
  final stagedFiles = ref.read(selectedSendingFilesProvider);
  if (stagedFiles.isEmpty) {
    return;
  }

  if (fingerprint != null) {
    final device = ref.read(nearbyDevicesProvider).allDevices.values.firstWhereOrNull(
          (entry) => entry.fingerprint == fingerprint,
        );
    if (device != null) {
      await ref.notifier(sendProvider).startSession(
            target: device,
            files: stagedFiles,
            background: false,
          );
      return;
    }
  }

  await showFromTray();
  ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.send));
}

/// Triggers device discovery when a drag session starts on the menu bar icon.
Future<void> handleMenuBarDragShareStarted(Ref ref) async {
  final devices = ref.read(nearbyDevicesProvider).devices;
  if (devices.isEmpty) {
    ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
    await ref.global.dispatchAsync(StartSmartScan(forceLegacy: false));
  }
}

final dragShareOverlayProvider = ReduxProvider<DragShareOverlayNotifier, bool>((ref) {
  return DragShareOverlayNotifier();
});

class DragShareOverlayNotifier extends ReduxNotifier<bool> {
  @override
  bool init() => false;
}

class ShowDragShareOverlayAction extends ReduxAction<DragShareOverlayNotifier, bool> {
  @override
  bool reduce() => true;
}

class HideDragShareOverlayAction extends ReduxAction<DragShareOverlayNotifier, bool> {
  @override
  bool reduce() => false;
}
