import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// VM/desktop/mobile: envia arquivo local.
Future<void> uploadFlashcardPickedFile(Reference ref, PlatformFile f) async {
  final path = f.path?.trim();
  if (path == null || path.isEmpty) {
    throw Exception('Caminho do arquivo inválido.');
  }
  await ref.putFile(File(path));
}
