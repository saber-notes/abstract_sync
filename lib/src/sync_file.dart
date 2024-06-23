import 'package:meta/meta.dart';

abstract class AbstractSyncFile<LocalFile extends Object,
    RemoteFile extends Object> {
  AbstractSyncFile({
    required this.remoteFile,
    required this.localFile,
  });

  RemoteFile? remoteFile;
  final LocalFile localFile;

  @override
  @mustBeOverridden
  String toString() => 'AbstractSyncFile<$RemoteFile>($localFile)';

  @override
  @mustBeOverridden
  bool operator ==(Object other) =>
      other is AbstractSyncFile<LocalFile, RemoteFile> &&
      other.localFile == localFile;

  @override
  @mustBeOverridden
  int get hashCode => localFile.hashCode;
}
