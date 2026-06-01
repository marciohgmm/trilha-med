import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'flashcard_storage_upload.dart';

/// Upload de imagens de casos OSCE para Storage (`osce_cases/{caseId}/`).
Future<String> uploadOsceCaseImage({
  required String caseId,
  required PlatformFile file,
  String subfolder = 'imaging',
}) async {
  final ext = _ext(file.name);
  final ref = FirebaseStorage.instance.ref(
    'osce_cases/$caseId/$subfolder/${DateTime.now().millisecondsSinceEpoch}.$ext',
  );
  await uploadFlashcardPickedFile(ref, file);
  return ref.getDownloadURL();
}

String _ext(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0) return 'jpg';
  return name.substring(i + 1).toLowerCase();
}

Future<PlatformFile?> pickOsceImageFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.first;
}
