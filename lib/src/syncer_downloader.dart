import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer_component.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

final class SyncerDownloader<
        SyncInterface extends AbstractSyncInterface<SyncFile, LocalFile,
            RemoteFile>,
        SyncFile extends AbstractSyncFile<LocalFile, RemoteFile>,
        LocalFile extends Object,
        RemoteFile extends Object>
    extends SyncerComponent<SyncInterface, SyncFile, LocalFile, RemoteFile> {
  SyncerDownloader({
    required super.syncer,
  }) : super(
          log: Logger('SyncerDownloader'),
        );

  /// Updates the queue with remotely changed files.
  @override
  Future<void> refresh() => super.refresh();

  /// Updates the queue with remotely changed files.
  @override
  @protected
  Future<void> doRefresh() async {
    final updatedFiles = await syncer.interface.findRemoteChanges();
    for (final syncFile in updatedFiles) {
      enqueue(syncFile: syncFile);
    }
  }

  /// Downloads a file.
  @override
  @protected
  Future<void> transfer(SyncFile file) async {
    final downloadedBytes = await syncer.remoteMutex.protect(
      () => syncer.interface.downloadRemoteFile(file),
    );
    await syncer.localMutex.protect(
      () => syncer.interface.writeLocalFile(file, downloadedBytes),
    );
  }
}
