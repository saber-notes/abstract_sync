import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer_downloader.dart';
import 'package:abstract_sync/src/syncer_uploader.dart';
import 'package:meta/meta.dart';
import 'package:mutex/mutex.dart';

@immutable
final class Syncer<
    SyncInterface extends AbstractSyncInterface<SyncFile, LocalFile,
        RemoteFile>,
    SyncFile extends AbstractSyncFile<LocalFile, RemoteFile>,
    LocalFile extends Object,
    RemoteFile extends Object> {
  Syncer(
    this.interface, {
    this.failureTimeout = const Duration(seconds: 1),
  });

  final SyncInterface interface;

  /// When an upload/download fails, it will be retried after this duration.
  ///
  /// We use exponential backoff, so the duration is doubled
  /// on a given file each time it fails to sync.
  final Duration failureTimeout;

  /// Mutex to prevent concurrent remote operations.
  @internal
  final remoteMutex = Mutex();

  /// Mutex to prevent concurrent local operations.
  @internal
  final localMutex = Mutex();

  late final uploader = SyncerUploader(syncer: this);
  late final downloader = SyncerDownloader(syncer: this);
}
