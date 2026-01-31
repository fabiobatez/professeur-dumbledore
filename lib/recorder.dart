// Unified recorder wrapper with conditional imports.
// On mobile/desktop (dart:io), uses the `record` plugin.
// On web (dart:html), provides a no-op stub so the app compiles.

export 'recorder_stub.dart'
    if (dart.library.io) 'recorder_io.dart'
    if (dart.library.html) 'recorder_stub.dart';