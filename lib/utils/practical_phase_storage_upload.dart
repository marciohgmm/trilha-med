import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'picker_bytes.dart';
import 'flashcard_storage_upload.dart' show uploadFlashcardPickedFile;

/// Upload de anexos/thumb da Fase Prática para Firebase Storage.
/// Caminho: `practical_phase/{modelId}/{subfolder}/{fileName}`.
Future<String> uploadPracticalPhaseFile({
  required String modelId,
  required PlatformFile file,
  String subfolder = 'attachments',
}) async {
  final name = file.name.trim().isEmpty ? 'arquivo' : file.name.trim();
  final safeName =
      name.replaceAll(RegExp(r'[^\w.\-]+'), '_').replaceAll(RegExp(r'_+'), '_');
  final ref = FirebaseStorage.instance
      .ref()
      .child('practical_phase')
      .child(modelId)
      .child(subfolder)
      .child('${DateTime.now().millisecondsSinceEpoch}_$safeName');

  await uploadFlashcardPickedFile(ref, file);
  return await ref.getDownloadURL();
}

/// Valida tamanho (bytes) e extensão permitida.
String? validatePracticalPhaseFile(
  PlatformFile file, {
  int maxBytes = 10 * 1024 * 1024,
  bool imagesOnly = false,
}) {
  final size = file.size;
  if (size > maxBytes) {
    return 'Arquivo muito grande (máx. ${maxBytes ~/ (1024 * 1024)} MB).';
  }
  final ext = file.extension?.toLowerCase() ?? '';
  const images = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
  const docs = {'pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'};
  final allowed = imagesOnly ? images : {...images, ...docs};
  if (ext.isNotEmpty && !allowed.contains(ext)) {
    return 'Formato não permitido: .$ext';
  }
  return null;
}

Future<int> fileSizeFromPlatformFile(PlatformFile file) async {
  if (file.size > 0) return file.size;
  final bytes = await bytesFromPlatformFile(file);
  return bytes?.length ?? 0;
}
