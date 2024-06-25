/// This example uses abstract_sync
/// to "sync" between two folders on the same device.
library;

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:abstract_sync/abstract_sync.dart';

final localDir = Directory('local');
final remoteDir = Directory('remote');

void main() async {
  // Refresh the syncer using `findLocalChanges` and `findRemoteChanges`
  syncer.uploader.refresh();
  syncer.downloader.refresh();

  // Upload a specific file
  syncer.uploader.enqueue(localFile: File('local/file.txt'));

  // Download a specific file
  syncer.downloader.enqueue(remoteFile: File('remote/file.txt'));

  // Bring a file to the front of the queue
  syncer.downloader.bringToFront(await const MySyncInterface()
      .getSyncFileFromRemoteFile(File('remote/file.txt')));

  // Check if there are files uploading
  if (syncer.uploader.numPending > 0) print('There are files uploading');

  // Check if the uploader is still refreshing
  if (syncer.uploader.isRefreshing) print('The uploader is still refreshing');

  // Listen for successfully uploaded files...
  final subscription = syncer.uploader.transferStream.listen((file) {
    print('Woohoo! Successfully uploaded: $file');
  });
  // ...and cancel the subscription when you're done
  subscription.cancel();
}

final syncer = Syncer<MySyncInterface, MySyncFile, File, File>(
  const MySyncInterface(),
);

class MySyncInterface extends AbstractSyncInterface<MySyncFile, File, File> {
  const MySyncInterface();

  @override
  bool areLocalFilesEqual(File a, File b) => a.path == b.path;

  @override
  bool areRemoteFilesEqual(File a, File b) => a.path == b.path;

  @override
  Future<List<MySyncFile>> findLocalChanges() async {
    final localFiles = localDir.list(recursive: true);
    final syncFiles = [
      await for (final localFile in localFiles)
        if (localFile is File) await getSyncFileFromLocalFile(localFile),
    ];
    return syncFiles.where(isLocalFileNewer).toList();
  }

  @override
  Future<List<MySyncFile>> findRemoteChanges() async {
    final remoteFiles = remoteDir.list(recursive: true);
    final syncFiles = [
      await for (final remoteFile in remoteFiles)
        if (remoteFile is File) await getSyncFileFromRemoteFile(remoteFile),
    ];
    return syncFiles.where(isRemoteFileNewer).toList();
  }

  @override
  Future<MySyncFile> getSyncFileFromLocalFile(File localFile) async {
    assert(localFile.path.startsWith(localDir.path));
    final remotePath =
        remoteDir.path + localFile.path.substring(localDir.path.length);
    final remoteFile = File(remotePath);
    return MySyncFile(
      localFile: localFile,
      remoteFile: remoteFile,
    );
  }

  @override
  Future<MySyncFile> getSyncFileFromRemoteFile(File remoteFile) async {
    assert(remoteFile.path.startsWith(remoteDir.path));
    final localPath =
        localDir.path + remoteFile.path.substring(remoteDir.path.length);
    final localFile = File(localPath);
    return MySyncFile(
      localFile: localFile,
      remoteFile: remoteFile,
    );
  }

  @override
  Future<void> uploadRemoteFile(MySyncFile file, Uint8List bytes) =>
      file.remoteFile!.writeAsBytes(bytes);

  @override
  Future<Uint8List> downloadRemoteFile(MySyncFile file) =>
      file.remoteFile!.readAsBytes();

  @override
  Future<Uint8List> readLocalFile(MySyncFile file) =>
      file.localFile.readAsBytes();

  @override
  Future<void> writeLocalFile(MySyncFile file, Uint8List bytes) =>
      file.localFile.writeAsBytes(bytes);

  static bool isLocalFileNewer(MySyncFile file) => !isRemoteFileNewer(file);

  static bool isRemoteFileNewer(MySyncFile file) {
    final local = file.localFile.lastModifiedSync();
    final remote = file.remoteFile!.lastModifiedSync();
    return remote.isAfter(local);
  }
}

class MySyncFile extends AbstractSyncFile<File, File> {
  MySyncFile({
    required super.localFile,
    required super.remoteFile,
  });

  @override
  bool operator ==(Object other) =>
      other is MySyncFile && other.localFile.path == localFile.path;

  @override
  int get hashCode => localFile.path.hashCode;

  @override
  String toString() => 'MySyncFile(local: $localFile, remote: $remoteFile)';
}
