import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Web: envia bytes do [FilePicker] (exige `withData: true`).
Future<void> uploadFlashcardPickedFile(Reference ref, PlatformFile f) async {
  final bytes = f.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw Exception('Não foi possível ler os bytes da imagem na Web.');
  }
  await ref.putData(bytes);
}
