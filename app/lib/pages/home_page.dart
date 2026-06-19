import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/util/drag_share_helper.dart';
import 'package:localsend_app/util/native/macos_drag_share.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/drag_share_overlay.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  receive(Icons.wifi),
  send(Icons.send),
  settings(Icons.settings);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;
  bool _deviceDropHandled = false;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);
    final menuBarDragShareOverlay = context.watch(dragShareOverlayProvider);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
        final devices = ref.read(nearbyDevicesProvider).devices;
        if (devices.isEmpty) {
          ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
          ref.global.dispatchAsync(StartSmartScan(forceLegacy: false)); // ignore: discarded_futures
        }
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        setState(() {
          _dragAndDropIndicator = false;
        });
        if (_deviceDropHandled) {
          _deviceDropHandled = false;
          return;
        }
        await stageDroppedFiles(ref, event, replaceExisting: true);
        vm.changeTab(HomeTab.send);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          return Scaffold(
            body: Row(
              children: [
                if (!sizingInformation.isMobile)
                  Stack(
                    children: [
                      NavigationRail(
                        selectedIndex: vm.currentTab.index,
                        onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                        extended: sizingInformation.isDesktop,
                        backgroundColor: Theme.of(context).cardColorWithElevation,
                        leading: sizingInformation.isDesktop
                            ? Column(
                                children: [
                                  checkPlatform([TargetPlatform.macOS])
                                      ? // considered adding some extra space so it looks more natural
                                        SizedBox(height: 40)
                                      : SizedBox(height: 20),
                                  const Text(
                                    'LocalSend',
                                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 20),
                                ],
                              )
                            : checkPlatform([TargetPlatform.macOS])
                            ? SizedBox(
                                height: 20,
                              )
                            : null,
                        destinations: HomeTab.values.map((tab) {
                          return NavigationRailDestination(
                            icon: Icon(tab.icon),
                            label: Text(tab.label),
                          );
                        }).toList(),
                      ),
                      // makes the top draggable
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: MoveWindow(),
                      ),
                    ],
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      PageView(
                        controller: vm.controller,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          SafeArea(child: ReceiveTab()),
                          SafeArea(child: SendTab()),
                          SettingsTab(),
                        ],
                      ),
                      if (_dragAndDropIndicator || menuBarDragShareOverlay)
                        DragShareOverlay(
                          onDropOnDevice: (event, device) async {
                            _deviceDropHandled = true;
                            setState(() {
                              _dragAndDropIndicator = false;
                            });
                            ref.redux(dragShareOverlayProvider).dispatch(HideDragShareOverlayAction());
                            await sendDroppedFilesToDevice(ref, event, device);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: sizingInformation.isMobile
                ? NavigationBar(
                    selectedIndex: vm.currentTab.index,
                    onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                    destinations: HomeTab.values.map((tab) {
                      return NavigationDestination(icon: Icon(tab.icon), label: tab.label);
                    }).toList(),
                  )
                : null,
          );
        },
      ),
    );
  }
}
