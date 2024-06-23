import 'dart:async';

import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

abstract class SyncerComponent<
    SyncInterface extends AbstractSyncInterface<SyncFile, LocalFile,
        RemoteFile>,
    SyncFile extends AbstractSyncFile<LocalFile, RemoteFile>,
    LocalFile extends Object,
    RemoteFile extends Object> with ChangeNotifier {
  SyncerComponent({
    required this.syncer,
    required this.log,
  });

  final Syncer<SyncInterface, SyncFile, LocalFile, RemoteFile> syncer;

  @protected
  final Set<SyncFile> _pending = {};

  final Logger log;

  bool isPending(SyncFile file) => _pending.contains(file);
  bool isLocalFilePending(LocalFile file) => _pending.any((element) =>
      syncer.interface.areLocalFilesEqual(element.localFile, file));
  bool isRemoteFilePending(RemoteFile file) => _pending.any((element) =>
      element.remoteFile != null &&
      syncer.interface.areRemoteFilesEqual(element.remoteFile!, file));

  /// Adds a file to the queue, if it is not already pending.
  ///
  /// Returns `true` if the file was newly added to the queue.
  Future<bool> enqueue({
    SyncFile? syncFile,
    LocalFile? localFile,
    RemoteFile? remoteFile,
  }) async {
    assert(syncFile != null || localFile != null || remoteFile != null,
        'One of syncFile, localFile, or remoteFile must be provided.');

    if ((syncFile != null && isPending(syncFile)) ||
        (localFile != null && isLocalFilePending(localFile)) ||
        (remoteFile != null && isRemoteFilePending(remoteFile))) return false;

    syncFile ??= localFile != null
        ? await syncer.interface.getSyncFileFromLocalFile(localFile)
        : await syncer.interface.getSyncFileFromRemoteFile(remoteFile!);

    // If the file is already pending, don't add it again.
    if (!_pending.add(syncFile)) return false;
    notifyListeners();

    // Start transferring the file if no other transfers are running.
    unawaited(_transferWrapper(_pending.first));

    return true;
  }

  /// Removes a file from the queue.
  ///
  /// Returns `true` if the file was removed from the queue.
  bool dequeue({
    SyncFile? syncFile,
    LocalFile? localFile,
    RemoteFile? remoteFile,
  }) {
    assert(syncFile != null || localFile != null || remoteFile != null,
        'One of syncFile, localFile, or remoteFile must be provided.');

    syncFile ??= _pending.castNullable().firstWhere(
          localFile != null
              ? (syncFile) => syncer.interface
                  .areLocalFilesEqual(syncFile!.localFile, localFile)
              : (syncFile) =>
                  syncFile!.remoteFile != null &&
                  syncer.interface
                      .areRemoteFilesEqual(syncFile.remoteFile!, remoteFile!),
          orElse: () => null,
        );

    if (syncFile == null) return false;
    if (!_pending.remove(syncFile)) return false;
    notifyListeners();
    return true;
  }

  /// Whether [_transferWrapper] is currently running.
  bool isTransferring = false;
  Future<void> _transferWrapper(SyncFile file) async {
    // If the file was dequeued before the transfer started, do nothing.
    if (!isPending(file)) return;

    /// If another transfer is already running, do nothing.
    if (isTransferring) return;

    try {
      isTransferring = true;

      bool transferFailed = false;
      try {
        await transfer(file);
      } catch (e, st) {
        // If the transfer failed, re-enqueue the file.
        transferFailed = true;
        log.warning('Transfer failed: $e', e, st);
        _pending.remove(file);
        enqueue(syncFile: file);
      }

      if (!transferFailed) {
        // File was successfully transferred.
        log.info('Transfer complete: $file');
        _pending.remove(file);
        notifyListeners();
      }
    } finally {
      isTransferring = false;
    }

    if (_pending.isNotEmpty) {
      unawaited(_transferWrapper(_pending.first));
    }
  }

  /// Checks the source file system for changes and updates the queue.
  Future<void> refresh();

  /// Transfers a file from the source to the destination.
  ///
  /// When overriding this method,
  /// be sure to use
  /// `syncer.remoteMutex.protect` and `syncer.localMutex.protect`
  /// to prevent concurrent operations on the remote and local file systems.
  ///
  /// This method should not remove the file from the pending queue,
  /// notify listeners, or handle errors. These are done in [_transferWrapper].
  @protected
  Future<void> transfer(SyncFile file);
}

extension EIterable<T> on Iterable<T> {
  Iterable<T?> castNullable() => cast<T?>();
}
