import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// VM/desktop/mobile: prefere `bytes`; fallback para leitura por path.
Future<Uint8List?> bytesFromPlatformFile(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) {
    return file.bytes;
  }
  final path = file.path;
  if (path != null && path.isNotEmpty) {
    return File(path).readAsBytes();
  }
  return null;
}
