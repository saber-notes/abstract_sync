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
    this.initialUploadQueue,
    this.initialDownloadQueue,
  });

  final SyncInterface interface;

  /// Mutex to prevent concurrent remote operations.
  @internal
  final remoteMutex = Mutex();

  /// Mutex to prevent concurrent local operations.
  @internal
  final localMutex = Mutex();

  final Iterable<SyncFile>? initialUploadQueue, initialDownloadQueue;
  late final uploader = SyncerUploader(
    syncer: this,
    initialQueue: initialUploadQueue,
  );
  late final downloader = SyncerDownloader(
    syncer: this,
    initialQueue: initialDownloadQueue,
  );
}
