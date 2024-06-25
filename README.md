# abstract_sync

A framework for synchronizing files to and from anything.

I'm building and maintaining this package for my open source notetaking app,
[Saber](https://github.com/saber-notes/saber).

## Getting started

There is a bit of setup required for this package due to its abstract nature.
You can do all of the following in a single file (e.g. `my_syncer.dart`)
or organize it however you like.

You can view a simple example of this in the
[example](example/main.dart) file,
or see a real-world example in
[Saber's `saber_syncer.dart`](https://github.com/saber-notes/saber/blob/main/lib/data/nextcloud/saber_syncer.dart),
which has added functionality for encryption and caching.

1. Decide on your local and remote file classes.
   E.g. Saber uses `File` for local files and `WebDavFile` for remote files.
   I will refer to these as `MyLocalFile` and `MyRemoteFile` respectively,
   but they can be anything you want.

2. Extend the `AbstractSyncFile` class to use the correct generic types.

   The `AbstractSyncFile` class is intended to help you store more information
   other than just the local and remote files,
   such as their path on the remote server, so add any additional fields you need.

   ```dart
   class MySyncFile extends AbstractSyncFile<MyLocalFile, MyRemoteFile> {
     MySyncFile({
       required super.remoteFile,
       required super.localFile,
     });

     // Use your IDE to help you implement the necessary methods
   }
   ```

3. Extend the `AbstractSyncInterface` with the correct generic types.

   The `AbstractSyncInterface` class is how this package can interact with
   your local and remote files.

   Your class has to have a `const` constructor which means you can't use
   variables that aren't final. However, you can use `static` variables
   if you need to save state.

   ```dart
   class MySyncInterface extends AbstractSyncInterface<MySyncFile, MyLocalFile, MyRemoteFile> {
     const MySyncInterface();

     // Use your IDE to help you implement the necessary methods
   }
   ```

4. Finally, we can create a `Syncer` object.

   The `Syncer` object is what you will interact with outside of this file.

   ```dart
   final syncer = Syncer<MySyncInterface, MySyncFile, MyLocalFile, MyRemoteFile>(
     const MySyncInterface(),
   );
   ```

## Usage examples

### Add a file to the upload queue
```dart
syncer.uploader.enqueue(
  // Provide any of syncFile, localFile, or remoteFile
  localFile: MyLocalFile(...),
);
```

### Add a file to the download queue
```dart
syncer.downloader.enqueue(
  // Provide any of syncFile, localFile, or remoteFile
  remoteFile: MyRemoteFile(...),
);
```

(The uploader and downloader have an identical interface.)

### Check the server for changes (and download them)
```dart
await syncer.downloader.refresh();
```

### Monitor the progress of uploads

```dart
if (syncer.downloader.isRefreshing) {
  print('Still checking the server for changes');
}

final subscription = syncer.uploader.transferStream.listen((syncFile) {
  print('Uploaded file: $syncFile');
});
