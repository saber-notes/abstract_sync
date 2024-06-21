import 'dart:io';

import 'package:abstract_sync/src/sync_file.dart';
import 'package:meta/meta.dart';

/// The sync interface allows `abstract_sync` to interface with a
/// backend without knowing the specifics of the backend.
///
/// Extend this class to create a sync interface for your backend.
/// Your class must be const, so if you need to keep state,
/// use static fields.
@immutable
abstract class AbstractSyncInterface<RemoteFile extends Object,
    SyncFile extends AbstractSyncFile<RemoteFile>> {
  /// Creates an instance of the sync interface.
  const AbstractSyncInterface();

  /// Gets an [AbstractSyncFile] from a given local file.
  SyncFile getSyncFileFromLocalFile(File file);

  /// Gets an [AbstractSyncFile] from a given remote file.
  SyncFile getSyncFileFromRemoteFile(RemoteFile file);

  bool areRemoteFilesEqual(RemoteFile a, RemoteFile b);

  /// Finds local changes that need to be uploaded.
  Future<List<File>> findLocalChanges();

  /// Finds remote changes that need to be downloaded.
  Future<List<RemoteFile>> findRemoteChanges();

  /// Uploads a file.
  Future<void> uploadFile(SyncFile file);

  /// Downloads a file.
  Future<void> downloadFile(SyncFile file);
}
