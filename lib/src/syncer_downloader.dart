import 'package:abstract_sync/src/abstract_sync_interface.dart';
import 'package:abstract_sync/src/sync_file.dart';
import 'package:abstract_sync/src/syncer_component.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

final class SyncerDownloader<
        SyncInterface extends AbstractSyncInterface<RemoteFile, SyncFile>,
        SyncFile extends AbstractSyncFile<RemoteFile>,
        RemoteFile extends Object>
    extends SyncerComponent<SyncInterface, SyncFile, RemoteFile> {
  SyncerDownloader({
    required super.syncer,
    required super.pending,
  }) : super(
          log: Logger('SyncerDownloader'),
        );

  /// Updates the queue with remotely changed files.
  @override
  Future<void> refresh() async {
    final updatedFiles = await syncer.interface.findRemoteChanges();
    for (final remoteFile in updatedFiles) {
      enqueue(remoteFile: remoteFile);
    }
  }

  /// Downloads a file.
  @override
  @protected
  Future<void> transfer(SyncFile file) async {
    await syncer.interface.downloadFile(file);
  }
}
