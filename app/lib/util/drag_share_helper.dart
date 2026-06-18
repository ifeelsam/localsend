import 'dart:io';

import 'package:common/model/device.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Adds dropped files to the current send selection.
Future<List<CrossFile>> stageDroppedFiles(Ref ref, DropDoneDetails event) async {
  if (event.files.isEmpty) {
    return ref.read(selectedSendingFilesProvider);
  }

  if (event.files.length == 1 && Directory(event.files.first.path).existsSync()) {
    await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(event.files.first.path));
  } else {
    await ref.redux(selectedSendingFilesProvider).dispatchAsync(
          AddFilesAction(
            files: event.files,
            converter: CrossFileConverters.convertXFile,
          ),
        );
  }

  return ref.read(selectedSendingFilesProvider);
}

/// Adds dropped files and immediately starts a send session to [device].
Future<void> sendDroppedFilesToDevice(Ref ref, DropDoneDetails event, Device device) async {
  final files = await stageDroppedFiles(ref, event);
  if (files.isEmpty) {
    return;
  }

  await ref.notifier(sendProvider).startSession(
        target: device,
        files: files,
        background: false,
      );
}
