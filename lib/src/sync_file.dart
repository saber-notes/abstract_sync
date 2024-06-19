import 'dart:io';

import 'package:meta/meta.dart';

abstract class AbstractSyncFile<RemoteFile extends Object> {
  AbstractSyncFile({
    required this.remoteFile,
    required this.localFile,
  });

  final RemoteFile remoteFile;
  final File localFile;

  @override
  @mustBeOverridden
  String toString() => 'AbstractSyncFile<$RemoteFile>($localFile)';

  @override
  bool operator ==(Object other) =>
      other is AbstractSyncFile<RemoteFile> &&
      other.localFile.path == localFile.path;

  @override
  int get hashCode => localFile.path.hashCode;
}
