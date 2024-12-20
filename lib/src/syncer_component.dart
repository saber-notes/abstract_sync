import 'dart:async';
import 'dart:collection';

import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:mutex/mutex.dart';

abstract class SyncerComponent<
    SyncInterface extends AbstractSyncInterface<SyncFile, LocalFile,
        RemoteFile>,
    SyncFile extends AbstractSyncFile<LocalFile, RemoteFile>,
    LocalFile extends Object,
    RemoteFile extends Object> {
  SyncerComponent({
    required this.syncer,
    required this.log,
  });

  final Syncer<SyncInterface, SyncFile, LocalFile, RemoteFile> syncer;

  @protected
  final _pending = Queue<SyncFile>();

  /// A read-only copy of the pending queue.
  ///
  /// Also see [isPending], [numPending], [pendingEmpty], and [pendingNotEmpty].
  Iterable<SyncFile> get pending => _pending.map((e) => e);

  final Logger log;

  final Mutex _refreshMutex = Mutex();
  bool get isRefreshing => _refreshMutex.isLocked;

  /// A stream that emits an event when a file has been transferred.
  Stream<SyncFile> get transferStream => _transferStreamController.stream;
  final _transferStreamController = StreamController<SyncFile>.broadcast();
  void _emitTransferStream(SyncFile file) {
    if (!_transferStreamController.hasListener) return;
    _transferStreamController.add(file);
  }

  /// A stream that emits an event when a file has been
  /// added or removed from the pending queue.
  Stream<void> get queueStream => _queueStreamController.stream;
  final _queueStreamController = StreamController<void>.broadcast();
  void _emitQueueStream() {
    if (!_queueStreamController.hasListener) return;
    _queueStreamController.add(null);
  }

  int get numPending => _pending.length;
  bool get pendingEmpty => _pending.isEmpty;
  bool get pendingNotEmpty => _pending.isNotEmpty;
  void clearPending() => _pending.clear();
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
        (remoteFile != null && isRemoteFilePending(remoteFile))) {
      return false;
    }

    syncFile ??= localFile != null
        ? await syncer.interface.getSyncFileFromLocalFile(localFile)
        : await syncer.interface.getSyncFileFromRemoteFile(remoteFile!);
    if (isPending(syncFile)) return false;

    _pending.addLast(syncFile);
    _emitQueueStream();

    transferNext();

    return true;
  }

  /// Moves a file to the front of the queue.
  void bringToFront(SyncFile file) {
    if (!isPending(file)) throw StateError('File is not pending: $file');
    _pending.remove(file);
    _pending.addFirst(file);
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
    _emitQueueStream();
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
        log.warning('Transfer failed: $e', e, st);
        transferFailed = true;
        _pending.remove(file);

        if (_failureTimeoutLengths.containsKey(file)) {
          _failureTimeoutLengths[file] = _failureTimeoutLengths[file]! * 2;
        } else {
          _failureTimeoutLengths[file] = syncer.failureTimeout;
        }
        _failureTimeouts[file] = Timer(
          _failureTimeoutLengths[file]!,
          () => enqueue(syncFile: file),
        );
      }

      if (!transferFailed) {
        // File was successfully transferred.
        log.info('Transfer complete: $file');
        _pending.remove(file);
        _emitTransferStream(file);
        _emitQueueStream();
      }
    } finally {
      isTransferring = false;
    }

    transferNext();
  }

  /// Start transferring a file if no other transfers are running.
  void transferNext() {
    if (isTransferring) return;
    if (_pending.isEmpty) return;
    unawaited(_transferWrapper(_pending.first));
  }

  /// When a file transfer fails, a Timer is started to add it back to the queue
  /// in increasingly long intervals (defined in [_failureTimeoutLengths]).
  ///
  /// This map keeps track of the Timers for each file,
  /// so they can be cancelled in [dispose].
  final _failureTimeouts = <SyncFile, Timer>{};

  /// The duration to wait before re-enqueuing a failed transfer
  /// for a given file.
  ///
  /// This begins at [Syncer.failureTimeout] and doubles each time
  /// the transfer fails again.
  final _failureTimeoutLengths = <SyncFile, Duration>{};

  /// Cancels any further transfers and clears [_failureTimeouts].
  ///
  /// This is not permanent and the queue is maintained.
  /// You can undo [dispose] and resume transfers
  /// by calling [transferNext], [refresh], or [enqueue].
  /// However, any failed transfers will be not be retried.
  void dispose() {
    for (final timer in _failureTimeouts.values) {
      timer.cancel();
    }
    _failureTimeouts.clear();
    _failureTimeoutLengths.clear();
  }

  /// Checks the source file system for changes and updates the queue.
  ///
  /// This method internally calls [doRefresh] and protects it with a mutex.
  /// You can use [isRefreshing] to check if a refresh is currently running.
  Future<void> refresh() => _refreshMutex.protect(doRefresh);

  /// Checks the source file system for changes and updates the queue.
  ///
  /// When overriding this method, do not use a mutex as this
  /// is handled in [refresh].
  @protected
  Future<void> doRefresh();

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
