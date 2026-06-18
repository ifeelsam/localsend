import 'package:common/model/device.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:refena_flutter/refena_flutter.dart';

class DragShareOverlay extends StatelessWidget {
  final void Function(DropDoneDetails event, Device device) onDropOnDevice;

  const DragShareOverlay({
    required this.onDropOnDevice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColorWithElevation,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Text(
                  t.sendTab.dragShare.title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.sendTab.dragShare.myDevices,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref) {
                        final devices = ref.watch(nearbyDevicesProvider).allDevices.values.toList();
                        final favorites = ref.watch(favoritesProvider);
                        final scanning = ref.watch(
                          nearbyDevicesProvider.select((s) => s.runningFavoriteScan || s.runningIps.isNotEmpty),
                        );
                        final animations = ref.watch(animationProvider);

                        if (devices.isEmpty) {
                          return _ScanningHint(scanning: scanning && animations);
                        }

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: devices.map((device) {
                            final favorite = favorites.findDevice(device);
                            return _DragShareDeviceTarget(
                              device: device,
                              name: favorite?.alias ?? device.alias,
                              onDrop: (event) => onDropOnDevice(event, device),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningHint extends StatelessWidget {
  final bool scanning;

  const _ScanningHint({required this.scanning});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotatingWidget(
            duration: const Duration(seconds: 2),
            spinning: scanning,
            reverse: true,
            child: Icon(Icons.sync, color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              t.sendTab.dragShare.scanning,
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _DragShareDeviceTarget extends StatefulWidget {
  final Device device;
  final String name;
  final void Function(DropDoneDetails event) onDrop;

  const _DragShareDeviceTarget({
    required this.device,
    required this.name,
    required this.onDrop,
  });

  @override
  State<_DragShareDeviceTarget> createState() => _DragShareDeviceTargetState();
}

class _DragShareDeviceTargetState extends State<_DragShareDeviceTarget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.18);

    return DropTarget(
      onDragEntered: (_) => setState(() => _hovered = true),
      onDragExited: (_) => setState(() => _hovered = false),
      onDragDone: (event) {
        setState(() => _hovered = false);
        widget.onDrop(event);
      },
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _hovered ? highlightColor : theme.colorScheme.secondaryContainer.withValues(alpha: 0.65),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _hovered ? theme.colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                widget.device.deviceType.icon,
                size: 30,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
