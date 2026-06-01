import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Web: apenas `bytes` do picker (nunca usar `File(path)`).
Future<Uint8List?> bytesFromPlatformFile(PlatformFile file) async {
  final b = file.bytes;
  if (b != null && b.isNotEmpty) return b;
  return null;
}
