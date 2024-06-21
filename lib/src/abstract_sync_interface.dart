import 'dart:typed_data';

import 'package:abstract_sync/src/sync_file.dart';
import 'package:meta/meta.dart';

/// The sync interface allows `abstract_sync` to interface with a
/// backend without knowing the specifics of the backend.
///
/// Extend this class to create a sync interface for your backend.
/// Your class must be const, so if you need to keep state,
/// use static fields.
@immutable
abstract class AbstractSyncInterface<
    SyncFile extends AbstractSyncFile<LocalFile, RemoteFile>,
    LocalFile extends Object,
    RemoteFile extends Object> {
  /// Creates an instance of the sync interface.
  const AbstractSyncInterface();

  /// Gets an [AbstractSyncFile] from a given local file.
  Future<SyncFile> getSyncFileFromLocalFile(LocalFile file);

  /// Gets an [AbstractSyncFile] from a given remote file.
  Future<SyncFile> getSyncFileFromRemoteFile(RemoteFile file);

  bool areRemoteFilesEqual(RemoteFile a, RemoteFile b);

  bool areLocalFilesEqual(LocalFile a, LocalFile b);

  /// Finds local changes that need to be uploaded.
  Future<List<LocalFile>> findLocalChanges();

  /// Finds remote changes that need to be downloaded.
  Future<List<RemoteFile>> findRemoteChanges();

  /// Uploads [bytes] to [file].
  Future<void> uploadRemoteFile(RemoteFile file, Uint8List bytes);

  /// Downloads the contents of [file].
  Future<Uint8List> downloadRemoteFile(RemoteFile file);

  /// Writes [bytes] to [file].
  Future<void> writeLocalFile(LocalFile file, Uint8List bytes);

  /// Reads the contents of [file].
  Future<Uint8List> readLocalFile(LocalFile file);
}
