## 1.2.0

- The `pending` queue is now exposed as a public iterable in `syncer.uploader.pending` and `syncer.downloader.pending`.

## 1.1.0

- Added a small timeout delay for when a transfer fails. This can be configured using the `failureTimeout` option in the `Syncer` constructor.
- Removed the dependency on Flutter, so the package can be used in non-Flutter projects.

## 1.0.0

- Initial version.
