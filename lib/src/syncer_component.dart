import 'dart:io';

import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

abstract class SyncerComponent<
    SyncInterface extends AbstractSyncInterface<RemoteFile, SyncFile>,
    SyncFile extends AbstractSyncFile<RemoteFile>,
    RemoteFile extends Object> with ChangeNotifier {
  SyncerComponent({
    required this.syncer,
    required this.pending,
    required this.log,
  });

  final Syncer<SyncInterface, SyncFile, RemoteFile> syncer;

  @protected
  final Set<SyncFile> pending;

  final Logger log;

  bool isPending(SyncFile file) => pending.contains(file);
  bool isLocalFilePending(File file) =>
      pending.any((element) => element.localFile.path == file.path);
  bool isRemoteFilePending(RemoteFile file) => pending.any((element) =>
      syncer.interface.areRemoteFilesEqual(element.remoteFile, file));

  /// Adds a file to the queue, if it is not already pending.
  ///
  /// Returns `true` if the file was newly added to the queue.
  bool enqueue({
    SyncFile? syncFile,
    File? localFile,
    RemoteFile? remoteFile,
  }) {
    assert(syncFile != null || localFile != null || remoteFile != null,
        'One of syncFile, localFile, or remoteFile must be provided.');

    if ((syncFile != null && isPending(syncFile)) ||
        (localFile != null && isLocalFilePending(localFile)) ||
        (remoteFile != null && isRemoteFilePending(remoteFile))) return false;

    syncFile ??= localFile != null
        ? syncer.interface.getSyncFileFromLocalFile(localFile)
        : syncer.interface.getSyncFileFromRemoteFile(remoteFile!);

    // If the file is already pending, don't add it again.
    if (!pending.add(syncFile)) return false;
    notifyListeners();

    syncer.networkMutex.protect(() => _transferWrapper(syncFile!));

    return true;
  }

  /// Removes a file from the queue.
  ///
  /// Returns `true` if the file was removed from the queue.
  bool dequeue({
    SyncFile? syncFile,
    File? localFile,
    RemoteFile? remoteFile,
  }) {
    assert(syncFile != null || localFile != null || remoteFile != null,
        'One of syncFile, localFile, or remoteFile must be provided.');

    syncFile ??= pending.castNullable().firstWhere(
          (syncFile) => localFile != null
              ? syncFile!.localFile.path == localFile.path
              : syncer.interface
                  .areRemoteFilesEqual(syncFile!.remoteFile, remoteFile!),
          orElse: () => null,
        );

    if (syncFile == null) return false;
    if (!pending.remove(syncFile)) return false;
    notifyListeners();
    return true;
  }

  Future<void> _transferWrapper(SyncFile file) async {
    // If the file was dequeued before the transfer started, do nothing.
    if (!isPending(file)) return;

    try {
      await transfer(file);
    } catch (e, st) {
      // If the transfer failed, re-enqueue the file.
      log.warning('Transfer failed: $e', e, st);
      syncer.networkMutex.protect(() => _transferWrapper(file));
      return;
    }

    // File was successfully transferred.
    log.info('Transfer complete: $file');
    pending.remove(file);
    notifyListeners();
  }

  /// Checks the source file system for changes and updates the queue.
  Future<void> refresh();

  /// Transfers a file from the source to the destination.
  ///
  /// This method should be called in the context of
  /// `syncer.networkMutex.protect`
  /// to prevent concurrent network operations.
  ///
  /// This method should not remove the file from the pending queue,
  /// notify listeners, or handle errors. These are done in [_transferWrapper].
  @protected
  Future<void> transfer(SyncFile file);
}

extension EIterable<T> on Iterable<T> {
  Iterable<T?> castNullable() => cast<T?>();
}
