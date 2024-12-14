## 1.3.1

- pub.dev score improvement by fixing a lint issue

## 1.3.0

- Exponential backoff is now used when a transfer fails: i.e. the delay between retries for a file is 1s, 2s, 4s, 8s, and so on if it keeps failing. You can configure the starting delay using `Syncer.failureTimeout` as before, but the default has been changed from 200ms to 1s.

## 1.2.0

- The `pending` queue is now exposed as a public iterable in `syncer.uploader.pending` and `syncer.downloader.pending`.

## 1.1.0

- Added a small timeout delay for when a transfer fails. This can be configured using the `failureTimeout` option in the `Syncer` constructor.
- Removed the dependency on Flutter, so the package can be used in non-Flutter projects.

## 1.0.0

- Initial version.
