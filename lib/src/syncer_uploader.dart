import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer_component.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

final class SyncerUploader<
        SyncInterface extends AbstractSyncInterface<SyncFile, LocalFile,
            RemoteFile>,
        SyncFile extends AbstractSyncFile<LocalFile, RemoteFile>,
        LocalFile extends Object,
        RemoteFile extends Object>
    extends SyncerComponent<SyncInterface, SyncFile, LocalFile, RemoteFile> {
  SyncerUploader({
    required super.syncer,
    required super.pending,
  }) : super(
          log: Logger('SyncerUploader'),
        );

  /// Finds locally changed files and updates the queue.
  @override
  Future<void> refresh() async {
    final updatedFiles = await syncer.interface.findLocalChanges();
    for (final localFile in updatedFiles) {
      enqueue(localFile: localFile);
    }
  }

  /// Uploads a file.
  @override
  @protected
  Future<void> transfer(SyncFile file) async {
    final localBytes = await syncer.localMutex.protect(
      () => syncer.interface.readLocalFile(file.localFile),
    );
    await syncer.remoteMutex.protect(
      () => syncer.interface.uploadRemoteFile(file.remoteFile, localBytes),
    );
  }
}
