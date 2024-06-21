import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer_downloader.dart';
import 'package:abstract_sync/src/syncer_uploader.dart';
import 'package:meta/meta.dart';
import 'package:mutex/mutex.dart';

@immutable
final class Syncer<
    SyncInterface extends AbstractSyncInterface<RemoteFile, SyncFile>,
    SyncFile extends AbstractSyncFile<RemoteFile>,
    RemoteFile extends Object> {
  Syncer(
    this.interface, {
    Set<SyncFile>? uploadQueue,
    Set<SyncFile>? downloadQueue,
  })  : _uploadQueue = uploadQueue ?? {},
        _downloadQueue = downloadQueue ?? {};

  final SyncInterface interface;

  /// Mutex to prevent concurrent network operations.
  @internal
  final networkMutex = Mutex();

  final Set<SyncFile> _uploadQueue, _downloadQueue;
  late final uploader = SyncerUploader<SyncInterface, SyncFile, RemoteFile>(
    syncer: this,
    pending: _uploadQueue,
  );
  late final downloader = SyncerDownloader<SyncInterface, SyncFile, RemoteFile>(
    syncer: this,
    pending: _downloadQueue,
  );
}
